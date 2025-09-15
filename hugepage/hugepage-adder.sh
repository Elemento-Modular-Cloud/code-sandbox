#!/bin/bash

# Update grub config
echo "Updating grub config to enable hugepages"
sudo grubby --update-kernel=ALL --args="default_hugepagesz=2M hugepages=0"

# create hugepage mount point
echo "Creating hugepage mount point"
sudo mkdir -p /mnt/huge
sudo echo "nodev /mnt/huge hugetlbfs pagesize=2MB 0 0" >> /etc/fstab
sudo mount -a



