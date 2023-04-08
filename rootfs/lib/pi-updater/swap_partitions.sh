#!/bin/bash
#version=2.0.0

PARAM_1=$1

# get partition #2
DEVICE_PART_2=$(findmnt / -o source -n)
DEVICE_PART_2_NAME=$(echo "$DEVICE_PART_2" | cut -d "/" -f 3)
DEVICE_NAME=$(echo /sys/block/*/"${DEVICE_PART_2_NAME}" | cut -d "/" -f 4)
# get partition #4
DEVICE_PART_4_NAME=$(ls /sys/block/"${DEVICE_NAME}" | grep ${DEVICE_PART_2_NAME::-1}4$)
DEVICE_PART_4="/dev/${DEVICE_PART_4_NAME}"
# get partition #3
DEVICE_PART_3_NAME=$(ls /sys/block/"${DEVICE_NAME}" | grep ${DEVICE_PART_2_NAME::-1}3$)
DEVICE_PART_3="/dev/${DEVICE_PART_3_NAME}"
# get partition #1
DEVICE_PART_1_NAME=$(ls /sys/block/"${DEVICE_NAME}" | grep ${DEVICE_PART_2_NAME::-1}1$)
DEVICE_PART_1="/dev/${DEVICE_PART_1_NAME}"
# get device
DEVICE="/dev/${DEVICE_NAME}"

# get partition 4 name
PART4="`echo $DEVICE_PART_4 | cut -c6-`"
# check /storage space left
STORAGE_SPACE_LEFT="`df $DEVICE_PART_4 | grep $PART4 | awk '{print $4}'`"
# get risk level
BRANCH="`cat /boot/updater/risk.txt | egrep -v -e '^#' -e '^( *)$'`"

# configure new os fstab
FSTAB_CONFIG(){
  # mount partition 3 to /mnt/part3
  MOUNT_PATH="/mnt/part3"
  mkdir -p $MOUNT_PATH
  umount $MOUNT_PATH 2&> /dev/null
  mount $DEVICE_PART_3 $MOUNT_PATH

  FSTAB="$MOUNT_PATH/etc/fstab"

  # get partuuid
  PARTUUID_1=$(blkid | grep $DEVICE_PART_1 | grep -o "PARTUUID=\"[a-f0-9]\{8\}-[0-9]\{2\}\"" | tr -d '"')
  PARTUUID_2=$(blkid | grep $DEVICE_PART_2 | grep -o "PARTUUID=\"[a-f0-9]\{8\}-[0-9]\{2\}\"" | tr -d '"')
  PARTUUID_4=$(blkid | grep $DEVICE_PART_4 | grep -o "PARTUUID=\"[a-f0-9]\{8\}-[0-9]\{2\}\"" | tr -d '"')
  sed -i 's| root=[^ ]* | root='$PARTUUID_2' |' /boot/cmdline.txt

  # write to fstab with partuuid
  echo "proc                  /proc           proc    defaults          0       0" > $FSTAB
  echo "$PARTUUID_1  /boot           vfat    defaults,uid=1000,gid=8888,fmask=0002,dmask=0002  0       2" >> $FSTAB
  echo "$PARTUUID_2  /               ext4    defaults,noatime  0       1" >> $FSTAB
  echo "$PARTUUID_4  /storage        ext4    defaults,noatime  0       2" >> $FSTAB

  # unmount /mnt/part3
  umount $MOUNT_PATH 2&> /dev/null
 }

# swap partition 2 to 3 and 3 to 2
SWAP_PARTITION(){
  # get partition #3 os uuid
  PART3_ID="`dumpe2fs -h \"$DEVICE_PART_3\" 2>&1 | grep 'Filesystem UUID' | cut -d: -f 2 | tr -d ' '`"

  # figure out the current start/stop sectors for the partitions
  TWO_START_SECTOR="`parted -m \"$DEVICE\" unit s print |egrep '^2:' |cut -d: -f 2`"
  TWO_END_SECTOR="`parted -m \"$DEVICE\" unit s print |egrep '^2:' |cut -d: -f 3`"

  THREE_START_SECTOR="`parted -m \"$DEVICE\" unit s print |egrep '^3:' |cut -d: -f 2`"
  THREE_END_SECTOR="`parted -m \"$DEVICE\" unit s print |egrep '^3:' |cut -d: -f 3`"

  # clean out the paritions we're going to swap
  parted -s "$DEVICE" rm 2
  parted -s "$DEVICE" rm 3

  # make 3 first, so it becomes 2
  parted -s -a none "$DEVICE" mkpart p ext4 "$THREE_START_SECTOR" "$THREE_END_SECTOR"
  # now make 2, so it becomes 3
  parted -s -a none "$DEVICE" mkpart p ext4 "$TWO_START_SECTOR" "$TWO_END_SECTOR"

  # remove the status
  rm -f /root/$PART3_ID/complete
}

# when it is os upgrade option
if [ "$PARAM_1" == "" ]; then
  CONF_FILE_BASE_PATH="/usr/local/etc/modules.d/"
  DRIVER_UPGRADE=false

  # check if driver config directory exists
  if [ -d "$CONF_FILE_BASE_PATH" ]; then
    CONF_FILES=$(find $CONF_FILE_BASE_PATH -type f -name "*.conf")

    if [ "$CONF_FILES" != "" ]; then
      DRIVER_UPGRADE=true
    fi
  fi

  # when risk contains of 64 in os upgrade
  if [[ "$BRANCH" == *64 ]]; then
    # when storage size is bigger than 100mb
    if [ "$STORAGE_SPACE_LEFT" != "" ] && [ $STORAGE_SPACE_LEFT -gt 100 ]; then
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Moving old /boot files to /storage..."

      # get partition #3 os uuid
      PART2_ID="`dumpe2fs -h \"$DEVICE_PART_2\" 2>&1 | grep 'Filesystem UUID' | cut -d: -f 2 | tr -d ' '`"
      # set temporary os backup boot path
      OS_BACKUP_PATH="/storage/$PART2_ID/os_backup/boot"

      # backup and remove current /boot system to /storage/{os_uuid}/os_backup/boot
      mkdir -p $OS_BACKUP_PATH/overlays
      mv /boot/kernel*.img $OS_BACKUP_PATH
      mv /boot/*.elf $OS_BACKUP_PATH
      mv /boot/*.dat $OS_BACKUP_PATH
      mv /boot/*.dtb $OS_BACKUP_PATH
      mv /boot/bootcode.bin $OS_BACKUP_PATH
      mv /boot/overlays/* $OS_BACKUP_PATH/overlays/
      sync

      if [ $DRIVER_UPGRADE == true ]; then
        # perform driver os upgrade task
        /scripts/drivers_os_upgrade.sh
        RES="$?"

        # when os upgrade has no error
        if [ "$RES" -eq 0 ]; then
          # configure new os fstab
          FSTAB_CONFIG
          # swap partition 2 to 3 and 3 to 2
          SWAP_PARTITION
          exit 0
        elif [ "$RES" -eq 10 ]; then
          # configure new os fstab
          FSTAB_CONFIG
          # swap partition 2 to 3 and 3 to 2
          SWAP_PARTITION
          exit 10
        else
          # when os upgrade has error
          exit 2
        fi
      else
        # configure new os fstab
        FSTAB_CONFIG
        # swap partition 2 to 3 and 3 to 2
        SWAP_PARTITION
        exit 0
      fi
    else
      # when storage size is not enough
      exit 1
    fi
  else
    if [ $DRIVER_UPGRADE == true ]; then
      # perform driver os upgrade task
      /scripts/drivers_os_upgrade.sh
      RES="$?"

      # when os upgrade has no error
      if [ "$RES" -eq 0 ]; then
        # configure new os fstab
        FSTAB_CONFIG
        # swap partition 2 to 3 and 3 to 2
        SWAP_PARTITION
        exit 0
      elif [ "$RES" -eq 10 ]; then
        # configure new os fstab
        FSTAB_CONFIG
        # swap partition 2 to 3 and 3 to 2
        SWAP_PARTITION
        exit 10
      else
        # when os upgrade has error
        exit 2
      fi
    else
      # configure new os fstab
      FSTAB_CONFIG
      # swap partition 2 to 3 and 3 to 2
      SWAP_PARTITION
      exit 0
    fi
  fi
else
  # when it is roll back option
  if [ "$PARAM_1" == "rollback" ]; then
    # configure new os fstab
    FSTAB_CONFIG
    # swap partition 2 to 3 and 3 to 2
    SWAP_PARTITION
    exit 0
  fi
fi