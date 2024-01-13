#!/bin/bash

# Check if the script is run with superuser privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root."
   exit 1
fi

# Define the path to the Python script (assuming it's located next to the installer script)
SCRIPT_PATH="$(dirname "$(realpath "$0")")/git_software_updater.py"

# Define the path to the requirements.txt file (assuming it's located next to the installer script)
REQUIREMENTS_PATH="$(dirname "$(realpath "$0")")/requirements.txt"

# Install Python dependencies using pip associated with the current Python version
python -m pip install -r $REQUIREMENTS_PATH

# Copy the systemd service unit file template to the system directory
cp git_software_updater@.service /etc/systemd/system/git_software_updater@.service

# Enable and start the systemd service
systemctl enable git_software_updater@$SCRIPT_PATH
systemctl start git_software_updater@$SCRIPT_PATH

echo "Service installed, Python dependencies installed, and service started successfully."
