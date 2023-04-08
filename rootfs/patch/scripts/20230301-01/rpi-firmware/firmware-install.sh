#!/bin/bash

LOGPATH="/var/log/rpi-update.log"
PIDDIRPATH="/storage/rpi-firmware"
PIDPATH="$PIDDIRPATH/firmware-install-status.json"
PREVREVPATH="/boot/.previous_firmware_revision"
CURRREVPATH="/boot/.firmware_revision"

mkdir -p $PIDDIRPATH
STARTTIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo '{"revision_id":"'$1'","start_time":"'$STARTTIME'","end_time":"","exit_code":-1}' > $PIDPATH

if [ -f $CURRREVPATH ]; then
  PREVREV="$(cat $CURRREVPATH)"
fi

CURRENT_KERNEL=`uname -r | cut -d'-' -f1`
DATETIME=`date +"%Y%m%d_%H%M%S"`

echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Upgrading Raspberry Pi's firmware and kernel..." | tee -a $LOGPATH

mkdir -p /storage/rpi-firmware/root
chmod 0700 /storage/rpi-firmware
chown root:root /storage/rpi-firmware
mv /root /root.upgrade
ln -s /storage/rpi-firmware/root /root
SKIP_BACKUP=1 SKIP_WARNING=1 rpi-update $1
EXITCODE=$?
unlink /root
mv /root.upgrade /root

rm -rf /boot.bak 2&> /dev/null
rm -rf /lib/modules.bak 2&> /dev/null

NEW_KERNEL=`ls /lib/modules | grep -v $CURRENT_KERNEL`

if [ "${#NEW_KERNEL}" == "0" ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] No changes made." | tee -a $LOGPATH
else
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] New kernels: $NEW_KERNEL..." | tee -a $LOGPATH
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] New firmware and kernel found. Removing older set." | tee -a $LOGPATH

  rm -rf /lib/modules/$CURRENT_KERNEL*

  # Record down previous firmware revision
  if [ ! -z $PREVREV ] && [ ! "$1" = "$PREVREV" ] && [ $EXITCODE -eq 0 ]; then
    echo $PREVREV > $PREVREVPATH
  fi
fi

sync

ENDTIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo '{"revision_id":"'$1'","start_time":"'$STARTTIME'","end_time":"'$ENDTIME'","exit_code":'$EXITCODE'}' > $PIDPATH

if [ ! $EXITCODE -eq 0 ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Firmware upgrade failed. ExitCode=$EXITCODE." | tee -a $LOGPATH
  exit $EXITCODE
else
  # Submit a restart request if firmware install success.
  curl -X POST \
    -H 'x-scope-id: host' \
    -H 'content-type: application/json' \
    --data '{"reason":"Firmware '$1' installed, require to restart Pi to apply firmware changes."}' \
    'http://127.0.0.1:3000/api/v1.0/system/request-restart'
fi
