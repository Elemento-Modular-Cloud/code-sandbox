from enum import Enum
from scapy.all import arping as scarping
import psutil
from socket import AF_INET, AF_INET6, gethostbyaddr, herror, inet_aton
from tabulate import tabulate
from ipaddress import IPv4Network
import json
import os
from zeroconf import ServiceBrowser, Zeroconf


def load_mac_map():
    script_directory = os.path.dirname(os.path.abspath(__file__))
    file_path = os.path.join(script_directory, 'mac_24bit.json')
    with open(file_path, 'r') as json_file:
        data = json.load(json_file, strict=False)
    return data


MAC_MAP = load_mac_map()


def merge_lists_of_dicts(list1, list2, key):
    """
    Merge two lists of dictionaries avoiding duplicate entries based on a specified key.

    Args:
        list1 (list): First list of dictionaries.
        list2 (list): Second list of dictionaries.
        key (str): Key within the dictionaries to determine uniqueness.

    Returns:
        list: Merged list of dictionaries with no duplicate entries based on the specified key.
    """
    # Create a set to store unique keys encountered so far
    unique_keys = set()

    # Merge the lists while avoiding duplicates based on the specified key
    merged_list = []
    for item in list1 + list2:
        if item[key] not in unique_keys:
            unique_keys.add(item[key])
            merged_list.append(item)

    return merged_list


class isIPVersion(Enum):
    """
    Enum class to determine the IP version.
    """
    def IPv4(addr):
        """
        Check if the address is IPv4.
        """
        return addr.family == AF_INET

    def IPv6(addr):
        """
        Check if the address is IPv6.
        """
        return addr.family == AF_INET6

    def BOTH(addr):
        """
        Check if the address is either IPv4 or IPv6.
        """
        return addr.family == AF_INET or addr.family == AF_INET6


def subnet_mask_to_mask_length(subnet_mask):
    """
    Convert subnet mask to mask length (prefix length).

    Args:
        subnet_mask (str): Subnet mask in dotted-decimal notation for IPv4
                           or hexadecimal notation for IPv6.

    Returns:
        int: Mask length (prefix length).
    """
    # Check if the subnet mask is IPv4 or IPv6
    if '.' in subnet_mask:  # For IPv4
        binary_mask = ''.join([bin(int(x))[2:].zfill(8)
                              for x in subnet_mask.split('.')])
    elif ':' in subnet_mask:  # For IPv6
        binary_mask = ''.join([bin(int(x, 16))[2:].zfill(16)
                              for x in subnet_mask.split(':')])
    else:
        raise ValueError("Invalid subnet mask format.")

    # Count the number of consecutive '1' bits to determine the mask length
    mask_length = 0
    for bit in binary_mask:
        if bit == '1':
            mask_length += 1
        else:
            break

    return mask_length


def get_hostname_from_ip(ip_address):
    """
    Retrieve the hostname associated with a given IP address.

    Args:
        ip_address (str): IP address of the device.

    Returns:
        str: Hostname associated with the IP address, or "Hostname not found" if not found.
    """
    try:
        # Perform reverse DNS lookup to retrieve hostname
        hostname = gethostbyaddr(ip_address)[0]
        return hostname
    except herror:
        return ""  # get_mdns_hostname(ip_address=ip_address)
    except Exception as e:
        # Handle other exceptions that may occur
        return f"Error occurred: {e}"


def get_hostnames_from_ips(devices):
    """
    Retrieve hostnames for a list of devices based on their IP addresses.

    Args:
        devices (list): List of dictionaries containing the "ip" key.

    Returns:
        list: List of dictionaries containing both "ip" and "hostname" keys.
    """
    for device in devices:
        ip_address = device.get("ip")
        if ip_address:
            # Retrieve hostname for each IP address using the get_hostname_from_ip function
            device["hostname"] = get_hostname_from_ip(ip_address)
        else:
            # Handle the case when the "ip" key is not present in the dictionary
            device["hostname"] = "IP not provided"

    return devices


