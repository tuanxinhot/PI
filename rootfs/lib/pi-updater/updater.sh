#!/bin/bash
#version=2.0.0
UPDATER_VERSION="v2.0.0"

UPDATE_SERVER="http://pi-update.docker.corp.jabil.org"

if [ -f /root/pi-daily-updater ]; then
  /usr/sbin/rfkill unblock wlan
  for filename in /var/lib/systemd/rfkill/*:wlan ; do
    echo 0 > $filename
  done

  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] For first time, pi-daily-updater service must run first before pi-updater service..."
  exit 0
fi

UPTIME="`awk '{print $1}' /proc/uptime | cut -d. -f1`"
PRETTY_UPTIME=$(awk '{printf("%d:%02d:%02d:%02d\n",($1/60/60/24),($1/60/60%24),($1/60%60),($1%60))}' /proc/uptime)
JPIADMAPI="`curl -s -m 3 http://127.0.0.1:3000/api/v1.0/system/health | grep -oE '\:[[:alpha:]]{4,5}'`"
SSH_STATUS="`systemctl is-active ssh`"
CURL_PILOGIN="`curl -s -m 10 -o /dev/null -I -k -w "%{http_code}" https://pi-login.docker.corp.jabil.org`"
PIUPDATER_LOGPATH="/usr/lib/pi-updater"
PIUPDATER_LOG="$PIUPDATER_LOGPATH/pi-updater.log"
PIUPDATER_TEMP_LOG="$PIUPDATER_LOGPATH/pi-updater.tmp"

touch $PIUPDATER_LOG
if [ ! -f $PIUPDATER_TEMP_LOG ]; then
  tail -n 5040 $PIUPDATER_LOG > $PIUPDATER_TEMP_LOG
fi
mv $PIUPDATER_TEMP_LOG $PIUPDATER_LOG

echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] New Cycle Uptime: $PRETTY_UPTIME" >> $PIUPDATER_LOG

if [ "$UPTIME" -gt 300 ]; then
  if [ -z "$JPIADMAPI" ] || [ "$JPIADMAPI" != ":true" ]; then
    if [ "$SSH_STATUS" != "active" ]; then
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] System Container is down. Enabling SSH service..." >> $PIUPDATER_LOG
      systemctl start ssh &
      DOCKER_STATUS="`systemctl is-active docker`"

      if [ "$DOCKER_STATUS" != "active" ]; then
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Docker service is failed or unavailable, repairing Docker..." >> $PIUPDATER_LOG
        /usr/lib/pi-updater/docker_cleanup.sh docker_down &
      else
        OVERLAY_PROBLEM_1="`journalctl --since="10 minutes ago" -u jpi-admin-api | grep \"readlink /storage/var/lib/docker/overlay2\"`"
        OVERLAY_PROBLEM_2="`journalctl --since="10 minutes ago" -u jpi-admin-api | grep \"failed to register layer: error creating overlay mount to /storage/var/lib/docker/overlay\"`"
        OVERLAY_PROBLEM_3="`journalctl --since="10 minutes ago" -u jpi-admin-api | grep \"Error relocating /usr/bin/node\"`"
        OVERLAY_PROBLEM_4="`journalctl --since="10 minutes ago" -u jpi-admin-api | grep \"Segmentation fault\"`"
        OVERLAY_PROBLEM_5="`journalctl --since="10 minutes ago" -u jpi-admin-api | grep \"standard_init_linux.go\"`"

        if [ "$OVERLAY_PROBLEM_1" != "" ] || [ "$OVERLAY_PROBLEM_2" != "" ] || [ "$OVERLAY_PROBLEM_3" != "" ] || [ "$OVERLAY_PROBLEM_4" != "" ] || [ "$OVERLAY_PROBLEM_5" != "" ]; then
          (
            echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Cleaning the unwanted containers and images..." >> $PIUPDATER_LOG
            systemctl stop jpi-admin-api
            docker container prune --force
            docker image prune --force --all
            systemctl start jpi-admin-api
          ) &
        fi
      fi

      (
        sleep 600s
        JPIADMAPI_SUBTHREAD="`curl -s -m 3 http://127.0.0.1:3000/api/v1.0/system/health | grep -oE '\:[[:alpha:]]{4,5}'`"

        if [ -z "$JPIADMAPI_SUBTHREAD" ] || [ "$JPIADMAPI_SUBTHREAD" != ":true" ]; then
          echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] System Containers failed to up..." >> $PIUPDATER_LOG
        fi
      ) &
    fi
  else
    if [ "$SSH_STATUS" == "active" ] && [ "$CURL_PILOGIN" == "200" ]; then
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Disabling SSH service..." >> $PIUPDATER_LOG
      systemctl stop ssh &
    fi
  fi

  if [ "$CURL_PILOGIN" != "200" ]; then
    if [ "$SSH_STATUS" != "active" ]; then
      CURL_PILOGIN_LOOP=0

      while [ "$CURL_PILOGIN_LOOP" -lt 2 ] && [ "$CURL_PILOGIN" != "200" ]; do
        sleep 10s
        CURL_PILOGIN="`curl -s -m 10 -o /dev/null -I -k -w "%{http_code}" https://pi-login.docker.corp.jabil.org`"
        ((CURL_PILOGIN_LOOP++))
      done

      if [ "$CURL_PILOGIN" != "200" ]; then
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Pi-Login is not reachable. Enabling SSH service..." >> $PIUPDATER_LOG
        systemctl start ssh &
      fi
    fi
  fi
  
  if [ "$CURL_PILOGIN" == "200" ]; then
    if [ ! -z "$JPIADMAPI" ] && [ "$JPIADMAPI" == ":true" ]; then
      SSH_STATUS="`systemctl is-active ssh`"
      if [ "$SSH_STATUS" == "active" ]; then
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Disabling SSH service..." >> $PIUPDATER_LOG
        systemctl stop ssh &
      fi
    fi
  fi
else
  (
    sleep 600s

    CERT_PROBLEM="`journalctl --since="10 minutes ago" -u jpi-admin-api | grep \"x509: certificate has expired or is not yet valid\"`"

    if [ "$CERT_PROBLEM" != "" ]; then
      NTP_SYNC="`timedatectl | grep 'synchronized:' | grep 'yes'`"

      if [ "$NTP_SYNC" == "" ]; then
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Synchronizing the date time with NTP..." >> $PIUPDATER_LOG
        systemctl restart systemd-timesyncd
        systemctl daemon-reload
        systemctl restart systemd-timesyncd
      fi
    fi

    JPIADMAPI_SUBTHREAD="`curl -s -m 3 http://127.0.0.1:3000/api/v1.0/system/health | grep -oE '\:[[:alpha:]]{4,5}'`"

    if [ -z "$JPIADMAPI_SUBTHREAD" ] || [ ! "$JPIADMAPI_SUBTHREAD" = ":true" ]; then
      DOCKER_STATUS_SUBTHREAD="`systemctl is-active docker`"

      if [ "$DOCKER_STATUS_SUBTHREAD" != "active" ]; then
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Docker service is failed or unavailable, repairing Docker..." >> $PIUPDATER_LOG
        /usr/lib/pi-updater/docker_cleanup.sh docker_down
      else
        OVERLAY_PROBLEM_1="`journalctl --since="10 minutes ago" -u jpi-admin-api | grep \"readlink /storage/var/lib/docker/overlay2\"`"
        OVERLAY_PROBLEM_2="`journalctl --since="10 minutes ago" -u jpi-admin-api | grep \"failed to register layer: error creating overlay mount to /storage/var/lib/docker/overlay\"`"
        OVERLAY_PROBLEM_3="`journalctl --since="10 minutes ago" -u jpi-admin-api | grep \"Error relocating /usr/bin/node\"`"
        OVERLAY_PROBLEM_4="`journalctl --since="10 minutes ago" -u jpi-admin-api | grep \"Segmentation fault\"`"
        OVERLAY_PROBLEM_5="`journalctl --since="10 minutes ago" -u jpi-admin-api | grep \"standard_init_linux.go\"`"

        if [ "$OVERLAY_PROBLEM_1" != "" ] || [ "$OVERLAY_PROBLEM_2" != "" ] || [ "$OVERLAY_PROBLEM_3" != "" ] || [ "$OVERLAY_PROBLEM_4" != "" ] || [ "$OVERLAY_PROBLEM_5" != "" ]; then
          echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Cleaning the unwanted containers and images..." >> $PIUPDATER_LOG
          systemctl stop jpi-admin-api
          docker container prune --force
          docker image prune --force --all
          systemctl start jpi-admin-api
        fi
      fi

      sleep 180s

      JPIADMAPI_SUBTHREAD="`curl -s -m 3 http://127.0.0.1:3000/api/v1.0/system/health | grep -oE '\:[[:alpha:]]{4,5}'`"

      if [ -z "$JPIADMAPI_SUBTHREAD" ] || [ "$JPIADMAPI_SUBTHREAD" != ":true" ]; then
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] System Containers failed to up, enabling SSH service..." >> $PIUPDATER_LOG
        systemctl start ssh
      fi
    fi

    if [ "$SSH_STATUS" != "active" ] && [ "$CURL_PILOGIN" != "200" ]; then
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Pi-Login is not reachable. Enabling SSH service..." >> $PIUPDATER_LOG
      systemctl start ssh
    fi
  ) &

  if [ -d /root.upgrade ]; then
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Moving /root.upgrade back to /root..." >> $PIUPDATER_LOG
    unlink /root
    mv /root.upgrade /root
    systemctl restart jpi-admin-api &
  fi
fi

if [ -z "$JPIADMAPI" ] || [ "$JPIADMAPI" != ":true" ]; then
  JPIADMAPI=0
else
  JPIADMAPI=2
fi

if [ -f /boot/compose-running.yml ]; then
  COMPOSE_UP="`docker-compose -f /boot/compose-running.yml ps | grep -oE '(Up|running)' | wc -l`"
  if [ $COMPOSE_UP -eq 0 ]; then
    BOOTAPP=0
  else
    BOOTAPP=1
  fi
else
  BOOTAPP=-1
fi

(
  REMOTE_CERT="`curl -f -s "${UPDATE_SERVER}/jabil/certs/Jabil_Full.crt" | md5sum  | awk '{ print $1 }'`"

  if [ -f /usr/share/ca-certificates/jabil/Jabil_Full.crt ]; then
    LOCAL_CERT="`md5sum /usr/share/ca-certificates/jabil/Jabil_Full.crt | awk '{ print $1 }'`"
  fi

  if [ "$REMOTE_CERT" != "$LOCAL_CERT" ]; then
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] New full certs found, updating..." >> $PIUPDATER_LOG
    curl -f -s "${UPDATE_SERVER}/jabil/certs/Jabil_Full.crt" -o /usr/share/ca-certificates/jabil/Jabil_Full.crt
  fi
) &

DEVICE_PART_2=$(findmnt / -o source -n)
DEVICE_PART_2_NAME=$(echo "$DEVICE_PART_2" | cut -d "/" -f 3)
DEVICE_NAME=$(echo /sys/block/*/"${DEVICE_PART_2_NAME}" | cut -d "/" -f 4)
DEVICE_PART_3_NAME=$(ls /sys/block/"${DEVICE_NAME}" | grep ${DEVICE_PART_2_NAME::-1}3$)
DEVICE_PART_3="/dev/${DEVICE_PART_3_NAME}"

