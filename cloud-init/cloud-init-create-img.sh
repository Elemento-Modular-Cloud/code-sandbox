#!/bin/bash

# Check if the required arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <cloud-init-image-url> <path-to-files> <output-path>"
    exit 1
fi

# Assign the arguments to variables
cloud_init_image_url=$1
path_to_files=$2
output_path=$3

# Download the cloud-init image
wget -O $output_path/cloud-init.img $cloud_init_image_url

# Convert the cloud-init image to qcow2 format
qemu-img convert -f raw -O qcow2 -t none $output_path/cloud-init.img $output_path/cloud-init.qcow2

# Convert the qcow2 image to iso
genisoimage -output $output_path/cloud-init-iso.iso -volid cidata -joliet -rock $path_to_files/user-data $path_to_files/meta-data

# Cleaning after myself
rm $output_path/cloud-init.img

echo "Cloud-init images created successfully at $output_path"
tree $output_path
