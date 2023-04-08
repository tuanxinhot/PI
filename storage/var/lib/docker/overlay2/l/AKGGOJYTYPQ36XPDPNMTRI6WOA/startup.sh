#!/bin/sh

# Getting /dev/root actual mounted blk device from cmdline.txt
# Cover use case where booting from usb drive
DEVICE_PART_2=$(blkid | grep `cat /proc/cmdline | grep -oE '(root=PARTUUID=.{1,}|root=/dev/.{1,})' | awk '{print $1}' | sed -e 's/root=PARTUUID=//g' -e 's/root=//g'` | awk '{print $1}' | sed 's/://g')
OS_VERSION=$(blkid | grep "$DEVICE_PART_2" | awk '{ print $3 }' | tr -d '\"' | cut -c6-)
PATCH_PATH="/host/patch/scripts/20230301-01"
LOG_PATH="/host/patch/logs"
LOG_FILE="$LOG_PATH/20230301-01.log"
STORAGE_PATH="/host/storage"
DB_DIR_PATH="$STORAGE_PATH/var/jpiadmapi"

if [ ! -d "$PATCH_PATH" ]; then
  SOURCE_PATH="/jabil/patch"

  mkdir -p $PATCH_PATH
  cp -r $SOURCE_PATH/* $PATCH_PATH/
  chmod -R 700 $PATCH_PATH
fi

if [ ! -d "$LOG_PATH" ]; then
  mkdir -p $LOG_PATH
fi

# Create system container db directory path if not exists
if [ ! -d $DB_DIR_PATH ]; then
  mkdir -p $DB_DIR_PATH
fi

executeSysconAutoRestart() {
  dbus-send --system --print-reply --dest=org.freedesktop.systemd1 /org/freedesktop/systemd1 \
    org.freedesktop.systemd1.Manager.StartUnit string:jpi-admin-api-autorestart.service string:replace
}

executeSystemctlDaemonReload() {
  dbus-send --system --print-reply --dest=org.freedesktop.systemd1 \
    /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager.Reload
}

removeSqlite3InstallStateFile() {
  if [ -f $DB_DIR_PATH/sqlite3-install-success ]; then
    rm -f $DB_DIR_PATH/sqlite3-install-success
  fi
}
# Remove existing sqlite3 install success state file
removeSqlite3InstallStateFile

if [ ! -z "$(echo "$OS_VERSION" | grep -oE "\<b28686c2|\<3cd4baaa|\<2457a1f0|\<b5f97c94|\<db6dc0d5")" ]; then
  SOURCE_COMPOSE="/jabil/patch/docker-compose.yml"
  JPIADMAPI_COMPOSE="/host/root/jpiadmapi/docker-compose.yml"
  GREP_TEXT_1="`grep '/usr/lib/pi-updater' $JPIADMAPI_COMPOSE`"
  GREP_TEXT_2="`grep 'docker.corp.jabil.org/devservices/jpi-redis:' $JPIADMAPI_COMPOSE`"
  GREP_TEXT_3="`grep '/root:/host/root:z' $JPIADMAPI_COMPOSE`"
  GREP_TEXT_4="`grep '/sys/fs/cgroup:/host/sys/fs/cgroup:ro' $JPIADMAPI_COMPOSE`"
  GREP_TEXT_5="`grep '/lib/firmware/raspberrypi/bootloader:/host/lib/firmware/raspberrypi/bootloader:ro' $JPIADMAPI_COMPOSE`"
  GREP_TEXT_6="`grep '/usr/local/etc:/host/usr/local/etc:z' $JPIADMAPI_COMPOSE`"
  SYSCON_AUTORESTART=0

  if [ "$GREP_TEXT_1" == "" ] || [ "$GREP_TEXT_2" == "" ] || [ "$GREP_TEXT_3" == "" ] || \
     [ "$GREP_TEXT_4" == "" ] || [ "$GREP_TEXT_5" == "" ] || [ "$GREP_TEXT_6" == "" ]; then
    SYSCON_AUTORESTART=1
    yes | cp $SOURCE_COMPOSE $JPIADMAPI_COMPOSE

    sed -i -E 's/buster|stretch/latest/g' $JPIADMAPI_COMPOSE
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Patched JPIADMAPI docker-compose.yml." >> $LOG_FILE
  fi

  MOUNT_POINT_2="/mnt/partition2"

  if [ -e "$DEVICE_PART_2" ]; then
    SRC_FILE_1="/jabil/patch/pi-updater/updater.sh"
    SRC_FILE_2="/jabil/patch/pi-updater/daily_updater.sh"
    SRC_FILE_3="/jabil/patch/pi-updater/pios_swap.sh"
    SRC_FILE_4="/jabil/patch/pi-updater/pios-swap.service"
    SRC_FILE_5="/jabil/patch/rss/docker-compose.yml"
    SRC_FILE_6="/jabil/patch/rss/rss.service"
    SRC_FILE_7="/jabil/patch/rss/shadow"
    SRC_FILE_8="/jabil/patch/rpi-firmware/rpi-firmware-install@.service"
    SRC_FILE_9="/jabil/patch/rpi-firmware/firmware-install.sh"
    SRC_FILE_10="/jabil/patch/scripts/compose-pull.sh"
    SRC_FILE_11="/jabil/patch/scripts/sysconf.sh"
    SRC_FILE_12="/jabil/patch/syscon/jpi-admin-api-pull.sh"
    SRC_FILE_13="/jabil/patch/syscon/jpi-admin-api-imageupdater.service"
    SRC_FILE_14="/jabil/patch/syscon/sqlite-cli-install.sh"
    SRC_FILE_15="/jabil/patch/syscon/sqlite-cli-install.service"
    SRC_FILE_16="/jabil/patch/rss/rss-startup.sh"
    SRC_FILE_17="/jabil/patch/syscon/jpi-admin-api-autorestart.service"
    SRC_FILE_18="/jabil/patch/syscon/syscon-autorestart.sh"
    SRC_FILE_19="/jabil/patch/syscon/docker-compose.service"
    SRC_FILE_20="/jabil/patch/syscon/jpi-admin-api-host.service"
    SRC_FILE_21="/jabil/patch/syscon/jpi-admin-api.service"
    SRC_FILE_22="/jabil/patch/pi-updater/docker_cleanup.sh"
    SRC_FILE_23="/jabil/patch/scripts/sysinfo.sh"
    SRC_FILE_24="/jabil/patch/scripts/restart_info.sh"
    SRC_FILE_25="/jabil/patch/scripts/compose.sh"
    SRC_FILE_26="/jabil/patch/pi-updater/rebuild_image.sh"
    SRC_FILE_27="/jabil/patch/rpi-eeprom/rpi-eeprom@.service"
    SRC_FILE_28="/jabil/patch/rpi-eeprom/update-boot-order.sh"
    SRC_FILE_29="/jabil/patch/scripts/ntp-updater.sh"
    SRC_FILE_30="/jabil/patch/scripts/sysinfo_m.sh"
    SRC_FILE_31="/jabil/patch/pi-updater/rollback.sh"
    SRC_FILE_32="/jabil/patch/pi-updater/swap_partitions.sh"
    DEST_PATH_1="/usr/lib/pi-updater"
    DEST_PATH_2="/lib/systemd/system"
    DEST_PATH_3="/root/rss"
    DEST_PATH_4="/root/jpiadmapi"
    DEST_PATH_5="/scripts"
    SELECTED_FILE="$DEST_PATH_1/updater.sh"
    PIOS_SWAP_FILE="pios_swap.sh"
    COMPOSE_FILENAME="docker-compose.yml"
    JPISERV_FILENAME="rss.service"
    SHADOW_FILENAME="shadow"
    COMPOSE_SH_FILENAME="compose.sh"
    COMPOSE_PULL_FILENAME="compose-pull.sh"
    SYSCONF_FILENAME="sysconf.sh"
    SYSCON_PULL_FILENAME="jpi-admin-api-pull.sh"
    SYSCON_SERVICE_FILENAME="jpi-admin-api-imageupdater.service"
    SYSCON_HOST_SERV_FILENAME="jpi-admin-api-host.service"
    SYSCON_SERV_FILENAME="jpi-admin-api.service"
    SQLITE_INSTALL_FILENAME="sqlite-cli-install.sh"
    SQLITE_SERVICE_FILENAME="sqlite-cli-install.service"
    FIRMWARE_SERVICE_FILENAME="rpi-firmware-install@.service"
    FIRMWARE_SCRIPT_FILENAME="firmware-install.sh"
    RSS_STARTUP_FILENAME="rss-startup.sh"
    SYSCON_AUTORESTART_SERV_FILENAME="jpi-admin-api-autorestart.service"
    SYSCON_AUTORESTART_SCRIPT_FILENAME="syscon-autorestart.sh"
    DOCKER_COMPOSE_SERV_FILENAME="docker-compose.service"
    DOCK_CLEANUP_SCRIPT_FILENAME="docker_cleanup.sh"
    SYSINFO_SCRIPT_FILENAME="sysinfo.sh"
    RESTARTINFO_SCRIPT_FILENAME="restart_info.sh"
    REBUILD_IMAGE_FILENAME="rebuild_image.sh"
    RPIEEPROM_SERVICE_FILENAME="rpi-eeprom@.service"
    RPIEEPROM_SCRIPT_FILENAME="update-boot-order.sh"
    NTP_UPDATER_FILENAME="ntp-updater.sh"
    SYSINFO_M_SH_FILENAME="sysinfo_m.sh"
    ROLLBACK_SH_FILENAME="rollback.sh"
    SWAP_PART_SH_FILENAME="swap_partitions.sh"
    UPDATER_SH_FILENAME="updater.sh"
    DAILY_UPDATER_SH_FILENAME="daily_updater.sh"
    PIOS_SWAP_SERVICE_FILENAME="pios-swap.service"

    umount $MOUNT_POINT_2 2> /dev/null
    mkdir -p $MOUNT_POINT_2
    mount $DEVICE_PART_2 $MOUNT_POINT_2

    EXITCODE30=1
    UPDATER_SH_VER="1.9.0"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_1" \
      "$MOUNT_POINT_2$DEST_PATH_1/$UPDATER_SH_FILENAME" \
      "$UPDATER_SH_VER" "2" "700"
    EXITCODE30=$?

    if [ $EXITCODE30 -eq 0 ]; then
      GROUP_CONF="/host/boot/jpiadmapi/group.conf"
      touch $GROUP_CONF

      EXITCODE31=1
      DAILY_UPDATER_SH_VER="1.9.0"
      cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_2" \
        "$MOUNT_POINT_2$DEST_PATH_1/$DAILY_UPDATER_SH_FILENAME" \
        "$DAILY_UPDATER_SH_VER" "2" "700"
      EXITCODE31=$?

      chmod 700 $MOUNT_POINT_2$DEST_PATH_1/*.sh
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Changed pi-updater path attribute." >> $LOG_FILE

      EXITCODE29=1
      PIOS_SWAP_SH_VER="1.2.0"
      cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_3" \
        "$MOUNT_POINT_2$DEST_PATH_1/$PIOS_SWAP_FILE" \
        "$PIOS_SWAP_SH_VER" "2" "700"
      EXITCODE29=$?

      EXITCODE32=1
      PIOS_SWAP_SERV_VER="1.2.0"
      cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_4" \
        "$MOUNT_POINT_2$DEST_PATH_2/$PIOS_SWAP_SERVICE_FILENAME" \
        "$PIOS_SWAP_SERV_VER" "1" "644"
      EXITCODE32=$?

      if [ $EXITCODE29 -eq 0 ] || [ $EXITCODE32 -eq 0 ]; then
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Patched pios-swap script and service." >> $LOG_FILE
        executeSystemctlDaemonReload
      fi

      chmod -R 700 $MOUNT_POINT_2$DEST_PATH_1
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Changed pi-updater path attribute." >> $LOG_FILE
      chmod -R 700 $MOUNT_POINT_2$DEST_PATH_5
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Changed scripts path attribute." >> $LOG_FILE
    fi

    EXITCODE18=1
    DOCK_CLEANUP_VER="1.1.0"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_22" \
      "$MOUNT_POINT_2$DEST_PATH_1/$DOCK_CLEANUP_SCRIPT_FILENAME" \
      "$DOCK_CLEANUP_VER" "2" "700"
    EXITCODE18=$?

    EXITCODE19=1
    SYSINFO_VER="1.2.0"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_23" \
      "$MOUNT_POINT_2$DEST_PATH_5/$SYSINFO_SCRIPT_FILENAME" \
      "$SYSINFO_VER" "2" "700"
    EXITCODE19=$?

    if [ $EXITCODE19 -eq 0 ]; then
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] $SYSINFO_SCRIPT_FILENAME patched." >> $LOG_FILE
      executeSystemctlDaemonReload
      # Restart sysinfo.service
      dbus-send --system --print-reply --dest=org.freedesktop.systemd1 /org/freedesktop/systemd1 \
        org.freedesktop.systemd1.Manager.RestartUnit string:sysinfo.service string:replace
    fi

    EXITCODE20=1
    RESTARTINFO_VER="1.0.0"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_24" \
      "$MOUNT_POINT_2$DEST_PATH_5/$RESTARTINFO_SCRIPT_FILENAME" \
      "$RESTARTINFO_VER" "2" "700"
    EXITCODE20=$?

    EXITCODE21=1
    COMPOSE_SH_VER="1.0.0"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_25" \
      "$MOUNT_POINT_2$DEST_PATH_5/$COMPOSE_SH_FILENAME" \
      "$COMPOSE_SH_VER" "2" "700"
    EXITCODE21=$?

    EXITCODE22=1
    REBUILD_IMAGE_VER="1.1.0"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_26" \
      "$MOUNT_POINT_2$DEST_PATH_1/$REBUILD_IMAGE_FILENAME" \
      "$REBUILD_IMAGE_VER" "2" "700"
    EXITCODE22=$?

    # Check if system container already mapped to /root directory
    if [ ! "$GREP_TEXT_3" == "" ]; then
      EXITCODE3=1
      # Create rss directory if not exists on host
      if [ ! -d $MOUNT_POINT_2$DEST_PATH_3 ]; then 
        mkdir -p $MOUNT_POINT_2$DEST_PATH_3; 
      fi
      # Copy rss docker-compose.yml file to host if not exists
      if [ ! -f $MOUNT_POINT_2$DEST_PATH_3/$COMPOSE_FILENAME ]; then 
        yes | cp $SRC_FILE_5 $MOUNT_POINT_2$DEST_PATH_3/$COMPOSE_FILENAME
        EXITCODE3=$?
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Copied RSS docker-compose file." >> $LOG_FILE
      fi

      EXITCODE4=1
      # Copy shadow file to host if not exists
      if [ ! -f $MOUNT_POINT_2$DEST_PATH_3/$SHADOW_FILENAME ]; then
        yes | cp $SRC_FILE_7 $MOUNT_POINT_2$DEST_PATH_3/$SHADOW_FILENAME
        EXITCODE4=$?
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Copied RSS shadow file." >> $LOG_FILE
      fi

      EXITCODE5=1
      RSS_SERV_VER="1.0.0"
      cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_6" \
        "$MOUNT_POINT_2$DEST_PATH_2/$JPISERV_FILENAME" \
        "$RSS_SERV_VER" "1" "644"
      EXITCODE5=$?

      EXITCODE12=1
      RSS_STARTUP_VER="1.0.0"
      cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_16" \
        "$MOUNT_POINT_2$DEST_PATH_3/$RSS_STARTUP_FILENAME" \
        "$RSS_STARTUP_VER" "2" "700"
      EXITCODE12=$?

      if [ $EXITCODE3 -eq 0 ] || [ $EXITCODE4 -eq 0 ] || [ $EXITCODE5 -eq 0 ] || [ $EXITCODE12 -eq 0 ]; then
        # Set request restart
        node /jpiadmapi/request.restart.js "Admin" "RSS service updated and Pi require restart."
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] RSS service updated and Pi require restart." >> $LOG_FILE
        executeSystemctlDaemonReload
      fi
    fi

    # Copy firmware upgrade service file if not exists
    if [ ! -f $MOUNT_POINT_2$DEST_PATH_2/$FIRMWARE_SERVICE_FILENAME ]; then
      yes | cp $SRC_FILE_8 $MOUNT_POINT_2$DEST_PATH_2/$FIRMWARE_SERVICE_FILENAME
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Copied firmware install service file." >> $LOG_FILE
    fi

    # Copy firmware upgrade scripte file if not exists
    if [ ! -f $MOUNT_POINT_2$DEST_PATH_4/$FIRMWARE_SCRIPT_FILENAME ]; then
      yes | cp $SRC_FILE_9 $MOUNT_POINT_2$DEST_PATH_4/$FIRMWARE_SCRIPT_FILENAME
      chmod 700 $MOUNT_POINT_2$DEST_PATH_4/$FIRMWARE_SCRIPT_FILENAME
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Copied firmware install script file." >> $LOG_FILE
    fi

    EXITCODE6=1
    COMPOSE_PULL_VER="1.0.1"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_10" \
      "$MOUNT_POINT_2$DEST_PATH_5/$COMPOSE_PULL_FILENAME" \
      "$COMPOSE_PULL_VER" "2" "700"
    EXITCODE6=$?

    EXITCODE7=1
    SYS_CONF_VER="1.1.0"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_11" \
      "$MOUNT_POINT_2$DEST_PATH_5/$SYSCONF_FILENAME" \
      "$SYS_CONF_VER" "2" "700"
    EXITCODE7=$?

    EXITCODE25=1
    NTP_UPDATER_SH_VER="1.1.0"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_29" \
      "$MOUNT_POINT_2$DEST_PATH_5/$NTP_UPDATER_FILENAME" \
      "$NTP_UPDATER_SH_VER" "2" "700"
    EXITCODE25=$?

    EXITCODE26=1
    SYSINFO_M_SH_VER="1.0.0"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_30" \
      "$MOUNT_POINT_2$DEST_PATH_5/$SYSINFO_M_SH_FILENAME" \
      "$SYSINFO_M_SH_VER" "2" "700"
    EXITCODE26=$?

    EXITCODE27=1
    ROLLBACK_SH_VER="1.1.0"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_31" \
      "$MOUNT_POINT_2$DEST_PATH_1/$ROLLBACK_SH_FILENAME" \
      "$ROLLBACK_SH_VER" "2" "700"
    EXITCODE27=$?

    EXITCODE28=1
    SWAP_PART_SH_VER="1.1.0"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_32" \
      "$MOUNT_POINT_2$DEST_PATH_1/$SWAP_PART_SH_FILENAME" \
      "$SWAP_PART_SH_VER" "2" "700"
    EXITCODE28=$?

    EXITCODE8=1; EXITCODE9=1; EXITCODE13=1; EXITCODE14=1; EXITCODE16=1; EXITCODE17=1;
    JPIADMAPI_HOST_SERV_VER="1.0.0"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_20" \
      "$MOUNT_POINT_2$DEST_PATH_2/$SYSCON_HOST_SERV_FILENAME" \
      "$JPIADMAPI_HOST_SERV_VER" "1" "644"
    EXITCODE16=$?

    JPIADMAPI_SERV_VER="1.0.0"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_21" \
      "$MOUNT_POINT_2$DEST_PATH_2/$SYSCON_SERV_FILENAME" \
      "$JPIADMAPI_SERV_VER" "1" "644"
    EXITCODE17=$?

    JPIADMAPI_PULL_VER="1.0.3"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_12" \
      "$MOUNT_POINT_2$DEST_PATH_4/$SYSCON_PULL_FILENAME" \
      "$JPIADMAPI_PULL_VER" "2" "700"
    EXITCODE8=$?
    # Delete jpi-admin-api-pull.sh from /scripts directory
    if [ -f "$MOUNT_POINT_2$DEST_PATH_5/$SYSCON_PULL_FILENAME" ]; then
      rm -f $MOUNT_POINT_2$DEST_PATH_5/$SYSCON_PULL_FILENAME
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] $SYSCON_PULL_FILENAME removed from $MOUNT_POINT_2$DEST_PATH_5." >> $LOG_FILE
    fi

    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_13" \
      "$MOUNT_POINT_2$DEST_PATH_2/$SYSCON_SERVICE_FILENAME" \
      "$JPIADMAPI_PULL_VER" "1" "644"
    EXITCODE9=$?

    JPIADMAPI_AUTORESTART_VER="1.0.3"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_17" \
      "$MOUNT_POINT_2$DEST_PATH_2/$SYSCON_AUTORESTART_SERV_FILENAME" \
      "$JPIADMAPI_AUTORESTART_VER" "1" "644"
    EXITCODE13=$?

    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_18" \
      "$MOUNT_POINT_2$DEST_PATH_4/$SYSCON_AUTORESTART_SCRIPT_FILENAME" \
      "$JPIADMAPI_AUTORESTART_VER" "2" "700"
    EXITCODE14=$?

    if [ $EXITCODE8 -eq 0 ] || [ $EXITCODE9 -eq 0 ] || [ $EXITCODE13 -eq 0 ] || [ $EXITCODE14 -eq 0 ] || \
       [ $EXITCODE16 -eq 0 ] || [ $EXITCODE17 -eq 0 ]; then
      if [ -f /boot/jpiadmapi/disableautorestart ]; then
        node /jpiadmapi/request.restart.js "Admin" "Jpi-admin-api service updated and require restart."
      fi
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Jpi-admin-api service updated and require restart." >> $LOG_FILE
      executeSystemctlDaemonReload
    fi

    EXITCODE23=1; EXITCODE24=1;
    RPIEEPROM_VER="1.0.0"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_27" \
      "$MOUNT_POINT_2$DEST_PATH_2/$RPIEEPROM_SERVICE_FILENAME" \
      "$RPIEEPROM_VER" "1" "644"
    EXITCODE23=$?

    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_28" \
      "$MOUNT_POINT_2$DEST_PATH_4/$RPIEEPROM_SCRIPT_FILENAME" \
      "$RPIEEPROM_VER" "2" "700"
    EXITCODE24=$?

    if [ $EXITCODE23 -eq 0 ] || [ $EXITCODE24 -eq 0 ]; then
      executeSystemctlDaemonReload
    fi

    EXITCODE15=1;
    DOCKER_COMPOSE_VER="1.0.1"
    cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_19" \
      "$MOUNT_POINT_2$DEST_PATH_2/$DOCKER_COMPOSE_SERV_FILENAME" \
      "$DOCKER_COMPOSE_VER" "1" "644"
    EXITCODE15=$?

    if [ $EXITCODE15 -eq 0 ]; then
      node /jpiadmapi/request.restart.js "Admin" "docker-compose service updated and require restart."
      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] docker-compose service updated and require restart." >> $LOG_FILE
      # Run systemctl daemon-reload command
      executeSystemctlDaemonReload
    fi

    # Only run sqlite install if $OS_VERTION not start with db6dc0d5
    if [ -z "$(echo "$OS_VERSION" | grep -oE "\<db6dc0d5")" ]; then
      EXITCODE10=1; EXITCODE11=1
      SQLITE_SCRIPT_VER="1.0.5"
      cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_14" \
        "$MOUNT_POINT_2$DEST_PATH_4/$SQLITE_INSTALL_FILENAME" \
        "$SQLITE_SCRIPT_VER" "2" "700"
      EXITCODE10=$?

      cp_file_if_ver_not_match.sh "$LOG_FILE" "$SRC_FILE_15" \
        "$MOUNT_POINT_2$DEST_PATH_2/$SQLITE_SERVICE_FILENAME" \
        "$SQLITE_SCRIPT_VER" "1" "644"
      EXITCODE11=$?

      umount $MOUNT_POINT_2 2> /dev/null

      # Trigger sqlite CLI installation if sqlite file copy success
      if [ $EXITCODE10 -eq 0 ] && [ $EXITCODE11 -eq 0 ]; then
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Installing sqlite CLI package..." >> $LOG_FILE
        dbus-send --system --print-reply --dest=org.freedesktop.systemd1 \
          /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager.StartUnit \
          string:$SQLITE_SERVICE_FILENAME string:replace
      fi
    else
      umount $MOUNT_POINT_2 2> /dev/null
    fi
  fi

  # Run /etc/fstab patch if $OS_VERTION not start with db6dc0d5
  if [ -z "$(echo "$OS_VERSION" | grep -oE "\<db6dc0d5")" ]; then
    # /etc/fstab check for entry "/dev/mmcblk0p1" and "defaults,uid=1000,gid=8888,fmask=0002,dmask=0002" record
    FSTABFILEPATH='/host/etc/fstab'
    UPDATECONTENT='/dev/mmcblk0p1 /boot vfat defaults,uid=1000,gid=8888,fmask=0002,dmask=0002 0 2'
    UPDATED=false
    LINEEXISTS=false
    if [ -f $FSTABFILEPATH ]; then
      while read line
      do
        ARG1=$(echo $line | awk '{print $1}')
        if [ "$ARG1" = "/dev/mmcblk0p1" ]; then
          LINEEXISTS=true
          ARG4=$(echo $line | awk '{print $4}')
          if [ "$ARG4" = "defaults,uid=1000,gid=8888,fmask=0002,dmask=0002" ]; then UPDATED=true; fi
        fi
      done < $FSTABFILEPATH
    fi

    if [ $LINEEXISTS = false ]; then
      # If "/dev/mmcblk0p1" not exists, append var UPDATECONTENT to /etc/fstab file
      if [ -f $FSTABFILEPATH ]; then
        echo "$UPDATECONTENT" >> $FSTABFILEPATH
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Updated /etc/fstab file." >> $LOG_FILE
        # Set request restart
        node /jpiadmapi/request.restart.js "Host" "/etc/fstab updated and Pi require restart."
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] /etc/fstab updated and Pi require restart." >> $LOG_FILE
      fi
    else
      # If "/dev/mmcblk0p1" exists and "defaults,uid=1000,gid=8888,fmask=0002,dmask=0002" not found then
      # patch /etc/fstab file
      if [ $UPDATED = false ]; then
        # Create /etc/fstab-mod with new content
        while read line
        do
          ARG1=$(echo $line | awk '{print $1}')
          if [ "$ARG1" = "/dev/mmcblk0p1" ]; then
            echo "$UPDATECONTENT" >> "$FSTABFILEPATH-mod"
          else
            echo "$line" >> "$FSTABFILEPATH-mod"
          fi
        done < $FSTABFILEPATH
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Created /etc/fstab-mod file." >> $LOG_FILE

        # Overwrite /etc/fstab file with /etc/fstab-mod file
        cat "$FSTABFILEPATH-mod" > $FSTABFILEPATH
        EXITCODE1=$?
        if [ ! $EXITCODE1 -eq 0 ]; then
          echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Failed to update /etc/fstab file. Exit_code:$EXITCODE1." >> $LOG_FILE
        else
          echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Updated /etc/fstab file." >> $LOG_FILE
        fi
        # Remove /etc/fstab-mod file
        rm "$FSTABFILEPATH-mod"
        EXITCODE2=$?
        if [ ! $EXITCODE2 -eq 0 ]; then
          echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Failed to removed /etc/fstab-mod file. Exit_code:$EXITCODE2." >> $LOG_FILE;
        else
          echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Removed /etc/fstab-mod file." >> $LOG_FILE;
        fi

        if [ $EXITCODE1 -eq 0 ] && [ $EXITCODE2 -eq 0 ]; then
          # Set request restart
          node /jpiadmapi/request.restart.js "Host" "/etc/fstab updated and Pi require restart."
          echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] /etc/fstab updated and Pi require restart." >> $LOG_FILE
        fi
      fi
    fi
  fi

  # File and directory owner change for 3cd images
  if [ "$OS_VERSION" == "3cd4baaa-5e7b-11ea-abe8-0242ac110002" ]; then
    # Find files in /storage path and change owner if necessary
    FILE_PATHS=$(find $STORAGE_PATH -maxdepth 1 -name "*" -type f)
    for FILE_PATH in $FILE_PATHS
    do
      if [ ! -z $FILE_PATH ]; then
        # Get file permission
        PERMISSION=$(stat -c '%u:%g' $FILE_PATH)
        if [ ! "$PERMISSION" = "0:8888" ]; then
          chown 0:8888 $FILE_PATH
          EXITCODE=$?
          if [ ! $EXITCODE -eq 0 ]; then
            echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Failed to change owner for file ${FILE_PATH/${FILE_PATH:0:5}}. Exit_code:$EXITCODE." >> $LOG_FILE
          else
            echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] File ${FILE_PATH/${FILE_PATH:0:5}} owner changed to \"root:pistorage\"." >> $LOG_FILE
          fi
        fi
      fi
    done

    # Find directories in /storage path and change owner if necessary
    DIR_PATHS=$(find $STORAGE_PATH -maxdepth 1 -name "*" -type d)
    for DIR_PATH in $DIR_PATHS
    do
      if [ ! -z $DIR_PATH ] && [ ! "$DIR_PATH" = "$STORAGE_PATH" ] && \
      [ ! "$DIR_PATH" = "$STORAGE_PATH/etc" ] && [ ! "$DIR_PATH" = "$STORAGE_PATH/var" ]; then
        # Get directory permission
        PERMISSION=$(stat -c '%u:%g' $DIR_PATH)
        if [ ! "$PERMISSION" = "0:8888" ]; then
          chown -R 0:8888 $DIR_PATH
          EXITCODE=$?
          if [ ! $EXITCODE -eq 0 ]; then
            echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Failed to change owner for directory ${DIR_PATH/${DIR_PATH:0:5}}. Exit_code:$EXITCODE." >> $LOG_FILE
          else
            echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Directory ${DIR_PATH/${DIR_PATH:0:5}} owner changed to \"root:pistorage\"." >> $LOG_FILE
          fi
        fi
      fi
    done
  fi

  # Only wait sqlite install finish if $OS_VERTION not start with db6dc0d5
  if [ -z "$(echo "$OS_VERSION" | grep -oE "\<db6dc0d5")" ]; then
    # Wait for sqlite CLI installation complete
    if [ $EXITCODE10 -eq 0 ] && [ $EXITCODE11 -eq 0 ]; then
      while [ ! -f $DB_DIR_PATH/sqlite3-install-success ]
      do
        SERVICE_STATUS=$(dbus-send --system --print-reply --dest=org.freedesktop.systemd1 \
          /org/freedesktop/systemd1/unit/sqlite_2dcli_2dinstall_2eservice \
          org.freedesktop.DBus.Properties.Get string:org.freedesktop.systemd1.Unit string:ActiveState | \
          grep -oE 'string ".{1,}"' | grep -oE '".{1,}"' | sed 's/"//g')
        if [ "$SERVICE_STATUS" == "failed" ]; then break; fi
        sleep 5s
      done

      if [ "$SERVICE_STATUS" == "failed" ]; then
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Failed to install Sqlite CLI package." >> $LOG_FILE
      else
        echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Sqlite CLI package install success." >> $LOG_FILE
        node /jpiadmapi/request.restart.js "Admin" "Sqlite package installed, please restart Pi."
      fi

      removeSqlite3InstallStateFile
    fi
  fi
fi

(
  LOOP=true

  while [ $LOOP ]; do
    sleep 60

    nc -zv 127.0.0.1 3001 &> /dev/null
    RES="$?"

    if [ $RES -ne 0 ]; then
      LOOP=false
      killall -9 node
    fi
  done
) &

if [ ! -z "$SYSCON_AUTORESTART" ] && [ $SYSCON_AUTORESTART -eq 1 ]; then
  executeSysconAutoRestart
fi

cd /jpiadmapi && node app.js