# Get MAC address from first command line argument
mac=$1
# Default network bridge device
default_device="br0"
# Number of ARP packets to capture
packets=1
# Number of attempts to try finding the IP
trials=50
# Timeout duration for network operations
timeout=60s

# Check if MAC address was provided as argument
if [ -z "$mac" ]; then
    echo "Usage: $0 <mac>"
    exit 1
fi

# Find network device associated with the MAC address
# Uses 'ip link' to list interfaces, grep to find MAC, and awk to extract device name
# -B1 shows one line before the match, which contains the device name
device=$(ip link | grep -i $mac -B1 | head -n1 | awk -F': ' '{print $2}' | awk -F'@' '{print $1}')

# If device is not found, MAC address is not on this host
if [ -z "$device" ]; then
    echo "Endpoint with MAC address $mac is not on this host"
    
    # Try to find IP address in ARP cache
    ip_address=$(ip neigh | grep $mac | awk '{print $1}')
    if [ -z "$ip_address" ]; then
        # Get all IP addresses on the default bridge interface
        bridge_ip_addresses=$(ip a show $default_device | awk '/inet / {print "      " $2}')

        # Scan each IP address to populate ARP cache
        for ip in $bridge_ip_addresses; do
            timeout $timeout nmap -sn -e $default_device $ip > /dev/null 2>&1
        done
    fi

    # Try to find IP address in ARP cache again after scanning
    ip_address=$(ip neigh | grep $mac | awk '{print $1}')
    if [ -z "$ip_address" ]; then
        echo "No IP address found for $mac"
        exit 1
    fi
    echo "Found IP address for $mac: $ip_address"
    exit 0
fi
echo "Endpoint with MAC address $mac is on this host, backed by device $device"

# If device is found locally, listen for ARP replies to find IP
# Try multiple times in case device is not immediately responsive
for ((i=1; i<=trials; i++)); do
    echo "Attempt $i: No IP address found yet..."
    # Use tcpdump to capture ARP replies (type 2) and extract IP address
    # -l: line buffered output
    # -i: specify interface
    # -c: number of packets to capture
    ip_address=$(timeout $timeout tcpdump -l -i $device -c $packets "arp[6:2] = 2" 2>/dev/null | grep -i "is-at $mac" | awk '{print $4}')
    if [ ! -z "$ip_address" ]; then
        break
    fi
done

# If no IP address found after all attempts, exit with error
if [ -z "$ip_address" ]; then
    echo "No IP address found after 10 attempts"
    exit 1
fi

# Output the found IP address
echo "Found IP address for $mac: $ip_address"
