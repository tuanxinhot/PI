#!/bin/bash
#version=2.0.0

# this script is to perform:
#   1. checking all driver config files in /usr/local/etc/modules.d/.
#   2. performing all these tasks if found files.
#     a. uninstalling the driver with uninstall file from driver config path.
#     b. renaming config file to os rollback file from driver config path.
#     c. reinstalling all uninstalled drivers if failure happened and exit this script.
#   3. checking all driver osupgrade files in /{previous_os_mount_point}/usr/local/etc/modules.d/.
#   4. performing all these tasks if found files.
#     a. renaming file extension back to normal config file.
#     b. reseting installation 0 status to the driver config file for rollback driver installation.
#
# example: ./drivers_os_rollback.sh /mnt/part3

# parameter(s)
# mount partition 3 for previous os
MOUNT_PATH=$1

# set log path
LOG_PATH=$(/scripts/libs/drivers_log_path.lib)

echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] START - /scripts/drivers_uninstall.sh" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log

PRINT_END() {
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] END - /scripts/drivers_uninstall.sh" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  echo "-" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  echo "-" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  echo "-" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
}

# define exit code
ERROR_EXIT_CODE="FALSE"

# define driver uninstall file base path
CONF_FILE_BASE_PATH="/usr/local/etc/modules.d/"
# get the config file base path length
CONF_FILE_BASE_PATH_LENGTH=${#CONF_FILE_BASE_PATH}

if [ -d $CONF_FILE_BASE_PATH ]; then
  # get all full path of driver config files
  CONF_FILES=$(find $CONF_FILE_BASE_PATH -type f -name "*.conf")

  # ensure there is at least a driver config file
  if [ "$CONF_FILES" != "" ]; then
    # get current running kernel version
    CURRENT_KERNEL_VERSION=$(uname -r)
    # define library modules path
    DRIVER_BASE_PATH="/lib/modules"

    # iterate all driver config files
    for CONF_FILE in $CONF_FILES; do
      CONF_FILE_LENGTH=${#CONF_FILE}
      # get driver name from the config file path
      DRIVER_NAME=$(echo $CONF_FILE | cut -c$((CONF_FILE_BASE_PATH_LENGTH+1))-$((CONF_FILE_LENGTH-5)))
      # get driver full path
      DRIVER_PATH="$DRIVER_BASE_PATH/$CURRENT_KERNEL_VERSION/extra/$DRIVER_NAME"

      # get current path
      CURRENT_PATH=$(pwd)
      /scripts/libs/drivers_uninstall_module.lib $DRIVER_PATH $CONF_FILE $CURRENT_KERNEL_VERSION 1
      RES="$?"
      # go back current path
      cd $CURRENT_PATH

      if [ "$RES" -ne 0 ]; then
        ERROR_EXIT_CODE="TRUE"
      else
        # the idea is to rename the config file extension to *.osrollback
        OSROLLBACK_CONF_FILE="$CONF_FILE_BASE_PATH$DRIVER_NAME.osrollback"
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] INFO: Renaming $CONF_FILE => $OSROLLBACK_CONF_FILE." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
        echo "Renaming $CONF_FILE => $OSROLLBACK_CONF_FILE."
        rm -f $OSROLLBACK_CONF_FILE
        mv $CONF_FILE $OSROLLBACK_CONF_FILE
      fi
    done
  fi
fi

# during os upgrade and when in the middle contains of driver uninstallation failure, reinstall all the uninstalled drivers
if [ "$ERROR_EXIT_CODE" == "TRUE" ]; then
  # get all full path of driver config files with *.osrollback extension
  OSROLLBACK_FILES=$(find $CONF_FILE_BASE_PATH -type f -name "*.osrollback")

  # iterate all osrollback extension config files
  for OSROLLBACK_FILE in $OSROLLBACK_FILES; do
    OSROLLBACK_FILE_LENGTH=${#OSROLLBACK_FILE}
    # get driver name from the config file path
    DRIVER_NAME=$(echo $OSROLLBACK_FILE | cut -c$((CONF_FILE_BASE_PATH_LENGTH+1))-$((OSROLLBACK_FILE_LENGTH-11)))
    # get driver full path
    DRIVER_PATH="$DRIVER_BASE_PATH/$CURRENT_KERNEL_VERSION/extra/$DRIVER_NAME"
    # reinstall back the drivers
    /scripts/libs/drivers_install_module.lib $DRIVER_PATH $OSROLLBACK_FILE $CURRENT_KERNEL_VERSION

    if [ "$RES" -ne 0 ]; then
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: installation failure." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
      echo "ERROR: installation failure."
    else
      # rename *.osrollback extension to *.conf extension
      CONF_FILE="$CONF_FILE_BASE_PATH$DRIVER_NAME.conf"
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] INFO: Renaming $OSROLLBACK_FILE => $CONF_FILE." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
      echo "Renaming $OSROLLBACK_FILE => $CONF_FILE."
      mv $OSROLLBACK_FILE $CONF_FILE
    fi
  done

  exit 1
else
  # define previous os driver config file base path
  PREV_OS_CONF_FILE_BASE_PATH="$MOUNT_PATH/usr/local/etc/modules.d/"

  # get all full path of driver config files with *.osupgrade extension
  OSUPGRADE_FILES=$(find $PREV_OS_CONF_FILE_BASE_PATH -type f -name "*.osupgrade")

  # ensure there is at least a osupgrade's driver config file
  if [ "$OSUPGRADE_FILES" != "" ]; then
    # iterate all driver osupgrade's driver config files
    for OSUPGRADE_FILE in $OSUPGRADE_FILES; do
      # renaming back osupgrade's driver config file to normal driver config file
      mv $OSUPGRADE_FILE ${OSUPGRADE_FILE::-10}.conf
      # reset installation status 0 to the driver config file for rollback driver installation
      sed -i 's/ .*/ 0/' ${OSUPGRADE_FILE::-10}.conf
    done
  fi
fi