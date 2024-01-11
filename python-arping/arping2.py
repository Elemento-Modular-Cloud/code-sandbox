import os
import subprocess
import re
import json
from socket import gethostbyaddr, herror
from tabulate import tabulate
import psutil
from scapy.all import arping as scarping

# Function to load MAC map from a JSON file


def load_mac_map():
    script_directory = os.path.dirname(os.path.abspath(__file__))
    file_path = os.path.join(script_directory, 'mac_24bit.json')
    with open(file_path, 'r') as json_file:
        data = json.load(json_file, strict=False)
    return data


MAC_MAP = load_mac_map()


def merge_lists_of_dicts(list1, list2, key):
    unique_keys = set()
    merged_list = []
    for item in list1 + list2:
        if item[key] not in unique_keys:
            unique_keys.add(item[key])
            merged_list.append(item)
    return merged_list


def get_hostname_from_ip(ip_address):
    try:
        hostname = gethostbyaddr(ip_address)[0]
        return hostname
    except herror:
        return ""
    except Exception as e:
        return f"Error occurred: {e}"


def get_vendor_from_mac(mac_address):
    oui = mac_address.upper().replace(":", "")[:6]
    return MAC_MAP.get(oui)


def arping_live():
    devices = []
    process = subprocess.Popen(
        ["arp", "-a"], stdout=subprocess.PIPE, text=True, bufsize=1)
    pattern = r'([\w\.-]+)? \((\d+\.\d+\.\d+\.\d+)\) at \(?([0-9a-fA-F:]+)?\)? on'

    while True:
        line = process.stdout.readline().strip().replace("incomplete", '')

        if not line and process.poll() is not None:
            break
        match = re.search(pattern, line)
        if match:
            hostname = match.group(1)  # Capturing hostname if available
            ip_address = match.group(2)
            mac_address = match.group(3) if match.group(3) else ""

            # If hostname is not provided in the ARP output, set it to None
            if not hostname:
                hostname = get_hostname_from_ip(ip_address=ip_address)
            if hostname or mac_address:
                vendor = get_vendor_from_mac(mac_address=mac_address)
                devices.append({'ip': ip_address, 'mac': mac_address,
                           'hostname': hostname, 'vendor': vendor})
            # print(
            #     f"IP Address: {ip_address}, MAC Address: {mac_address}, Hostname: {hostname}, Vendor: {vendor}")
    return devices


if __name__ == "__main__":
    devices = merge_lists_of_dicts([], arping_live(), "ip")
    table_data = []
    for i, device in enumerate(devices, start=1):
        table_data.append([i, device['ip'], device['mac'],
                          device['hostname'], device["vendor"]])
    print(tabulate(table_data, headers=[
          "Index", "IP Address", "MAC Address", "Hostname", "Vendor"], tablefmt="grid"))
