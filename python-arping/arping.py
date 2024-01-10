from enum import Enum
from scapy.all import ARP, Ether, srp
import psutil
from socket import AF_INET, AF_INET6


class isIPVersion(Enum):
    def IPv4(addr): return addr.family == AF_INET
    def IPv6(addr): return addr.family == AF_INET6
    def BOTH(addr): return addr.family == AF_INET or addr.family == AF_INET6


def subnet_mask_to_mask_length(subnet_mask):
    """
    Convert subnet mask to mask length (prefix length).

    Args:
    - subnet_mask (str): Subnet mask in dotted-decimal notation for IPv4
                         or hexadecimal notation for IPv6.

    Returns:
    - int: Mask length (prefix length).
    """
    # Check if the subnet mask is IPv4 or IPv6
    if '.' in subnet_mask:  # IPv4
        # Convert subnet mask to binary format
        binary_mask = ''.join([bin(int(x))[2:].zfill(8)
                              for x in subnet_mask.split('.')])
    elif ':' in subnet_mask:  # IPv6
        # Convert IPv6 to binary format
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


def get_all_ip_ranges(ipv: isIPVersion = isIPVersion.BOTH):
    ip_ranges = []

    # Iterate over all network interfaces
    for interface, addrs in psutil.net_if_addrs().items():
        for addr in addrs:
            if ipv(addr):
                try:
                    # {subnet_mask_to_mask_length(addr.netmask)}
                    ip_ranges.append([addr.address, subnet_mask_to_mask_length(addr.netmask)])
                except ValueError:
                    pass

    return ip_ranges


def arping(ip_range):
    # Create ARP request packet
    arp_request = Ether(dst="ff:ff:ff:ff:ff:ff") / ARP(pdst=ip_range)

    # Send ARP request and receive responses
    result = srp(arp_request, timeout=.5, verbose=0)[0]

    # Parse the responses
    devices = []
    for sent, received in result:
        devices.append({'ip': received.psrc, 'mac': received.hwsrc})

    # Print the list of devices
    print("IP Address\t\tMAC Address")
    print("-----------------------------------------")
    for device in devices:
        print(f"{device['ip']}\t\t{device['mac']}")


if __name__ == "__main__":
    ips = get_all_ip_ranges()
    for ip in ips:
        try:
            if ip[0] == "127.0.0.1" or ip[0] == "::1":
                print(f"Skipping IP {ip[0]}/{ip[1]} since it's localhost.")
                continue
            if ip[1] < 24:
                print(f"Skipping IP {ip[0]}/{ip[1]} since submask is small (taking too much time).")
                continue
            print(f"Performing ARPING on IP {ip[0]}/{ip[1]}.")
            arping(f"{ip[0]}/{ip[1]}")
        except Exception as e:
            print(e)
            print("Invalid network range for ARPING")