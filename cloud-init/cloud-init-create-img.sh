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

# Create an overlay layer for the cloud-init image
echo "Creating an overlay layer for the cloud-init image..."
format=$(qemu-img info $output_path/cloud-init.img | grep 'file format' | awk '{print $3}')
if [ "$format" == "raw" ]; then
    qemu-img convert -f raw -O qcow2 $output_path/cloud-init.img $output_path/cloud-init.qcow2
    mv $output_path/cloud-init.qcow2 $output_path/cloud-init.img
    rm $output_path/cloud-init.qcow2
fi
output=$(qemu-img create -f qcow2 -F $format -o backing_file=$output_path/cloud-init.img $output_path/cloud-init.qcow2 2>&1)
echo "$output"
echo "Overlay layer creation complete."

# Convert the qcow2 image to iso
echo "Converting qcow2 image to iso format..."
output=$(genisoimage -output $output_path/cidata.iso -volid cidata -joliet -rock $path_to_files/user-data $path_to_files/meta-data 2>&1)
echo "$output" | grep -oP '(?<=Added to ISO image: file )[^ ]+'
echo "$output" | grep -oP '(?<=ISO image produced: )[^ ]+'
echo "$output" | grep -oP '(?<=Written to medium : )[^ ]+'
echo "Conversion complete."

echo -e "
<disk type='file' device='disk'>
    <driver name='qemu' type='qcow2'/>
    <source file='$output_path/cloud-init.qcow2'/>
    <backingStore type='file'>
        <format type='qcow2'/>
        <source file='$output_path/cloud-init.img'/>
    </backingStore>
    <target dev='vda' bus='virtio'/>
    <address type='pci' domain='0x0000' bus='0x00' slot='0x0a' function='0x0'/>
</disk>
<disk type='file' device='cdrom'>
    <driver name='qemu' type='raw' discard='unmap'/>
    <source file='$output_path/cidata.iso'/>
    <target dev='sda' bus='scsi'/>
    <readonly/>
    <address type='drive' controller='0' bus='0' target='0' unit='0'/>
</disk>" > $output_path/cloud-init.xml

echo "Cloud-init images created successfully at $output_path"
echo "Listing files in $output_path..."
tree $output_path
echo "Listing complete."
