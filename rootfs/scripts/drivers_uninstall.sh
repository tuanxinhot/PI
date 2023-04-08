#!/bin/bash
#version=2.0.0

# this script is to perform:
#   1. checking all driver uninstall files in /usr/local/etc/modules.d/.
#   2. performing all these tasks if driver not exists in /lib/modules/.
#     a. uninstalling the driver with uninstall file from driver config path.
#     b. deleting config file and uninstall file from driver config path.
#
# example: ./drivers_uninstall.sh

# parameter(s)
# none

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
UNINST_FILE_BASE_PATH="/usr/local/etc/modules.d/"

if [ ! -d $UNINST_FILE_BASE_PATH ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: $UNINST_FILE_BASE_PATH not found." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  PRINT_END

  echo "ERROR: $UNINST_FILE_BASE_PATH not found."
  exit 0
fi

# get all full path of driver uninstall files
UNINST_FILES=$(find $UNINST_FILE_BASE_PATH -type f -name "*.uninst")

# ensure there is at least a driver uninstall file
if [ "$UNINST_FILES" != "" ]; then
  # get current running kernel version
  CURRENT_KERNEL_VERSION=$(uname -r)
  # define library modules path
  DRIVER_BASE_PATH="/lib/modules"
  # get the uninstall file base path length
  UNINST_FILE_BASE_PATH_LENGTH=${#UNINST_FILE_BASE_PATH}

  # iterate all driver uninstall files
  for UNINST_FILE in $UNINST_FILES; do
    UNINST_FILE_LENGTH=${#UNINST_FILE}
    # get driver name from the uninstall file path
    DRIVER_NAME=$(echo $UNINST_FILE | cut -c$((UNINST_FILE_BASE_PATH_LENGTH+1))-$((UNINST_FILE_LENGTH-7)))
    # get driver full path
    DRIVER_PATH="$DRIVER_BASE_PATH/$CURRENT_KERNEL_VERSION/extra/$DRIVER_NAME"

    /scripts/libs/drivers_uninstall_module.lib $DRIVER_PATH $UNINST_FILE $CURRENT_KERNEL_VERSION
    RES="$?"

    if [ "$RES" -ne 0 ]; then
      ERROR_EXIT_CODE="TRUE"
    else
      # deleting config file and uninstall file
      CONF_FILE="$UNINST_FILE_BASE_PATH$DRIVER_NAME.conf"
      OLD_CONF_FILE="$UNINST_FILE_BASE_PATH$DRIVER_NAME.old"
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] INFO: Deleting $CONF_FILE." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
      echo "Deleting $CONF_FILE."
      # not really to delete the config file but backup it as old file extension
      rm -f $OLD_CONF_FILE
      mv $CONF_FILE $OLD_CONF_FILE
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] INFO: Deleting $UNINST_FILE." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
      echo "Deleting $UNINST_FILE."
      rm -f $UNINST_FILE
    fi
  done
fi

PRINT_END

if [ $ERROR_EXIT_CODE == "TRUE" ]; then
  exit 1
fi