def get_vendor_from_mac(mac_address):
    """
    Retrieve the vendor associated with a given MAC address based on the OUI database.

    Args:
        mac_address (str): MAC address in the format "XX:XX:XX:XX:XX:XX".

    Returns:
        str: Vendor name associated with the MAC address.
    """

    # Extract the OUI from the MAC address (first three octets)
    oui = mac_address.upper().replace(":", "")[:6]

    # Lookup the vendor based on the OUI
    return MAC_MAP.get(oui)


def get_vendors_from_macs(devices):
    """
    Retrieve vendors for a list of devices based on their MAC addresses.

    Args:
        devices (list): List of dictionaries containing the "mac" key.

    Returns:
        list: List of dictionaries containing both "mac" and "vendor" keys.
    """
    for device in devices:
        mac_address = device.get("mac")
        if mac_address:
            # Retrieve vendor for each MAC address using the get_vendor_from_mac function
            device["vendor"] = get_vendor_from_mac(mac_address)
        else:
            # Handle the case when the "mac" key is not present in the dictionary
            device["vendor"] = "MAC not provided"

    return devices


def get_all_ip_ranges(ipv: isIPVersion = isIPVersion.BOTH):
    """
    Retrieve all IP ranges based on the specified IP version.

    Args:
        ipv (Enum): Enum value indicating the IP version (IPv4, IPv6, or BOTH).

    Returns:
        list: List of IP addresses and their corresponding mask lengths.
    """
    ip_ranges = []

    # Iterate over all network interfaces
    for interface, addrs in psutil.net_if_addrs().items():
        for addr in addrs:
            if ipv(addr):
                try:
                    ip_ranges.append(
                        [addr.address, subnet_mask_to_mask_length(addr.netmask)])
                except ValueError:
                    pass

    return ip_ranges


def arping(ip_range):
    """
    Send ARP request to a specified IP range and print devices that respond.

    Args:
        ip_range (str): IP range to send ARP requests to.

    Returns:
        list: List of dictionaries containing the IP and MAC addresses of devices that respond.
    """
    # Send ARP request and receive responses using Scapy's arping function
    responses, _ = scarping(ip_range, timeout=10, verbose=0)

    # Parse the responses and store devices
    devices = []
    for packet in responses:
        devices.append({'ip': packet[1].psrc, 'mac': packet[1].hwsrc})

    return devices


if __name__ == "__main__":
    # Get all IP ranges
    ips = get_all_ip_ranges()
    devices = []
    checked_networks = []

    # Iterate over each IP range and perform ARPING
    for ip in ips:
        try:
            # Skip localhost addresses
            if ip[0] == "127.0.0.1" or ip[0] == "::1":
                print(f"Skipping IP {ip[0]}/{ip[1]} since it's localhost.")
                continue
            # Skip IP ranges with a mask length less than 24
            if ip[1] < 20:
                print(
                    f"Skipping IP {ip[0]}/{ip[1]} since submask is small (taking too much time).")
                continue

            network = str(IPv4Network(
                f"{ip[0]}/{ip[1]}", strict=False)).replace(".0/", ".1/")
            if network in checked_networks:
                print(f"Network {network} already scanned. Skipping.")
                continue
            checked_networks.append(network)
            print(f"Performing ARPING on IP {network}.")

            devices = merge_lists_of_dicts(
                devices, arping(network), "ip")
        except Exception as e:
            print(e)
            print("Invalid network range for ARPING")

    devices = sorted(devices, key=lambda x: inet_aton(x["ip"]))
    devices = get_hostnames_from_ips(devices=devices)
    devices = get_vendors_from_macs(devices=devices)

    # Print the list of devices
    table_data = []
    # Start index from 1 instead of 0
    for device in devices:
        table_data.append([device['ip'], device['mac'],
                          device['hostname'], device["vendor"]])
    print(tabulate(table_data, headers=[
          "IP Address", "MAC Address", "Hostname", "Vendor"], tablefmt="grid", showindex="always"))
