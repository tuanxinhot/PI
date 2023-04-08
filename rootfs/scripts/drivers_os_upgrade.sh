#!/bin/bash
#version=2.0.0

# this script is to perform:
#   1. checking all driver config files in /usr/local/etc/modules.d/.
#   2. mount new os from partition 3 to /mnt/part3.
#   3. performing all these tasks for new os.
#     a. extracting modules folder from docker image after docker run it.
#     b. copying module files into /mnt/part3/lib/modules respective's kernel version folders.
#     c. creating driver config file in /mnt/part3/usr/local/etc/modules.d/.
#     d. uninstalling the current kernel version's driver.
#     e. reinstalling all uninstalled drivers if failure happened.
#
# example: ./drivers_os_upgrade.sh

# parameter(s)
# none

# set log path
LOG_PATH=$(/scripts/libs/drivers_log_path.lib)

echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] START - /scripts/drivers_os_upgrade.sh" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log

PRINT_END() {
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] END - /scripts/drivers_os_upgrade.sh" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  echo "-" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  echo "-" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  echo "-" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
}

# define exit code
ERROR_EXIT_CODE="FALSE"
# define uninstall flag
UNINSTALL_FLAG="FALSE"

# define driver config file base path
CONF_FILE_BASE_PATH="/usr/local/etc/modules.d/"

