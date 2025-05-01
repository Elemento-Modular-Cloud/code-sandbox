#!/bin/bash

# Function to validate port number
validate_port() {
    local port=$1
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo "Invalid port number: $port"
        return 1
    fi
    return 0
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if ! [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Invalid IP address format: $ip"
        return 1
    fi
    
    # Validate each octet
    for octet in ${ip//\./ }; do
        if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
            echo "Invalid IP address: $ip"
            return 1
        fi
    done
    return 0
}

setup_fw() {
    # Check if firewalld is running
    if ! systemctl is-active --quiet firewalld; then
        echo "Firewalld is not running. Attempting to start..."
        systemctl start firewalld
        if [ $? -ne 0 ]; then
            echo "Failed to start firewalld"
            return 1
        fi
    fi

    # Enable firewalld to start on boot
    systemctl enable firewalld

    # Check if masquerade is enabled
    if [ "$(firewall-cmd --query-masquerade)" != "yes" ]; then
        echo "Masquerade is not enabled. Attempting to enable..."
        firewall-cmd --permanent --zone=public --add-masquerade
        firewall-cmd --reload
    fi

    return 0
}

firewall-cmd-wrapper() {
    local output=$(firewall-cmd "$@" 2>&1)
    
    if [[ "$output" != *"success"* ]]; then
        echo -e "\e[31mError running command:\e[0m firewall-cmd $@" >&2
        echo -e "\e[31m$output\e[0m" >&2
        return 1
    fi

    return 0
}

# Function to create port mapping
create_port_mapping() {
    local host_port=$1
    local target_ip=$2
    local target_port=$3
    local source_network=${4:-""}  # Optional source network to exclude

    # Check if firewall-cmd is available
    if ! command -v firewall-cmd &> /dev/null; then
        echo "firewall-cmd could not be found, please install firewalld"
        return 1
    fi

    # Add a new service for the port mapping
    service_name="port-mapping-${host_port}-to-${target_ip//\./_}-${target_port}"
    
    local exit_code=0
    firewall-cmd-wrapper --permanent --new-service="$service_name"
    exit_code=$((exit_code + $?))
    firewall-cmd-wrapper --permanent --service="$service_name" --add-port="$host_port/tcp"
    exit_code=$((exit_code + $?))
    firewall-cmd-wrapper --permanent --service="$service_name" --set-description="Port mapping from $host_port to $target_ip:$target_port"
    exit_code=$((exit_code + $?))

    # Add the service to the public zone
    firewall-cmd-wrapper --permanent --zone=public --add-service="$service_name"
    exit_code=$((exit_code + $?))

    if [ -n "$source_network" ]; then
        # For source network exclusion, use a rich rule with name
        firewall-cmd-wrapper --permanent --add-rich-rule="rule family=ipv4 source NOT address=\"${source_network}\" forward-port port=\"${host_port}\" protocol=\"tcp\" to-port=\"${target_port}\" to-addr=\"${target_ip}\""
        exit_code=$((exit_code + $?))
    else
        # Simple forward port without source restriction
        firewall-cmd-wrapper --permanent --add-rich-rule="rule family=ipv4 forward-port port=\"${host_port}\" protocol=\"tcp\" to-port=\"${target_port}\" to-addr=\"${target_ip}\""
        exit_code=$((exit_code + $?))
    fi

    # Reload to apply the changes
    firewall-cmd-wrapper --reload
    exit_code=$((exit_code + $?))
    
    if [ $exit_code -ne 0 ]; then
        echo -e "\e[31mError creating port mapping: $host_port -> $target_ip:$target_port\e[0m"
        return 1
    fi

    echo "Successfully created mapping for $host_port -> $target_ip:$target_port"
    return 0
}


# Function to remove port mapping
remove_port_mapping() {
    local host_port=$1
    local target_ip=$2
    local target_port=$3
    local source_network=${4:-""}  # Optional source network to exclude

    # Remove firewall service
    service_name="port-mapping-${host_port}-to-${target_ip//\./_}-${target_port}"
    
    local exit_code=0
    # Remove service from public zone
    firewall-cmd-wrapper --permanent --zone=public --remove-service="$service_name"
    exit_code=$((exit_code + $?))

    # Remove the service completely
    firewall-cmd-wrapper --permanent --delete-service="$service_name"
    exit_code=$((exit_code + $?))
    
    # Remove any forward port rules (both named rich rules and simple forward ports)
    if [ -n "$source_network" ]; then
        firewall-cmd-wrapper --permanent --remove-rich-rule="rule family=ipv4 source NOT address=\"${source_network}\" forward-port port=\"${host_port}\" protocol=\"tcp\" to-port=\"${target_port}\" to-addr=\"${target_ip}\""
        exit_code=$((exit_code + $?))
    else
        firewall-cmd-wrapper --permanent --remove-rich-rule="rule family=ipv4 forward-port port=\"${host_port}\" protocol=\"tcp\" to-port=\"${target_port}\" to-addr=\"${target_ip}\""
        exit_code=$((exit_code + $?))
    fi
    
    # Reload firewall to apply changes
    firewall-cmd-wrapper --reload
    exit_code=$((exit_code + $?))
    
    if [ $exit_code -ne 0 ]; then
        echo -e "\e[31mError removing port mapping: $host_port -> $target_ip:$target_port\e[0m"
        return 1
    fi

    echo "Successfully removed mapping for $host_port -> $target_ip:$target_port"
    return 0
}

# Function to resolve MAC address to IP using smart-mac-scanner.sh
resolve_mac_to_ip() {
    local mac=$1
    local scanner_path="$(dirname "$0")/../ip-finder/smart-mac-scanner.sh"
    
    # Check if scanner script exists
    if [ ! -f "$scanner_path" ]; then
        echo "Error: smart-mac-scanner.sh not found at $scanner_path"
        return 1
    fi
    
    # Run scanner in quiet JSON mode and extract IP
    local result=$("$scanner_path" -j -q "$mac")
    if [ $? -ne 0 ]; then
        echo "Error: Failed to resolve MAC address $mac"
        return 1
    fi
    
    # Extract IP from JSON output using simple string manipulation
    # Format is {"mac":"XX:XX:XX:XX:XX:XX","ip":"X.X.X.X",...}
    local ip=$(echo "$result" | sed 's/.*"ip":"\([^"]*\)".*/\1/')
    
    if [ -z "$ip" ]; then
        echo "Error: Could not find IP for MAC address $mac"
        return 1
    fi
    
    echo "$ip"
    return 0
}

# Modified function to process port mappings that accepts MAC addresses
process_port_mappings() {
    # Check if script is run with root privileges
    if [ "$EUID" -ne 0 ]; then
        echo "Please run this script as root (using sudo)"
        return 1
    fi

    # Check if at least one mapping is provided
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <host_port>:<target_mac|target_ip>:<target_port> [<host_port>:<target_mac|target_ip>:<target_port> ...]"
        echo "Example: $0 8080:00:11:22:33:44:55:80 3306:192.168.1.101:3306"
        return 1
    fi

    # Process each mapping
    for mapping in "$@"; do
        # Split the mapping into components using parameter expansion
        host_port=${mapping%%:*}                    # Get everything before first colon
        remaining=${mapping#*:}                     # Remove host_port and first colon
        target_port=${remaining##*:}                # Get everything after last colon
        target_addr=${remaining%:*}                 # Get everything between first and last colon
        
        # Validate all components are present
        if [ -z "$host_port" ] || [ -z "$target_addr" ] || [ -z "$target_port" ]; then
            echo "Invalid mapping format: $mapping"
            echo "Expected format: host_port:target_mac|target_ip:target_port"
            continue
        fi
        
        # Validate ports
        if ! validate_port "$host_port"; then
            continue
        fi
        
        if ! validate_port "$target_port"; then
            continue
        fi
        
        # Check if target_addr is a MAC address or IP
        if [[ "$target_addr" =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]; then
            # It's a MAC address, resolve it to IP
            echo "Resolving MAC address $target_addr..."
            target_ip=$(resolve_mac_to_ip "$target_addr")
            if [ $? -ne 0 ]; then
                echo "Failed to resolve MAC address $target_addr"
                continue
            fi
            echo "Resolved $target_addr to IP: $target_ip"
        else
            # Treat as IP address
            target_ip="$target_addr"
            if ! validate_ip "$target_ip"; then
                continue
            fi
        fi
        
        # Create the port mapping using iptables
        echo "Creating port mapping: Host port $host_port -> $target_ip:$target_port"
        create_port_mapping "$host_port" "$target_ip" "$target_port"
        if [ $? -ne 0 ]; then
            echo -e "\e[31mError creating port mapping. Aborting!\e[0m"
            return 1
        fi
    done

    echo "Port mapping complete!"
    return 0
}

# Function to cleanup port mappings
cleanup_port_mappings() {
    # Check if script is run with root privileges
    if [ "$EUID" -ne 0 ]; then
        echo "Please run this script as root (using sudo)"
        return 1
    fi

    # Check if at least one mapping is provided
    if [ $# -eq 0 ]; then
        echo "Usage: $0 --cleanup <host_port>:<target_mac|target_ip>:<target_port> [<host_port>:<target_mac|target_ip>:<target_port> ...]"
        echo "Example: $0 --cleanup 8080:192.168.1.100:80 3306:192.168.1.101:3306"
        return 1
    fi

    # Process each mapping to remove
    for mapping in "$@"; do
        # Split the mapping into components using parameter expansion
        host_port=${mapping%%:*}                    # Get everything before first colon
        remaining=${mapping#*:}                     # Remove host_port and first colon
        target_port=${remaining##*:}                # Get everything after last colon
        target_addr=${remaining%:*}                 # Get everything between first and last colon
        
        # Validate all components are present
        if [ -z "$host_port" ] || [ -z "$target_addr" ] || [ -z "$target_port" ]; then
            echo "Invalid mapping format: $mapping"
            echo "Expected format: host_port:target_mac|target_ip:target_port"
            continue
        fi
        
        # Validate ports
        if ! validate_port "$host_port"; then
            continue
        fi
        
        if ! validate_port "$target_port"; then
            continue
        fi
        
        # Check if target_addr is a MAC address or IP
        if [[ "$target_addr" =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]; then
            # It's a MAC address, resolve it to IP
            echo "Resolving MAC address $target_addr..."
            target_ip=$(resolve_mac_to_ip "$target_addr")
            if [ $? -ne 0 ]; then
                echo "Failed to resolve MAC address $target_addr"
                continue
            fi
            echo "Resolved $target_addr to IP: $target_ip"
        else
            # Treat as IP address
            target_ip="$target_addr"
            if ! validate_ip "$target_ip"; then
                continue
            fi
        fi
        
        # Remove the port mapping
        echo "Removing port mapping: Host port $host_port -> $target_ip:$target_port"
        remove_port_mapping "$host_port" "$target_ip" "$target_port"
        if [ $? -ne 0 ]; then
            echo -e "\e[31mError removing port mappings. Aborting!\e[0m"
            return 1
        fi
    done

    echo "Port mapping cleanup complete!"
    return 0
}

# Main script execution
if [ "$1" = "--cleanup" ]; then
    shift  # Remove --cleanup from arguments
    cleanup_port_mappings "$@"
else
    setup_fw || exit 1
    process_port_mappings "$@"
fi
