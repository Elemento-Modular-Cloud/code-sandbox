from enum import Enum
from ipaddress import IPv4Network
from concurrent.futures import ThreadPoolExecutor
from socket import AF_INET, AF_INET6, gethostbyaddr, herror
import subprocess
import re
import os
import json
import psutil
from tabulate import tabulate

# Regular expression pattern to extract information from the "arp" command output
pattern = r'([\w\.-]+)? \((\d+\.\d+\.\d+\.\d+)\) at \(?([0-9a-fA-F:]+)?\)? on'


def load_mac_map():
    """
    Load MAC address vendor information from a JSON file.

    Returns:
        dict: MAC address vendor information.
    """
    script_directory = os.path.dirname(os.path.abspath(__file__))
    file_path = os.path.join(script_directory, 'mac_24bit.json')
    with open(file_path, 'r') as json_file:
        data = json.load(json_file, strict=False)
    return data


# Load MAC address vendor information
MAC_MAP = load_mac_map()


class isIPVersion(Enum):
    """
    Enum class to determine the IP version.
    """
    @staticmethod
    def IPv4(addr):
        """
        Check if the address is IPv4.

        Args:
            addr (ipaddress.IPv4Address): IPv4 address.

        Returns:
            bool: True if IPv4, False otherwise.
        """
        return addr.family == AF_INET

    @staticmethod
    def IPv6(addr):
        """
        Check if the address is IPv6.

        Args:
            addr (ipaddress.IPv6Address): IPv6 address.

        Returns:
            bool: True if IPv6, False otherwise.
        """
        return addr.family == AF_INET6

    @staticmethod
    def BOTH(addr):
        """
        Check if the address is either IPv4 or IPv6.

        Args:
            addr (ipaddress.IPv4Address or ipaddress.IPv6Address): IP address.

        Returns:
            bool: True if IPv4 or IPv6, False otherwise.
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


def get_all_ip_ranges(ipv: isIPVersion = isIPVersion.IPv4):
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


def get_hostname_from_ip(ip_address):
    try:
        hostname = gethostbyaddr(ip_address)[0]
        return hostname
    except herror:
        return ""
    except Exception as e:
        return f"Error occurred: {e}"


def add_leading_zeroes(mac_address):
    """
    Add leading zeroes to each segment of a MAC address to make them two digits.

    Args:
        mac_address (str): MAC address in the format "XX:XX:XX:XX:XX:XX".

    Returns:
        str: MAC address with leading zeroes added to each segment.
    """
    segments = mac_address.split(':')
    formatted_segments = [segment.zfill(2) for segment in segments]
    return ':'.join(formatted_segments)


def get_vendor_from_mac(mac_address):
    mac_address = add_leading_zeroes(mac_address=mac_address)
    oui = mac_address.upper().replace(":", "")[:6]
    return MAC_MAP.get(oui)


def generate_ip_list(base_ip, subnet_mask):
    """
    Generate a list of possible IPs within a given subnet.

    Args:
        base_ip (str): Base IP address in dotted-decimal notation.
        subnet_mask (str): Subnet mask in dotted-decimal notation.

    Returns:
        list: List of possible IPs within the subnet.
    """
    print(f"Base IP: {base_ip}")
    print(f"Subnet: {subnet_mask}")
    base_network = IPv4Network(f"{base_ip}/{subnet_mask}", strict=False)
    print(f"Base network: {base_network}")
    return [str(ip) for ip in base_network.hosts()]


def chunk_ips(ip_list, chunk_size):
    """
    Chunk the list of IPs into subnets of a specified size.

    Args:
        ip_list (list): List of IPs.
        chunk_size (int): Size of each subnet.

    Returns:
        list: List of lists, where each sublist represents a subnet of IPs.
    """
    return [ip_list[i:i + chunk_size] for i in range(0, len(ip_list), chunk_size)]


def arp_scan(ips):
    """
    Perform ARP scanning towards a specific IP using the "arp" command.

    Args:
        ip (str): IP address to scan.

    Returns:
        dict: Dictionary containing the IP and MAC addresses of devices that respond.
    """
    devices = []
    for ip in ips:
        try:
            result = subprocess.Popen(
                ["arp", ip], stdout=subprocess.PIPE, text=True, bufsize=1)
            line, _ = result.communicate()
            match = re.search(pattern, line.strip().replace("incomplete", ''))
            if match:
                hostname = match.group(1)  # Capturing hostname if available
                ip_address = match.group(2)
                mac_address = match.group(
                    3) if match.group(3) else "incomplete"

                if not hostname:
                    hostname = get_hostname_from_ip(ip_address=ip_address)

                devices.append({'ip': ip_address, 'mac': mac_address, 'vendor': get_vendor_from_mac(
                    mac_address=mac_address), 'hostname': hostname})
            else:
                devices.append(
                    {'ip': ip, 'mac': None, 'vendor': None, 'hostname': None})
        except subprocess.CalledProcessError as e:
            devices.append(
                {'ip': ip, 'mac': None, 'vendor': None, 'hostname': None})
    return devices


if __name__ == "__main__":
    with ThreadPoolExecutor(max_workers=8) as executor:
        # Get all IP ranges
        ips = get_all_ip_ranges()
        devices = []
        checked_networks = []
        chunk_size = 4
        subnet_chunks = []
        possible_ips = []
        table_data = []

        futures = []
        for base_ip, subnet_mask in ips:
            print(base_ip)
            print(subnet_mask)
            if base_ip == "127.0.0.1" or base_ip == "::1":
                print(
                    f"Skipping IP {base_ip}/{subnet_mask} since it's localhost.")
                continue
            if subnet_chunks < 20:
                print(
                    f"Skipping IP {base_ip}/{subnet_chunks} since submask is small (taking too much time).")
                continue
            ips = generate_ip_list(base_ip, subnet_mask)
            subnet_chunks += chunk_ips(ips, chunk_size)

            # Submit ARP scanning task for each subnet in parallel
            futures = [executor.submit(arp_scan, chunk)
                       for chunk in subnet_chunks]

        for future in futures:
            devices = future.result()
            for device in devices:
                if device['mac'] and not device['mac'] == "incomplete":
                    table_data.append([device['ip'], device['mac'],
                                       device['hostname'], device["vendor"]])

    print("List of Devices:")
    print(tabulate(table_data, headers=[
          "IP Address", "MAC Address", "Hostname", "Vendor"], tablefmt="grid", showindex="always"))
