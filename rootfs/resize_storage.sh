#!/bin/bash

reboot_pi () {
  umount /storage
  umount /boot
  sync
  echo b > /proc/sysrq-trigger
  sleep 5
  exit 0
}

mount -t proc proc /proc
mount -t sysfs sys /sys
mount / -o remount,ro

DEVICE_PART_2=$(findmnt / -o source -n)
DEVICE_PART_2_NAME=$(echo "$DEVICE_PART_2" | cut -d "/" -f 3)
DEVICE_NAME=$(echo /sys/block/*/"${DEVICE_PART_2_NAME}" | cut -d "/" -f 4)
DEVICE_PART_4_NAME=$(ls /sys/block/"${DEVICE_NAME}" | grep ${DEVICE_PART_2_NAME::-1}4$)
DEVICE_PART_4="/dev/${DEVICE_PART_4_NAME}"
DEVICE="/dev/${DEVICE_NAME}"

DISK_SECTORS="`parted \"$DEVICE\" unit s print -m | head -n 2 | tail -n 1 | cut -d: -f 2 | cut -ds -f1`"
CURRENT_END="`parted \"$DEVICE\" unit s print -m | egrep '^4:' | cut -d: -f 3 | cut -ds -f1`"
CURRENT_START="`parted \"$DEVICE\" unit s print -m | egrep '^4:' | cut -d: -f 2 | cut -ds -f1`"
echo -e "DISK Size: ${DISK_SECTORS}\t 4th Partition End: ${CURRENT_END}"

if [ "$((DISK_SECTORS - 1))" -gt "$CURRENT_END" ]; then
  echo "d
4
n
p
4
$CURRENT_START
$((DISK_SECTORS - 1))
p
w
" | fdisk $DEVICE
  fsck.ext4 -f "${DEVICE_PART_4}"

  mount /boot
  mount "${DEVICE_PART_4}" /storage

  resize2fs "${DEVICE_PART_4}"

  if [ /boot/firstrun.sh ]; then
    rm -f /boot/firstrun.sh
    sed -i 's| systemd.run.*||g' /boot/cmdline.txt
  fi

  sed -i 's| quiet init=/resize_storage.sh||' /boot/cmdline.txt

  mount / -o remount,rw

  OLD_DISKID=$(fdisk -l "$DEVICE" | sed -n 's/Disk identifier: 0x\([^ ]*\)/\1/p')
  NEW_DISKID="$(tr -dc 'a-f0-9' < /dev/hwrng | dd bs=1 count=8 2>/dev/null)"

  fdisk "$DEVICE" > /dev/null <<EOF
x
i
0x$NEW_DISKID
r
w
EOF

  if [ "$?" -eq 0 ]; then
    sed -i "s/${OLD_DISKID}/${NEW_DISKID}/g" /etc/fstab
    sed -i "s/${OLD_DISKID}/${NEW_DISKID}/" /boot/cmdline.txt
    sync
  fi

  mount / -o remount,ro
  mount /boot -o remount,ro

  sync

  echo 1 > /proc/sys/kernel/sysrq

  reboot_pi
else
  echo "Partition already fills disk"
fi
