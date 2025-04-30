# Script to find IP address corresponding to a given MAC address
# Usage: ./simpler.sh [-j|--json] <mac>

# Input parameters and configuration
mac=""                 # MAC address to search for
json_output=false     # JSON output flag
quiet_mode=false      # Quiet mode flag
default_device="br0"   # Default network bridge device
packets=1             # Number of ARP packets to capture
trials=50            # Maximum number of attempts to find the IP
timeout=60s          # Timeout for network operations

# Custom echo function that respects quiet mode
log_msg() {
    if ! $quiet_mode; then
        echo "$@"
    fi
}

# Validate command line arguments
check_usage() {
    if [ -z "$mac" ]; then
        echo "Usage: $0 [-j|--json] <mac>"
        echo "Options:"
        echo "  -j, --json    Output results in JSON format"
        echo "  -q, --quiet   Suppress output unless in JSON mode"
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -j|--json)
            json_output=true
            shift
            ;;
        -q|--quiet)
            quiet_mode=true
            shift
            ;;
        *)
            mac=$1
            shift
            ;;
    esac
done

# Check if the MAC address belongs to a local network interface
find_local_device() {
    local mac=$1
    ip link | grep -i "$mac" -B1 | head -n1 | awk -F': ' '{print $2}' | awk -F'@' '{print $1}'
}

# Search for IP address in the system's ARP cache
find_ip_in_arp_cache() {
    local mac=$1
    ip neigh | grep "$mac" | awk '{print $1}'
}

# Actively scan the network to populate ARP cache
# This helps discover devices that haven't communicated recently
scan_network() {
    local default_device=$1
    local timeout=$2
    # Get all IP addresses on the default bridge interface
    local bridge_ip_addresses=$(ip a show "$default_device" | awk '/inet / {print "      " $2}')

    # Scan each IP address to populate ARP cache
    for ip in $bridge_ip_addresses; do
        timeout "$timeout" nmap -sn -e "$default_device" "$ip" > /dev/null 2>&1
    done
}

# Listen for ARP replies on the network to capture IP addresses
listen_for_arp_replies() {
    local device=$1
    local mac=$2
    local packets=$3
    local timeout=$4
    timeout "$timeout" tcpdump -l -i "$device" -c "$packets" "arp[6:2] = 2" 2>/dev/null | grep -i "is-at $mac" | awk '{print $4}'
}

# Function to resolve FQDN to IP address
resolve_fqdn() {
    local addr=$1
    # Check if input looks like a hostname (contains alphabetic characters)
    if [[ $addr =~ [a-zA-Z] ]]; then
        # Try to resolve the hostname using dig, fall back to original if it fails
        local resolved=$(dig +short "$addr" | grep -v '\.$' | head -n1)
        if [ ! -z "$resolved" ]; then
            echo "$resolved"
            return
        fi
    fi
    # Return original address if it's already an IP or if resolution failed
    echo "$addr"
}

# Main algorithm flow:
# 1. First, check if the MAC address belongs to a local interface
device=$(find_local_device "$mac")

if [ -z "$device" ]; then
    log_msg "Endpoint with MAC address $mac is not on this host"
    
    # 2. If not local, check the ARP cache for the IP
    ip_address=$(find_ip_in_arp_cache "$mac")
    if [ -z "$ip_address" ]; then
        # 3. If not in ARP cache, actively scan the network
        scan_network "$default_device" "$timeout"
        ip_address=$(find_ip_in_arp_cache "$mac")
    fi

    if [ -z "$ip_address" ]; then
        log_msg "No IP address found for $mac"
        exit 1
    fi
    log_msg "Found IP address for $mac: $ip_address"
    exit 0
fi

# 4. If MAC is local, monitor ARP traffic to find its IP
log_msg "Endpoint with MAC address $mac is on this host, backed by device $device"

# Make multiple attempts to capture ARP traffic
for ((i=1; i<=trials; i++)); do
    log_msg "Attempt $i: No IP address found yet..."
    ip_address=$(listen_for_arp_replies "$device" "$mac" "$packets" "$timeout")
    if [ ! -z "$ip_address" ]; then
        break
    fi
done

# If no IP address found after all attempts, exit with error
if [ -z "$ip_address" ]; then
    log_msg "No IP address found after 10 attempts"
    exit 1
fi

# Output the found IP address
if $json_output; then
    resolved_ip=$(resolve_fqdn "$ip_address")
    echo "{\"mac\":\"$mac\",\"ip\":\"$resolved_ip\",\"original_address\":\"$ip_address\",\"device\":\"$device\"}"
else
    resolved_ip=$(resolve_fqdn "$ip_address")
    if [ "$resolved_ip" != "$ip_address" ]; then
        echo "Found IP address for $mac: $resolved_ip (resolved from $ip_address)"
    else
        echo "Found IP address for $mac: $ip_address"
    fi
fi
