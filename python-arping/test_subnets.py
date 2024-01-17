from ipaddress import IPv4Network

base_ip = "172.16.24.32"
subnet_mask = 25

print(f"Base IP: {base_ip}")
print(f"Subnet: {subnet_mask}")
base_network = IPv4Network(f"{base_ip}/{subnet_mask}", strict=False)
print(f"Base network: {base_network}")
print([str(ip) for ip in base_network.hosts()])