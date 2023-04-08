#!/bin/bash
#version=2.0.0

BOOT_BACKUP="/os_backup/boot"
MOUNT_PATH="/mnt/part3"

DEVICE_PART_2=$(findmnt / -o source -n)
DEVICE_PART_2_NAME=$(echo "$DEVICE_PART_2" | cut -d "/" -f 3)
DEVICE_NAME=$(echo /sys/block/*/"${DEVICE_PART_2_NAME}" | cut -d "/" -f 4)
DEVICE_PART_3_NAME=$(ls /sys/block/"${DEVICE_NAME}" | grep ${DEVICE_PART_2_NAME::-1}3$)
DEVICE_PART_3="/dev/${DEVICE_PART_3_NAME}"

# check if boot backup available
if [ -d $BOOT_BACKUP ]; then
  PART3_ID="`dumpe2fs -h \"$DEVICE_PART_3\" 2>&1 | grep 'Filesystem UUID' | cut -d: -f 2 | tr -d ' '`"

  if [ -e $DEVICE_PART_3 ] && [ "$PART3_ID" != "" ]; then
    echo "Setup system container to previous OS..."
    # make sure the mount point unmount
    umount $MOUNT_PATH 2> /dev/null
    # make sure the mount point folder existed
    mkdir -p $MOUNT_PATH
    # mount partition 1 to mount point
    mount $DEVICE_PART_3 $MOUNT_PATH

    # set rollback driver installation
    /scripts/drivers_os_rollback.sh $MOUNT_PATH
    RES="$?"

    if [ "$RES" -eq 0 ]; then
      #Remove previous OS rollback to prevent incorrect rollback
      yes | cp /usr/lib/pi-updater/*.sh $MOUNT_PATH/usr/lib/pi-updater/
      yes | cp -R /scripts/ $MOUNT_PATH/
      rm -f $MOUNT_PATH/lib/systemd/system/rollback.service
      rm -f $MOUNT_PATH/usr/lib/pi-updater/rollback.sh
      rm -rf $MOUNT_PATH$BOOT_BACKUP
    fi

    # unmount the mount point
    umount $MOUNT_PATH 2> /dev/null

    if [ "$RES" -eq 0 ]; then
      # restore the boot backup
      echo "Restoring boot backup..."
      cp -R $BOOT_BACKUP/* /boot/

      # swap partition #2 to #3 and vice versa
      echo "Swapping partition #2 > partition #3 and vice versa."
      /usr/lib/pi-updater/swap_partitions.sh rollback

      # reboot
      echo "Rebooting..."
      reboot
    else
      echo "Failed to rollback due to driver uninstallation issue..."
    fi
  else
    echo "$DEVICE_PART_3 is not valid Jabil Pi OS partition."
  fi
else
  echo "Boot backup folder not found..."
fi