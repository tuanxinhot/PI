#!/bin/bash
#version=2.0.0

DEVICE_PART_2=$(findmnt / -o source -n)
DEVICE_PART_2_NAME=$(echo "$DEVICE_PART_2" | cut -d "/" -f 3)
DEVICE_NAME=$(echo /sys/block/*/"${DEVICE_PART_2_NAME}" | cut -d "/" -f 4)
DEVICE_PART_3_NAME=$(ls /sys/block/"${DEVICE_NAME}" | grep ${DEVICE_PART_2_NAME::-1}3$)
DEVICE_PART_3="/dev/${DEVICE_PART_3_NAME}"

P3="`dumpe2fs -h \"$DEVICE_PART_3\" 2>&1 | grep 'Filesystem UUID' | cut -d: -f 2 | tr -d ' '`"

if [ ${#P3} -gt 0 ]; then
  if [ -f /root/$P3/complete ]; then
    /usr/lib/pi-updater/swap_partitions.sh
    rm -f /root/$P3/complete

    echo "Finished swapping partitions, ready to reboot in 30 seconds..."
    sleep 30s
    /sbin/reboot
  else
    echo "Partition 3 is not ready to swap!"
  fi
else
  echo "Partition 3 is empty!"
fi