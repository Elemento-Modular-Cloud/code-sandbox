#!/bin/bash

# Check if the script is run with superuser privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root."
   exit 1
fi

# Define the path to the Python script (assuming it's located next to the installer script)
SCRIPT_PATH="$(dirname "$(realpath "$0")")/git_software_updater.py"

# Stop and disable the systemd service
systemctl stop git_software_updater@$SCRIPT_PATH
systemctl disable git_software_updater@$SCRIPT_PATH

# Remove the systemd service unit file from the system directory
rm /etc/systemd/system/git_software_updater@.service

echo "Service uninstalled and stopped successfully."