A_DEVICE=`echo $DEVICE_PART_2 | cut -c6-`
B_DEVICE=`echo $DEVICE_PART_3 | cut -c6-`

if [ -a "/boot/updater/server.txt" ]; then
  UPDATE_SERVER="`cat /boot/updater/server.txt | egrep -v '^#'`"
fi

SERIAL="`cat /proc/cpuinfo |grep ^Serial |cut -d: -f 2 |tr -d ' '`"
DISTRIBUTION="`cat /boot/updater/distrib.txt|egrep -v -e '^#' -e '^( *)$'`"
BRANCH="`cat /boot/updater/risk.txt|egrep -v -e '^#' -e '^( *)$'`"
UPTIME="`awk '{print $1}' /proc/uptime`"

PTABLE_A_START_SECTOR="`parted -m \"/dev/$DEVICE_NAME\" unit s print |egrep '^2:' |cut -d: -f 2 |tr -d 's'`"
PTABLE_B_START_SECTOR="`parted -m \"/dev/$DEVICE_NAME\" unit s print |egrep '^3:' |cut -d: -f 2 |tr -d 's'`"

KERNEL_A_START_SECTOR="`cat /sys/block/$DEVICE_NAME/$A_DEVICE/start`"
if [ -f /sys/block/$DEVICE_NAME/$B_DEVICE/start ]; then
  KERNEL_B_START_SECTOR="`cat /sys/block/$DEVICE_NAME/$B_DEVICE/start`"
