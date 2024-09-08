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
echo "Downloading cloud-init image..."
output=$(wget -O $output_path/cloud-init.img $cloud_init_image_url 2>&1)
echo "$output" | grep -oP '(?<=Saving to: )[^ ]+'
echo "$output" | grep -oP '(?<=\()[^ ]+(?= saved)'
echo "Download complete."

# Convert the cloud-init image to qcow2 format
echo "Converting cloud-init image to qcow2 format..."
output=$(qemu-img convert -f raw -O qcow2 -t none $output_path/cloud-init.img $output_path/cloud-init.qcow2 2>&1)
echo "$output"
echo "Conversion complete."

# Convert the qcow2 image to iso
echo "Converting qcow2 image to iso format..."
output=$(genisoimage -output $output_path/cloud-init-iso.iso -volid cidata -joliet -rock $path_to_files/user-data $path_to_files/meta-data 2>&1)
echo "$output" | grep -oP '(?<=Added to ISO image: file )[^ ]+'
echo "$output" | grep -oP '(?<=ISO image produced: )[^ ]+'
echo "$output" | grep -oP '(?<=Written to medium : )[^ ]+'
echo "Conversion complete."

# Cleaning after myself
echo "Cleaning up..."
rm $output_path/cloud-init.img
echo "Cleanup complete."

echo "Cloud-init images created successfully at $output_path"
echo "Listing files in $output_path..."
tree $output_path
echo "Listing complete."
