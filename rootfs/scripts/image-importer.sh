#!/bin/bash
#version=2.0.0

DEVICE_PART_2=$(findmnt / -o source -n)
DEVICE_PART_2_NAME=$(echo "$DEVICE_PART_2" | cut -d "/" -f 3)
DEVICE_NAME=$(echo /sys/block/*/"${DEVICE_PART_2_NAME}" | cut -d "/" -f 4)
DEVICE_PART_4_NAME=$(ls /sys/block/"${DEVICE_NAME}" | grep ${DEVICE_PART_2_NAME::-1}4$)
DEVICE_PART_4="/dev/${DEVICE_PART_4_NAME}"

TAR_DIR="/storage/var/loadtars/"
LOG_FILE="loadtars.log"
TEMP_FILE="loadtars.temp"

if [ -e "$DEVICE_PART_4" ] && [ -d "$TAR_DIR" ]; then
  TAR_FILES="$(ls "$TAR_DIR" | grep -E "*.tar.gz")"

  if [ "$?" -eq 0 ]; then
    if [ ! -f $TAR_DIR$LOG_FILE ]; then
      touch $TAR_DIR$LOG_FILE
    fi

    if [ ! -f $TAR_DIR$TEMP_FILE ]; then
      tail -n 5040 $TAR_DIR$LOG_FILE > $TAR_DIR$TEMP_FILE
    fi

    mv $TAR_DIR$TEMP_FILE $TAR_DIR$LOG_FILE

    # import tar images
    while IFS='' read -r LINE; do
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] docker load - $TAR_DIR$LINE" >> $TAR_DIR$LOG_FILE
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Loading image - $LINE" > /dev/tty7
      docker load -q -i $TAR_DIR$LINE > /dev/tty7
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] deleted - $TAR_DIR$LINE" >> $TAR_DIR$LOG_FILE
      rm -f $TAR_DIR$LINE
    done <<< $TAR_FILES
  fi
fi
