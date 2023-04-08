#!/bin/bash
#version=2.0.0

# this script is to perform:
#   1. checking all driver config files in /usr/local/etc/modules.d/.
#   2. checking to each driver status from these config files from the current kernel version.
#   3. performing all these tasks if driver not exists in /lib/modules/.
#     a. extracting modules folder from docker image after docker run it.
#     b. copying module files into /lib/modules respective's kernel version folders.
#     c. installing the driver where current version has 0 driver status from the driver config file.
#
# example: ./drivers_install.sh

# parameter(s)
# none

# set log path
LOG_PATH=$(/scripts/libs/drivers_log_path.lib)

echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] START - /scripts/drivers_install.sh" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log

PRINT_END() {
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] END - /scripts/drivers_install.sh" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  echo "-" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  echo "-" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
  echo "-" >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
}

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

# set reboot flag
PI_REBOOT="FALSE"

# ensure there is at least a driver config file
if [ "$CONF_FILES" != "" ]; then
  # get current running kernel version
  CURRENT_KERNEL_VERSION=$(uname -r)

  # define library modules path
  DRIVER_BASE_PATH="/lib/modules"

  # iterate all driver config files
  for CONF_FILE in $CONF_FILES; do
    # find matched line for kernel version from config file
    CONF_FILE_RESULT=$(cat $CONF_FILE | grep $CURRENT_KERNEL_VERSION)

    # if matched line is not empty
    if [ "$CONF_FILE_RESULT" != "" ]; then
      # get kernel version driver status from matched line
      DRIVER_STATUS=$(echo $CONF_FILE_RESULT | awk '{print $2}')
      # get the config file base path length
      CONF_FILE_BASE_PATH_LENGTH=${#CONF_FILE_BASE_PATH}

      # if driver status is 0
      if [ "$DRIVER_STATUS" == "0" ]; then
        CONF_FILE_LENGTH=${#CONF_FILE}
        # get driver name from the config file path
        DRIVER_NAME=$(echo $CONF_FILE | cut -c$((CONF_FILE_BASE_PATH_LENGTH+1))-$((CONF_FILE_LENGTH-5)))
        # get driver full path
        DRIVER_PATH="$DRIVER_BASE_PATH/$CURRENT_KERNEL_VERSION/extra/$DRIVER_NAME"
        # set status for driver installation
        INSTALL_FLAG="TRUE"

        # if install.sh and uninstall.sh files found from the driver path
        if [ ! -f "$DRIVER_PATH/install.sh" ] || [ ! -f "$DRIVER_PATH/uninstall.sh" ]; then
          # get partition #2
          DEVICE_PART_2=$(findmnt / -o source -n)

          # get os version
          OS_VERSION="`dumpe2fs -h $DEVICE_PART_2 2>&1 | grep 'Filesystem UUID' | cut -d: -f 2 | tr -d ' '`"
          # get image tag
          IMAGE_TAG=$(echo $OS_VERSION | cut -c1-13)
          # set image name
          IMAGE="$DRIVER_NAME:$IMAGE_TAG"

          # extract module folder with its files into temporary /storage/drivers/ directory from docker container
          /scripts/libs/drivers_extract_modules.lib $IMAGE
          RES="$?"

          if [ "$RES" -ne 0 ]; then
            echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: abort extracting module paths." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
            echo "ERROR: abort extracting module paths."
            INSTALL_FLAG="FALSE"
          else
            # copy the module files from /storage/drivers/ to /lib/modules/
            /scripts/libs/drivers_copy_modules.lib $IMAGE
            RES="$?"

            if [ "$RES" -ne 0 ]; then
              echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: abort copying module files." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
              echo "ERROR: abort copying module files."
              INSTALL_FLAG="FALSE"
            else
              # read if repo digest exists in the driver config file
              REPO_DIGEST=$(cat $CONF_FILE | grep sha256)

              if [ "$REPO_DIGEST" == "" ]; then
                # update driver config file in /usr/local/etc/modules.d/
                /scripts/libs/drivers_create_conf_file.lib $IMAGE
                RES="$?"

                if [ "$RES" -ne 0 ]; then
                  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] ERROR: abort updating config." >> $LOG_PATH/drivers_$(date -u +"%Y-%m-%d").log
                  echo "ERROR: abort updating config."
                fi
              fi
            fi
          fi
        fi

        # when installation flag is true
        if [ "$INSTALL_FLAG" = "TRUE" ]; then
          # get current path
          CURRENT_PATH=$(pwd)
          # do driver installation
          /scripts/libs/drivers_install_module.lib $DRIVER_PATH $CONF_FILE $CURRENT_KERNEL_VERSION
          RES=$?
          # go back current path
          cd $CURRENT_PATH
          
          if [ "$RES" -eq 0 ]; then
            # set reboot flag
            PI_REBOOT="TRUE"
          fi
        fi
      fi
    fi
  done

  if [ "$PI_REBOOT" = "TRUE" ]; then
    echo "Finished driver installation, rebooting now..."
    reboot
  fi
fi

PRINT_END