#!/bin/sh

# Getting /dev/root actual mounted blk device from cmdline.txt
# Cover use case where booting from usb drive
DEVICE_PART_2=$(blkid | grep `cat /proc/cmdline | grep -oE '(root=PARTUUID=.{1,}|root=/dev/.{1,})' | awk '{print $1}' | sed -e 's/root=PARTUUID=//g' -e 's/root=//g'` | awk '{print $1}' | sed 's/://g')
OS_VERSION=$(blkid | grep "$DEVICE_PART_2" | awk '{ print $3 }' | tr -d '\"' | cut -c6-)
PATCH_PATH="/patch/scripts/20230301-01"
LOG_PATH="/patch/logs"
LOG_FILE="$LOG_PATH/20230301-01.log"
MOUNT_POINT_2="/mnt/partition2"

if [ ! -z "$(echo "$OS_VERSION" | grep -oE "\<b28686c2|\<3cd4baaa|\<2457a1f0|\<b5f97c94|\<db6dc0d5")" ]; then
  if [ -e "$DEVICE_PART_2" ]; then
    umount $MOUNT_POINT_2 2> /dev/null
    mkdir -p $MOUNT_POINT_2
    mount $DEVICE_PART_2 $MOUNT_POINT_2

    if [ ! -d "$MOUNT_POINT_2$LOG_PATH" ]; then
      mkdir -p $MOUNT_POINT_2$LOG_PATH
    fi

    SOURCE_COMPOSE="/jabil/patch/docker-compose.yml"
    JPIADMAPI_COMPOSE="/root/jpiadmapi/docker-compose.yml"
    GREP_TEXT_1="`grep '/usr/lib/pi-updater' $MOUNT_POINT_2$JPIADMAPI_COMPOSE`"
    GREP_TEXT_2="`grep 'docker.corp.jabil.org/devservices/jpi-redis:' $MOUNT_POINT_2$JPIADMAPI_COMPOSE`"

    if [ "$GREP_TEXT_1" == "" ] || [ "$GREP_TEXT_2" == "" ]; then
      yes | cp $SOURCE_COMPOSE $MOUNT_POINT_2$JPIADMAPI_COMPOSE

      sed -i -E 's/buster|stretch/latest/g' $MOUNT_POINT_2$JPIADMAPI_COMPOSE
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Patched JPIADMAPI docker-compose.yml." >> $MOUNT_POINT_2$LOG_FILE
    fi

    umount $MOUNT_POINT_2 2> /dev/null
  fi
fi

(
  sleep 240
  LOOP=true

  while [ $LOOP ]; do
    sleep 60

    nc -zv 172.16.0.1 3000 &> /dev/null
    RES="$?"

    if [ $RES -ne 0 ]; then
      LOOP=false
      killall -9 redis-server
    fi
  done
) &

sysctl vm.overcommit_memory=1
redis-server /usr/local/etc/redis/redis.conf --requirepass $1