fi

IPADDR="`ip route | grep default | awk 'NR==1 { print $(NF-2) }'`"
WL_SSID=""
TEMP="`cat /sys/class/thermal/thermal_zone*/temp`"

if [ ! -z "$IPADDR" ]; then
  INTERFACE="`netstat -ie | grep -B1 $IPADDR | awk NR==1'{ print $1 }' | tr -d ':'`"
  if [[ "$INTERFACE" == "wlan"* ]]; then
    WL_SSID="`iwgetid -r`"
    WL_SIGNAL="`cat /proc/net/wireless | awk 'END { print $3 }' | sed 's/\.$//'`"
    WL_BAND="`iwconfig $INTERFACE | awk 'NR==2 { print $2 $3 }' | cut -c11-`"
  fi
fi

CURRENT_MANIFEST_VER="`dumpe2fs -h \"/dev/$A_DEVICE\" 2>&1 |grep 'Filesystem UUID' |cut -d: -f 2 |tr -d ' '`"
if [ -z "$CURRENT_MANIFEST_VER" ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Unable to read current manifest version from device /dev/${A_DEVICE}.  Please check permissions and configuration."
  exit 3
fi

APP_EXIT_COUNT="`docker events --since '30m' --until '0s' --filter 'event=die' | grep -Ev 'name=jpiadmapi_nodejs|name=jpiadmapi_redis' | wc -l`"
IS_RUNNING_SWAPPED=0

if [ "$PTABLE_A_START_SECTOR" -ne "$KERNEL_A_START_SECTOR" ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] System updated, but not yet rebooted."
  IS_RUNNING_SWAPPED=1
  curl -f -s "${UPDATE_SERVER}/api/v1.0/rebootwaiting?serial=${SERIAL}&running=${CURRENT_MANIFEST_VER}&uptime=${UPTIME}&aec=${APP_EXIT_COUNT}&ver=${UPDATER_VERSION}&sc=${JPIADMAPI}&app=${BOOTAPP}&ssid=${WL_SSID}&signal=${WL_SIGNAL}&band=${WL_BAND}&temp=${TEMP}"
  #TODO, figure out a way to cleanly check if the waiting partition is already on the newest manifest, and if not - update it again.
  exit 0
fi

if [ ! -b "/dev/$B_DEVICE" ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] OS B device does not exist [/dev/$B_DEVICE], Fatal error."
  curl -f -s "${UPDATE_SERVER}/api/v1.0/faultcollector?fault=missing_b_device&serial=${SERIAL}&running=${CURRENT_MANIFEST_VER}&uptime=${UPTIME}&aec=${APP_EXIT_COUNT}&ver=${UPDATER_VERSION}&sc=${JPIADMAPI}&app=${BOOTAPP}&ssid=${WL_SSID}&signal=${WL_SIGNAL}&band=${WL_BAND}&temp=${TEMP}"
  exit 3
fi

if [ -z "$BRANCH" ]; then
  BRANCH="high"
else
  CONF_FILE_BASE_PATH="/usr/local/etc/modules.d/"
 
  if [ -d "$CONF_FILE_BASE_PATH" ]; then
    CONF_FILES=$(find $CONF_FILE_BASE_PATH -type f -name "*.conf")

    if [ "$CONF_FILES" != "" ]; then
      BRANCH="high"
      echo -e "#Update to reflect the risk level should this system become unavailable.  Lines that start with # are ignored.\n#Must be one of test, low, medium, high. Each is an increasing level of risk\n#Default is high, and should an invalid value be used, high is assumed.\nhigh" > /boot/updater/risk.txt
    fi
  fi
fi

if [ -z "$DISTRIBUTION" ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Missing Distribution, notifying update server...  Please update /boot/updater/distrib.txt with the correct distribution"
  curl -f -s "${UPDATE_SERVER}/api/v1.0/faultcollector?fault=missing_distribution&serial=${SERIAL}&running=${CURRENT_MANIFEST_VER}&uptime=${UPTIME}&aec=${APP_EXIT_COUNT}&ver=${UPDATER_VERSION}&sc=${JPIADMAPI}&app=${BOOTAPP}&ssid=${WL_SSID}&signal=${WL_SIGNAL}&band=${WL_BAND}&temp=${TEMP}"
  exit 1
fi

#TODO - Check if the partitions have already been swapped, but we have not yet rebooted.  If so, put them back...
mkdir -p /boot/updater/

echo -n "[$(date -u +"%Y-%m-%d %H:%M:%S")] Getting latest manifest information for ${DISTRIBUTION} ${BRANCH}..."
MANIFEST_FILE="`curl -f -s \"${UPDATE_SERVER}/api/v1.0/dists/${DISTRIBUTION}/${BRANCH}.latest?serial=${SERIAL}&running=${CURRENT_MANIFEST_VER}&uptime=${UPTIME}&aec=${APP_EXIT_COUNT}&ver=${UPDATER_VERSION}&sc=${JPIADMAPI}&app=${BOOTAPP}&ssid=${WL_SSID}&signal=${WL_SIGNAL}&band=${WL_BAND}&temp=${TEMP}\"`"
if [ -z "$MANIFEST_FILE" ]; then
  echo "Server is missing manifest definition for this distribution and branch.  Exiting."
  exit 2
fi

MANIFEST_VER="`echo \"$MANIFEST_FILE\"|cut -d. -f 1`"
if [ "$MANIFEST_VER" == "$CURRENT_MANIFEST_VER" ]; then
  echo "Already at version $MANIFEST_VER"
  exit 0
fi

if [ -f /root/$MANIFEST_VER/complete ]; then
  curl -f -s "${UPDATE_SERVER}/api/v1.0/swapwaiting?serial=${SERIAL}&running=${CURRENT_MANIFEST_VER}&uptime=${UPTIME}&aec=${APP_EXIT_COUNT}&ver=${UPDATER_VERSION}&sc=${JPIADMAPI}&app=${BOOTAPP}&ssid=${WL_SSID}&signal=${WL_SIGNAL}&band=${WL_BAND}&temp=${TEMP}"
  echo " Already downloaded version $MANIFEST_VER, pending for manual partition swapping."
  /usr/bin/sqlite3 /storage/var/jpiadmapi/restart.db3 "update history set restart_complete = 0 where reason='Newer OS downloaded. Pending for swapping and rebooting...'"
  exit 0
fi

echo "Updating to $MANIFEST_VER"

#Do we already have that manifest downloaded?
if [ -a "/boot/updater/b_target.version" ]; then
  TARGET_MANIFEST_VER="`cat /boot/updater/b_target.version`"
fi

if [ "$MANIFEST_VER" != "$TARGET_MANIFEST_VER" ]; then
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Downloading new target manifest ${MANIFEST_VER} "
  curl -f -s "${UPDATE_SERVER}/api/v1.0/manifests/${MANIFEST_FILE}" >/boot/updater/b_target.manifest
  echo "$MANIFEST_VER" >/boot/updater/b_target.version
fi

/usr/lib/pi-updater/rebuild_image.sh /boot/updater/b_target.manifest "/dev/${B_DEVICE}" "$UPDATE_SERVER"
RES="$?"
if [ "$RES" -ne 0 ]; then
  if [ $RES -eq 10 ]; then
    #10 has a special meaning, something is wrong with the manifest.  Remove it so we're forced to re-download
    rm -f /boot/updater/b_target.manifest /boot/updater/b_target.version
  fi
  exit $RES
else
  mkdir -p /root/$MANIFEST_VER
  date > /root/$MANIFEST_VER/complete

  if [[ ! "$BRANCH" =~ ^high ]]; then
    /usr/lib/pi-updater/swap_partitions.sh
    RES="$?"
    if [ "$RES" -eq 0 ]; then
      /usr/bin/sqlite3 /storage/var/jpiadmapi/restart.db3 \
        "insert into history ('scope','updated_by','reason','restart_complete','created_at','updated_at') \
        values ('Host','Host','Newer OS downloaded and swapped. Pending for reboot...',0,strftime('%Y-%m-%d %H:%M:%f +00:00', 'NOW'),strftime('%Y-%m-%d %H:%M:%f +00:00', 'NOW'));"
      curl -f -s "${UPDATE_SERVER}/api/v1.0/rebootwaiting?serial=${SERIAL}"
    fi

    if [ "$RES" -eq 1 ]; then
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] /storage space not enough. Please clean up some spaces."
      curl -f -s "${UPDATE_SERVER}/api/v1.0/faultcollector?fault=part4_nospace&serial=${SERIAL}"
    fi

    if [ "$RES" -eq 2 ]; then
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] New OS driver installation failure."
      curl -f -s "${UPDATE_SERVER}/api/v1.0/faultcollector?fault=new_driveros_failure&serial=${SERIAL}"
    fi

    if [ "$RES" -eq 3 ]; then
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Current OS cannot upgrade to 64 bits OS."
      curl -f -s "${UPDATE_SERVER}/api/v1.0/faultcollector?fault=3cd_os_upgrade_64&serial=${SERIAL}"
    fi

    if [ "$RES" -eq 10 ]; then
      echo "Finished swapping partitions, ready to reboot in 30 seconds..."
      sleep 30s
      /sbin/reboot
    fi
  else
    /usr/bin/sqlite3 /storage/var/jpiadmapi/restart.db3 \
      "insert into history ('scope','updated_by','reason','restart_complete','created_at','updated_at') \
      values ('Host','Host','Newer OS downloaded. Pending for swap and reboot...',0,strftime('%Y-%m-%d %H:%M:%f +00:00', 'NOW'),strftime('%Y-%m-%d %H:%M:%f +00:00', 'NOW'));"
    curl -f -s "${UPDATE_SERVER}/api/v1.0/swapwaiting?serial=${SERIAL}"
  fi
fi

if [ "$BRANCH" == "low" ]; then
  echo "Finished swapping partitions, ready to reboot in 30 seconds..."
  sleep 30s
  /sbin/reboot
fi