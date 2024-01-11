from zeroconf import Zeroconf, ServiceBrowser

class HostnameResolver:
    def __init__(self, ip_address):
        self.ip_address = ip_address
        self.hostname = None
        self.zeroconf = Zeroconf()
        self.browser = ServiceBrowser(self.zeroconf, "_services._dns-sd._udp.local.", self)

    def remove_service(self, zeroconf, type, name):
        pass

    def add_service(self, zeroconf, type, name):
        info = zeroconf.get_service_info(type, name)
        if info and info.addresses:
            for address in info.addresses:
                if address == self.ip_address:
                    self.hostname = info.name
                    break

    def resolve(self):
        try:
            while not self.hostname:
                pass  # Wait until we find the hostname or timeout
        finally:
            self.zeroconf.close()
            return self.hostname

if __name__ == "__main__":
    ip_address_to_resolve = "172.16.24.91"  # Replace with the IP address you want to resolve
    resolver = HostnameResolver(ip_address_to_resolve)
    hostname = resolver.resolve()
    
    if hostname:
        print(f"The hostname for IP address {ip_address_to_resolve} is: {hostname}")
    else:
        print(f"No hostname found for IP address: {ip_address_to_resolve}")
