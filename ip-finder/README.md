# Smart MAC Scanner

A robust shell script for discovering IP addresses associated with MAC addresses in your network. This tool uses multiple detection methods to ensure reliable MAC-to-IP address resolution.

## Features

- Multiple detection methods:
  - Local interface checking
  - ARP cache lookup
  - Active network scanning
  - ARP traffic monitoring
- JSON output support
- Quiet mode option
- Configurable timeout and retry settings

## Prerequisites

The script requires the following tools to be installed:
- `ip` command (usually part of `iproute2` package)
- `nmap` for network scanning
- `tcpdump` for ARP traffic monitoring

## Installation

1. Download the script:
```bash
wget https://raw.githubusercontent.com/yourusername/smart-mac-scanner/main/smart-mac-scanner.sh
```

2. Make it executable:
```bash
chmod +x smart-mac-scanner.sh
```

## Usage

Basic usage:
```bash
./smart-mac-scanner.sh <MAC_ADDRESS>
```

With options:
```bash
./smart-mac-scanner.sh [-j|--json] [-q|--quiet] <MAC_ADDRESS>
```

### Options

- `-j, --json`: Output results in JSON format
- `-q, --quiet`: Suppress all output except the final result (or JSON output)

### Examples

Basic lookup:
```bash
./smart-mac-scanner.sh 00:11:22:33:44:55
```

JSON output:
```bash
./smart-mac-scanner.sh -j 00:11:22:33:44:55
```

Quiet mode:
```bash
./smart-mac-scanner.sh -q 00:11:22:33:44:55
```

## How It Works

The script uses a multi-step approach to find IP addresses:

1. Checks if the MAC address belongs to a local network interface
2. Searches the system's ARP cache
3. Performs active network scanning to populate the ARP cache
4. Monitors ARP traffic for replies

## Configuration

The script includes several configurable parameters at the top:

- `default_device`: Default network bridge device (default: "br0")
- `packets`: Number of ARP packets to capture (default: 1)
- `trials`: Maximum number of attempts to find the IP (default: 50)
- `timeout`: Timeout for network operations (default: 60s)

## Exit Codes

- 0: Success (IP address found)
- 1: Error (MAC address not found or invalid usage)

## License

This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). This means:

- You can use this software for any purpose
- You can modify this software
- You can distribute this software
- You must include the original source code when you distribute this software
- You must state any changes made to this software
- Any network service using this software must make its full source code available
- All derivative works must be licensed under the same terms

For more details, see the [GNU AGPL v3.0](https://www.gnu.org/licenses/agpl-3.0.en.html) license.

## Contributing

Feel free to submit issues and enhancement requests!