if [ ! -d $CONF_FILE_BASE_PATH ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: $CONF_FILE_BASE_PATH not found." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  PRINT_END

  echo "ERROR: $CONF_FILE_BASE_PATH not found."
  exit 0
fi

# get all full path of driver config files
CONF_FILES=$(find $CONF_FILE_BASE_PATH -type f -name "*.conf")

# ensure there is at least a driver config file
if [ "$CONF_FILES" != "" ]; then
  # get current running kernel version
  CURRENT_KERNEL_VERSION=$(uname -r)

  # define library modules path
  DRIVER_BASE_PATH="/lib/modules"

  # get partition 2
  DEVICE_PART_2=$(findmnt / -o source -n)
  DEVICE_PART_2_NAME=$(echo "$DEVICE_PART_2" | cut -d "/" -f 3)
  DEVICE_NAME=$(echo /sys/block/*/"${DEVICE_PART_2_NAME}" | cut -d "/" -f 4)
  # get partition 3
  DEVICE_PART_3_NAME=$(ls /sys/block/"${DEVICE_NAME}" | grep ${DEVICE_PART_2_NAME::-1}3$)
  DEVICE_PART_3="/dev/${DEVICE_PART_3_NAME}"
  # get device
  DEVICE="/dev/${DEVICE_NAME}"

  # get new os version
  NEW_OS_VERSION="`dumpe2fs -h $DEVICE_PART_3 2>&1 | grep 'Filesystem UUID' | cut -d: -f 2 | tr -d ' '`"
  # get image tag
  IMAGE_TAG=$(echo $NEW_OS_VERSION | cut -c1-13)

  # mount partition 3 for new os
  MOUNT_PATH="/mnt/part3"
  mkdir -p $MOUNT_PATH
  umount $MOUNT_PATH 2&> /dev/null
  mount $DEVICE_PART_3 $MOUNT_PATH
  CHECK_MOUNT=$(mount | grep $DEVICE_PART_3)

  # ensure /mnt/part3 is mounted
  if [ "$CHECK_MOUNT" == "" ]; then
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: mount $DEVICE_PART_3 failed." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
    PRINT_END

    echo "ERROR: mount $DEVICE_PART_3 failed."
    exit 1
  fi

  # get the config file base path length
  CONF_FILE_BASE_PATH_LENGTH=${#CONF_FILE_BASE_PATH}

  # iterate all driver config files
  for CONF_FILE in $CONF_FILES; do
    if [ "$ERROR_EXIT_CODE"  == "FALSE" ]; then
      CONF_FILE_LENGTH=${#CONF_FILE}
      # get driver name from the config file path
      DRIVER_NAME=$(echo $CONF_FILE | cut -c$((CONF_FILE_BASE_PATH_LENGTH+1))-$((CONF_FILE_LENGTH-5)))
      # set image name
      IMAGE="$DRIVER_NAME:$IMAGE_TAG"
      # get driver full path
      DRIVER_PATH="$DRIVER_BASE_PATH/$CURRENT_KERNEL_VERSION/extra/$DRIVER_NAME"
      # get status from CONF_FILE
      DRIVER_STATUS=$(cat $CONF_FILE | grep $CURRENT_KERNEL_VERSION | awk '{print $2}')

      if [ "$DRIVER_STATUS" == "1" ]; then
        # extract module folder with its files into temporary /storage/drivers/ directory from docker container
        /scripts/libs/drivers_extract_modules.lib $IMAGE
        RES="$?"

        if [ "$RES" -ne 0 ]; then
          echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: abort extracting module paths." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
          echo "ERROR: abort extracting module paths."
          ERROR_EXIT_CODE="TRUE"
        else
          # copy the module files from /storage/drivers/ to /mnt/part3/lib/modules/
          /scripts/libs/drivers_copy_modules.lib $IMAGE $MOUNT_PATH
          RES="$?"

          if [ "$RES" -ne 0 ]; then
            echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: abort copying module files." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
            echo "ERROR: abort copying module files."
            ERROR_EXIT_CODE="TRUE"
          else
            # create driver config file in /mnt/part3/usr/local/etc/modules.d/
            /scripts/libs/drivers_create_conf_file.lib $IMAGE $MOUNT_PATH
            RES="$?"

            if [ "$RES" -ne 0 ]; then
              echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: abort creating config." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
              echo "ERROR: abort creating config."
              ERROR_EXIT_CODE="TRUE"
            else
              # define the osupgrade file path
              OSUPGRADE_CONF_FILE="$CONF_FILE_BASE_PATH$DRIVER_NAME.osupgrade"

              # if install.sh and uninstall.sh files found from the driver path
              if [ -f "$DRIVER_PATH/uninstall.sh" ]; then
                # set the uninstall flag
                UNINSTALL_FLAG="TRUE"
                # get current path
                CURRENT_PATH=$(pwd)
                # do driver uninstallation
                /scripts/libs/drivers_uninstall_module.lib $DRIVER_PATH $CONF_FILE $CURRENT_KERNEL_VERSION 1
                RES="$?"
                # go back current path
                cd $CURRENT_PATH

                if [ "$RES" -ne 0 ]; then
                  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: uninstallation failure." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
                  echo "ERROR: uninstallation failure."
                  ERROR_EXIT_CODE="TRUE"
                else
                  # the idea is to rename the config file extension to *.osupgrade
                  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] INFO: Renaming $CONF_FILE => $OSUPGRADE_CONF_FILE." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
                  echo "Renaming $CONF_FILE => $OSUPGRADE_CONF_FILE."
                  rm -f $OSUPGRADE_CONF_FILE
                  mv $CONF_FILE $OSUPGRADE_CONF_FILE
                fi
              fi
            fi
          fi
        fi
      fi
    fi
  done

  # during os upgrade and when in the middle contains of driver uninstallation failure, reinstall all the uninstalled drivers
  if [ "$ERROR_EXIT_CODE" == "TRUE" ]; then
    # get all full path of driver config files with *.osupgrade extension
    OSUPGRADE_FILES=$(find $CONF_FILE_BASE_PATH -type f -name "*.osupgrade")

    # iterate all osupgrade extension config files
    for OSUPGRADE_FILE in $OSUPGRADE_FILES; do
      OSUPGRADE_FILE_LENGTH=${#OSUPGRADE_FILE}
      # get driver name from the config file path
      DRIVER_NAME=$(echo $OSUPGRADE_FILE | cut -c$((CONF_FILE_BASE_PATH_LENGTH+1))-$((OSUPGRADE_FILE_LENGTH-10)))
      # get driver full path
      DRIVER_PATH="$DRIVER_BASE_PATH/$CURRENT_KERNEL_VERSION/extra/$DRIVER_NAME"
      # reinstall back the drivers
      /scripts/libs/drivers_install_module.lib $DRIVER_PATH $OSUPGRADE_FILE $CURRENT_KERNEL_VERSION

      if [ "$RES" -ne 0 ]; then
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: installation failure." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
        echo "ERROR: installation failure."
      else
        # rename *.osupgrade extension to *.conf extension
        CONF_FILE="$CONF_FILE_BASE_PATH$DRIVER_NAME.conf"
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] INFO: Renaming $OSUPGRADE_FILE => $CONF_FILE." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
        echo "Renaming $OSUPGRADE_FILE => $CONF_FILE."
        mv $OSUPGRADE_FILE $CONF_FILE
      fi
    done
  fi

  # unmount partition 3
  umount $MOUNT_PATH 2&> /dev/null
fi

PRINT_END

if [ $ERROR_EXIT_CODE == "TRUE" ]; then
  exit 1
else
  if [ $UNINSTALL_FLAG == "TRUE" ]; then
    exit 10
  fi
fi