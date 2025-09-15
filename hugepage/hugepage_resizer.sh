#!/bin/bash

GUEST_NAME="$1"
RAM_KB="$2"
LOG="/etc/libvirt/hooks/qemu.log"

# new value is the number of pages required by the vm
NEW_VALUE=$(( ((RAM_KB + (2048 - (RAM_KB % 2048)))/2048) ))

# current value is the number of pages already allocated
CURRENT_VALUE=$(cat /proc/sys/vm/nr_hugepages)

# update value sum or subtract the new value from the current value based on the 3rd script parameter
if [ "$3" == "start" ]; then
        UPDATED_VALUE=$((CURRENT_VALUE + NEW_VALUE))
else
        UPDATED_VALUE=$((CURRENT_VALUE - NEW_VALUE))
        if [ "$UPDATED_VALUE" -lt 0 ]; then
                UPDATED_VALUE=0
        fi
fi

TRIES=0
while (( $CURRENT_VALUE != $UPDATED_VALUE && $TRIES < 500 ))
do
    echo 1 > /proc/sys/vm/compact_memory                        ## defrag ram
    echo 0 > /proc/sys/vm/nr_overcommit_hugepages               ## disable overcommit
    ## update swappiness to 100-150 when zram implemented
    echo $UPDATED_VALUE > /proc/sys/vm/nr_hugepages
    CURRENT_VALUE=$(cat /proc/sys/vm/nr_hugepages)
    echo "Succesfully allocated hugepages" >> "$LOG"
    let TRIES+=1
done


if [ "$CURRENT_VALUE" -ne "$UPDATED_VALUE" ]
then
    echo "Not able to allocate all hugepages. Reverting..." >> "$LOG"
    echo 0 > /proc/sys/vm/nr_hugepages
    exit 1
fi