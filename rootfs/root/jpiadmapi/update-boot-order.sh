#!/bin/bash
#version=1.0.0

FIRST_BOOT=$1
FIRST_BOOT=`echo "$FIRST_BOOT" | awk '{ print toupper($0) }'`
BOOT_CONF_PATH="/root/jpiadmapi/boot.conf"
MOD_BOOT_CONF_PATH="/root/jpiadmapi/boot-mod.conf"
MOD_BOOT_BIN_PATH="/root/jpiadmapi/pieeprom-new.bin"
BOOTLOADER_BACKUP_DIR="/storage/jpiadmapi/backup/bootloader"
BOOTLOADER_CONFIG_BACKUP="$BOOTLOADER_BACKUP_DIR/config"
BOOTLOADER_BIN_BACKUP="$BOOTLOADER_BACKUP_DIR/binary"
PI4_REVS="a03111,b03111,b03112,b03114,b03115,c03111,c03112,c03114,c03115,d03114,d03115"
CM4_REVS="a03140,b03140,c03140,d03140"

# Delete existing boot.conf
deleteBootConf() {
  if [ -f "$BOOT_CONF_PATH" ]; then rm -f $BOOT_CONF_PATH; fi
  if [ -f "$MOD_BOOT_CONF_PATH" ]; then rm -f $MOD_BOOT_CONF_PATH; fi
  if [ -f "$MOD_BOOT_BIN_PATH" ]; then rm -f $MOD_BOOT_BIN_PATH; fi
}
# Get USB boot order value, Pi4=4, CM4=5
getUsbType() {
  REVISION=$(cat /proc/cpuinfo | grep 'Revision' | awk '{print $3}')
  if [ ! -z "$(echo "$PI4_REVS" | grep "$REVISION")" ]; then
    USB_TYPE_VAL="4"
  elif [ ! -z "$(echo "$CM4_REVS" | grep "$REVISION")" ]; then
    USB_TYPE_VAL="5"
  else
    echo "Current revision $REVISION not match with any known supported revision codes."
    exit 1
  fi
}
# Get current bootloader build date and release status
getCurrentBuildInfo() {
  BUILD_DATE_UNIX=$(printf "%d" "0x$(od "/proc/device-tree/chosen/bootloader/build-timestamp" -v -A n -t x1 | tr -d ' ' )")
  RELEASE_STATUS=$(cat /etc/default/rpi-eeprom-update | sed -e 's/"//g' -e 's/FIRMWARE_RELEASE_STATUS=//g')
}
# Export boot.conf
exportBootConf() {
  rpi-eeprom-config --out $BOOT_CONF_PATH

  getCurrentBuildInfo
  BACKUP_DATE=$(date -u +%Y%m%d-%H%M%S)

  # Backup current boot config
  if [ ! -d "$BOOTLOADER_CONFIG_BACKUP" ]; then mkdir -p "$BOOTLOADER_CONFIG_BACKUP"; fi
  BACKUP_CONFIG_PATH="$BOOTLOADER_CONFIG_BACKUP/boot_backup_$(date -u -Idate -d@$BUILD_DATE_UNIX)_$BACKUP_DATE.conf"
  cp "$BOOT_CONF_PATH" "$BACKUP_CONFIG_PATH"

  # Backup current boot binary file
  if [ ! -d "$BOOTLOADER_BIN_BACKUP" ]; then mkdir -p "$BOOTLOADER_BIN_BACKUP"; fi
  ORIGIN_BIN_PATH=$(find -L /lib/firmware/raspberrypi/bootloader/$RELEASE_STATUS/pieeprom-$(date -u -Idate -d@$BUILD_DATE_UNIX).bin)
  if [ -f "$ORIGIN_BIN_PATH" ]; then
    BACKUP_BIN_PATH="$BOOTLOADER_BIN_BACKUP/pieeprom_$(date -u -Idate -d@$BUILD_DATE_UNIX)_$BACKUP_DATE.bin"
    rpi-eeprom-config $ORIGIN_BIN_PATH --config $BACKUP_CONFIG_PATH --out $BACKUP_BIN_PATH
  else
    echo "Bootloader binary for current eeprom not found. Release=$RELEASE_STATUS, FileName=pieeprom-$(date -u -Idate -d@$BUILD_DATE_UNIX).bin"
    echo "Abort script during backup."
    exit 1
  fi
}
# Command to flash eeprom for CM4 and Pi4
flasheeprom() {
  REVISION=$(cat /proc/cpuinfo | grep 'Revision' | awk '{print $3}')
  if [ ! -z "$(echo "$PI4_REVS" | grep "$REVISION")" ]; then
    rpi-eeprom-update -d -f $MOD_BOOT_BIN_PATH
  elif [ ! -z "$(echo "$CM4_REVS" | grep "$REVISION")" ]; then
    CM4_ENABLE_RPI_EEPROM_UPDATE=1 rpi-eeprom-update -d -f $MOD_BOOT_BIN_PATH
  else
    echo "Current revision $REVISION not match with any known supported revision codes."
    exit 1
  fi
}
# Flash EEPROM with specific binary
saveToEeprom() {
  # This particular code not worked with CM4...
  # rpi-eeprom-config --apply $MOD_BOOT_CONF_PATH
  if [ -f "$MOD_BOOT_BIN_PATH" ]; then rm -f $MOD_BOOT_BIN_PATH; fi
  ORIGIN_BIN_PATH=$(find -L /lib/firmware/raspberrypi/bootloader/$RELEASE_STATUS/pieeprom-$(date -u -Idate -d@$BUILD_DATE_UNIX).bin)
  if [ -f "$ORIGIN_BIN_PATH" ]; then
    rpi-eeprom-config $ORIGIN_BIN_PATH --config $MOD_BOOT_CONF_PATH --out $MOD_BOOT_BIN_PATH
    if [ -f "$MOD_BOOT_BIN_PATH" ]; then
      flasheeprom
    else
      echo "Unable to create pieeprom-new.bin file using new boot config."
      echo "Abort script during flashing."
      exit 1
    fi
  else
    echo "Bootloader binary for current eeprom not found. Release=$RELEASE_STATUS, FileName=pieeprom-$(date -u -Idate -d@$BUILD_DATE_UNIX).bin"
    echo "Abort script during flashing."
    exit 1
  fi
}
# Update boot.conf
updateBootConf() {
  if [ -f "$MOD_BOOT_CONF_PATH" ]; then rm -f $MOD_BOOT_CONF_PATH; fi
  touch $MOD_BOOT_CONF_PATH
  CURRENT_BOOT_ORDER_VAL=$(cat "$BOOT_CONF_PATH" | grep 'BOOT_ORDER' | sed 's/=/ /g' | awk '{ print $2 }')
  if [ -z "$CURRENT_BOOT_ORDER_VAL" ]; then
    cat "$BOOT_CONF_PATH" > $MOD_BOOT_CONF_PATH
    echo "BOOT_ORDER=$VALUE" >> $MOD_BOOT_CONF_PATH
  else
    NEW_CONF=$(cat "$BOOT_CONF_PATH" | sed 's/'"$CURRENT_BOOT_ORDER_VAL"'/'"$VALUE"'/g')
    echo "$NEW_CONF" > $MOD_BOOT_CONF_PATH
  fi
}

case "$FIRST_BOOT" in
  "SDCARD")
    exportBootConf
    getUsbType
    VALUE='0xf'"$USB_TYPE_VAL"'1'
    updateBootConf
    saveToEeprom
    deleteBootConf
    exit 0
    ;;
  "USB")
    exportBootConf
    getUsbType
    VALUE='0xf1'"$USB_TYPE_VAL"''
    updateBootConf
    saveToEeprom
    deleteBootConf
    exit 0
    ;;
  "ABORT")
    # Abort any pending bootloader update
    rpi-eeprom-update -r
    exit 0
    ;;
  *)
    echo "Unrecognized argument \"$FIRST_BOOT\"."
    deleteBootConf
    exit 1
    ;;
esac
