#!/bin/bash
#version=2.0.0

# Make /etc/hostname & /etc/hosts have same hostname configuration.
if [ -s /boot/hostname ]; then
  if [ -h /etc/hostname ]; then
    CURR_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
    NEW_HOSTNAME="jpi`cat /proc/cpuinfo | grep Serial | awk '{ print $3 }' | cut -c1,9-`"

    if [ "$CURR_HOSTNAME" = "raspberrypi" ]; then
      echo "$NEW_HOSTNAME" > /boot/hostname
    fi

    if [[ "$CURR_HOSTNAME" =~ jpi[0-9a-f]{9}$ ]] && [ "$CURR_HOSTNAME" != "$NEW_HOSTNAME" ]; then
      echo "$NEW_HOSTNAME" > /boot/hostname
    fi

    FOUND=`cat /etc/hosts | grep $CURR_HOSTNAME`
    if [ "$FOUND" != "" ]; then
      sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
      /bin/chmod 644 /etc/hostname
    fi
    /bin/hostname --file /etc/hostname
  else
    echo "'/boot/hostname' Failed to link /etc/hostname"
  fi
else
  echo "'/boot/hostname'. Detected no such file / The file is empty."
fi

# Load the modules during startup
# and configured by /etc/modules-load.d/modules.conf which also symlink with /boot/modules.
if [ -s /boot/modules ]; then
  if [ -h /etc/modules-load.d/modules.conf ]; then
    sudo /lib/systemd/systemd-modules-load
  else
    echo "'/boot/modules'. Failed to link /etc/modules-load.d/modules.conf"
  fi
else
  echo "'/boot/modules'. Detected no such file / The file is empty."
fi

if [ -f /storage/var/jpiadmapi/restart.db3 ]; then
  /usr/bin/sqlite3 /storage/var/jpiadmapi/restart.db3 \
    "delete from history where created_at <= date('now', '-90 day');" \
    "update history set restart_complete=1,updated_by='Host',updated_at=strftime('%Y-%m-%d %H:%M:%f +00:00', 'NOW')" \
    ".exit"
fi

DEVICE_PART_2=$(findmnt / -o source -n)
DEVICE_PART_2_NAME=$(echo "$DEVICE_PART_2" | cut -d "/" -f 3)
DEVICE_NAME=$(echo /sys/block/*/"${DEVICE_PART_2_NAME}" | cut -d "/" -f 4)
DEVICE_PART_4_NAME=$(ls /sys/block/"${DEVICE_NAME}" | grep ${DEVICE_PART_2_NAME::-1}4$)
DEVICE_PART_4="/dev/${DEVICE_PART_4_NAME}"

PART4="`echo $DEVICE_PART_4 | cut -c6-`"

PART2_ID="`dumpe2fs -h \"$DEVICE_PART_2\" 2>&1 | grep 'Filesystem UUID' | cut -d: -f 2 | tr -d ' '`"

if [ "$PART2_ID" != "" ]; then
  NEW_OS_PREFIX_UUID="db6dc0d5"
  VALID_NEW_OS_PREFIX_UUID=$(echo $PART2_ID | grep ^$NEW_OS_PREFIX_UUID)
  VALID_UUID=""

  if [ "$VALID_NEW_OS_PREFIX_UUID" != "" ]; then
    RELEASE_DATETIME=$(echo $PART2_ID | cut -c25-)
    OFFICIAL_DATETIME="202303020000"

    if [ "$RELEASE_DATETIME" -ge "$OFFICIAL_DATETIME" ]; then
      VALID_UUID="$NEW_OS_PREFIX_UUID"
    fi
  else
    OS_UUIDS="3cd4baaa-5e7b-11ea-abe8-0242ac110002 b28686c2-213e-11ea-b32c-0242ac110002 2457a1f0-5c8f-11eb-8c05-0242ac110002 b5f97c94-af0b-11ec-974d-0242ac110002"
    VALID_UUID=$(echo $OS_UUIDS | grep $PART2_ID)
  fi

  if [ "$VALID_UUID" == "" ]; then
    OS_DURATION_FILE="/root/non_baseline_os"

    if [ ! -f $OS_DURATION_FILE ]; then
      (
        sleep 180s
        NTP_SYNC="`timedatectl | grep 'synchronized:' | grep 'yes'`"

        if [ "$NTP_SYNC" != "" ]; then
          touch $OS_DURATION_FILE
        fi
      ) &
    else
      START_DATE="$(stat -c '%w' $OS_DURATION_FILE | awk '{print $1}')"
      END_DATE="$(date -d "$START_DATE + 89 days" -u +"%Y%m%d")"
      WARNING_DATE=""$(date -d "$START_DATE + 74 days" -u +"%Y%m%d")""
      CURRENT_DATE="$(date -u +"%Y%m%d")"
      WARNING_DATE_LEFT=$(( ($(date -d "$WARNING_DATE UTC" +%s) - $(date -d "$CURRENT_DATE UTC" +%s)) / (60*60*24) ))
      END_DATE_LEFT=$(( ($(date -d "$END_DATE UTC" +%s) - $(date -d "$CURRENT_DATE UTC" +%s)) / (60*60*24) ))

      if [ $CURRENT_DATE -gt $END_DATE ]; then
        chvt 9
        echo "Current Jabil Pi OS $PART2_ID is not the standard baseline. The 30 days OS trial period is over..." > /dev/tty9
        echo "Please install baseline Jabil Pi OS from Pi-Update. If you have any question, please contact Jabil Pi Admin." > /dev/tty9
        echo "OS will shutdown in 90 seconds..." > /dev/tty9
        echo "" > /dev/tty9
        sleep 90
        halt
      else
        if [ $WARNING_DATE_LEFT -lt 1 ]; then
          chvt 9
          echo "WARNING!" > /dev/tty9
          echo "Current Jabil Pi OS $PART2_ID is not the standard baseline. $END_DATE_LEFT day(s) left for this OS trial period..." > /dev/tty9
          echo "Please install baseline Jabil Pi OS from Pi-Update. If you have any question, please contact Jabil Pi Admin." > /dev/tty9
          echo "" > /dev/tty9
          sleep 30
        fi
      fi
    fi
  fi
fi

# Disable wifi power management
WIRELESS_NICS=$(iw dev | grep "Interface" | sed 's/Interface//' | tr -d '[:blank:]')
if [ "$WIRELESS_NICS" != "" ]; then
  OLDIFS="$IFS"
  IFS=$' '
  for WIRELESS_NIC in $WIRELESS_NICS; do
    iw $WIRELESS_NIC set power_save off
  done
  IFS="$OLDIFS"
fi

# Disable auto login
if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
  systemctl --quiet set-default multi-user.target
  rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
fi

# Handle drivers
if [ -f /lib/systemd/system/drivers_install.service ]; then
  # Run dependency modules for arducam if required
  if ! grep -qzw "ak7375.ko.xz" /lib/modules/$(uname -r)/modules.dep; then
    depmod -v
  fi

  # Run drivers.sh script
  systemctl start drivers_install &
fi