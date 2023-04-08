#!/bin/bash
#version=2.0.0

# this script is to perform:
#   1. extracting modules folder from docker image after docker run it.
#   2. copying module files into /lib/modules/ respective's kernel version folders.
#   3. creating driver config file in /usr/local/etc/modules.d/.
#
# example: ./drivers_pioven.sh docker.corp.jabil.org/raspberry-pi/arducam-16mp b5f97c94-af0b-11ec-974d-0242ac110002 /dev/sda2

# parameter(s)
DRIVER_NAME=$1
OS_VERSION=$2
TARGET_DEVICE=$3

# set log path
LOG_PATH=$(/scripts/libs/drivers_log_path.lib)

echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] START - /scripts/drivers_pi_oven.sh" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log

PRINT_END() {
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] END - /scripts/drivers_pi_oven.sh" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  echo "-" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  echo "-" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  echo "-" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
}

# ensure parameter 1 exists
if [ "$DRIVER_NAME" == "" ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: (parameter 1) driver name variable is empty." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  PRINT_END

  echo "ERROR: (parameter 1) driver name variable is empty."
  exit 1
fi

# ensure parameter 2 exists
if [ "$OS_VERSION" == "" ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: (parameter 2) os version variable is empty." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  PRINT_END

  echo "ERROR: (parameter 2) os version variable is empty."
  exit 1
else
  # ensure it is uuid
  OS_VERSION_LENGTH=$(echo $OS_VERSION | grep -o "[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}" | wc -c)

  # ensure it is 36 characters long
  if [ "$OS_VERSION_LENGTH" != "37" ]; then
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: (parameter 2) os version is not valid uuid." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
    PRINT_END

    echo "ERROR: (parameter 2) os version is not valid uuid."
    exit 1
  fi
fi

# ensure parameter 3 exists
if [ "$TARGET_DEVICE" == "" ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: (parameter 3) device target variable is empty." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  PRINT_END

  echo "ERROR: (parameter 3) device target variable is empty."
  exit 1
fi

# obtain first 13 characters from os version
IMAGE_TAG=$(echo $OS_VERSION | cut -c1-13)
IMAGE="$DRIVER_NAME:$IMAGE_TAG"

# mount target device partition 2 to /mnt/part2
MOUNT_PATH="/mnt/part2"
mkdir -p $MOUNT_PATH
mount $TARGET_DEVICE $MOUNT_PATH
CHECK_MOUNT=$(mount | grep $TARGET_DEVICE)

# ensure /mnt/part2 is mounted
if [ "$CHECK_MOUNT" == "" ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: mount $TARGET_DEVICE failed." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  PRINT_END

  echo "ERROR: mount $TARGET_DEVICE failed."
  exit 1
fi

# extract module folder with its files into temporary /storage/drivers/ directory from docker container
/scripts/libs/drivers_extract_modules.lib $IMAGE
RES="$?"

# exit program if failure found
if [ "$RES" -ne 0 ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: abort extracting module paths." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  PRINT_END

  echo "ERROR: abort extracting module paths."
  exit 1
fi 

# copy the module files from /storage/drivers/ to /mnt/part2/lib/modules/
/scripts/libs/drivers_copy_modules.lib $IMAGE $MOUNT_PATH
RES="$?"

# exit program if failure found
if [ "$RES" -ne 0 ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: abort copying module files." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  PRINT_END

  echo "ERROR: abort copying module files."
  exit 1
fi

# create driver config file in /mnt/part2/usr/local/etc/modules.d/
/scripts/libs/drivers_create_conf_file.lib $IMAGE $MOUNT_PATH
RES="$?"

# exit program if failure found
if [ "$RES" -ne 0 ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: abort creating config." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  PRINT_END

  echo "ERROR: abort creating config."
  exit 1
fi

# umount target device /mnt/part2
umount $MOUNT_PATH

PRINT_END

echo "Done running pioven_drivers.sh..."