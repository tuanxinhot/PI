#!/bin/bash
#version=1.9.0
UPDATER_VERSION="v1.9.0"

if [ -f /root/pi-daily-updater ]; then
  /usr/sbin/rfkill unblock wifi
  for filename in /var/lib/systemd/rfkill/*:wlan ; do
    echo 0 > $filename
  done
fi

DEVICE_PART_2=$(findmnt / -o source -n)
DEVICE_PART_2_NAME=$(echo "$DEVICE_PART_2" | cut -d "/" -f 3)
DEVICE_NAME=$(echo /sys/block/*/"${DEVICE_PART_2_NAME}" | cut -d "/" -f 4)

UPDATE_SERVER="http://pi-update.docker.corp.jabil.org"
SERIAL="`cat /proc/cpuinfo | grep ^Serial | cut -d: -f 2 | tr -d ' '`"
REVISION="`cat /proc/cpuinfo | grep 'Revision' | awk '{print $3}' | sed 's/^1000//'`"
HOSTNAME="`hostname`"
NET_INTERFACE="`route | awk '/default/ { print $8 "_" $5 }' | tr '\n' '|' | sed 's/.$//'`"
MAC_ADDRESS="`find /sys/class/net/*/address | grep -E $(route | awk '/default/ { print $NF }'| tr '\n' '|' | sed 's/.$//') | awk '{print $0}' | while read line; do echo -n $line | cat - $line | tr '\n' '|' | sed 's/\/sys\/class\/net\///' | sed 's/\/address/_/'; done | sed 's/.$//'`"
IP_ADDRESS="`ip route | grep default | awk 'NR==1 { print $(NF-2) }'`"
FLASH_DATE=""
SDCARD_SIZE="`grep $DEVICE_NAME'$' /proc/partitions | awk '{ print $3 }'`"
PARTITION_INFO="`df -h /boot / /storage | tr '\n' '|'`"
COMPOSE_YML="/boot/compose-running.yml"
OS_VERSION="`dumpe2fs -h $DEVICE_PART_2 2>&1 | grep 'Filesystem UUID' | cut -d: -f 2 | tr -d ' '`"
CURL_HEADER="Content-Type: application/json"
SHADOW="`cat /etc/shadow | sed '/systemd-coredump/d' | md5sum | awk '{ print $1 }'`"
DEFAULT_SHADOW=""
FIRMWARE=""
KERNEL="`uname -r`"
SYSCON_STATUS="$(curl -sL -w "%{http_code}" "http://127.0.0.1:3000/api/v1.0/version" -o /dev/null)"
SYSCON=""
RSS=""
BSSID="`iwgetid -r`"
METRIC="`ip route | grep default | awk -v OFS=_ '{ print $5,$NF,$(NF-2) }' | tr '\n' '|' | sed 's/.$//'`"

if [ -a "/boot/updater/server.txt" ]; then
  UPDATE_SERVER="`cat /boot/updater/server.txt | egrep -v '^#'`"
fi

if [ -d /boot/System\ Volume\ Information ]; then
  FLASH_DATE="`stat -c %.19y /boot/System\ Volume\ Information/`"
fi

if [ "$OS_VERSION" != "b28686c2-213e-11ea-b32c-0242ac110002" ]; then
  DEFAULT_SHADOW="`md5sum /root/shadow | awk '{ print $1 }'`"
  SUDO_GROUP="`cat /etc/group | grep sudo | awk -F ':' '{ print $4 }'`"
  SUDOERS="`md5sum /etc/sudoers | awk '{ print $1 }'`"
  CMD_SU="`stat /bin/su | awk NR=='4 { print $2 }' | cut -c2-5`"
  CMD_PASSWD="`stat /usr/bin/passwd | awk NR=='4 { print $2 }' | cut -c2-5`"
  DEFAULT_SUDOERS="`md5sum /root/sudoers | awk '{ print $1 }'`"

  if [ "$SUDO_GROUP" != "piupdate" ]; then
    SHADOW="0"
  fi

  if [ "$SUDOERS" != "$DEFAULT_SUDOERS" ]; then
    SHADOW="0"
  fi

  if [ "$CMD_SU" != "4700" ]; then
    SHADOW="0"
  fi

  if [ "$CMD_PASSWD" != "4700" ]; then
    SHADOW="0"
  fi
fi

if [ -f "/boot/.firmware_revision" ]; then
  FIRMWARE="`cat /boot/.firmware_revision`"
fi

if [ "$SYSCON_STATUS" == "200" ]; then
  SYSCON="`curl -s http://127.0.0.1:3000/api/v1.0/version`"
fi

if [ -f "/root/rss/docker-compose.yml" ]; then
  RSS_CHECK="`head -n 1 /root/rss/docker-compose.yml`"

  if [ "${RSS_CHECK:0:1}" == "#" ]; then
    RSS="`head -n 1 /root/rss/docker-compose.yml | cut -c3- | tr -d '\n' | tr -d '\r'`"
  fi
fi

for ((C=0; C<=2; C++)) do
  if [[ "$NET_INTERFACE" == "" ]] || [[ "$NET_INTERFACE" =~ ^br- ]] || [[ "$NET_INTERFACE" =~ ^veth ]] || [[ "$NET_INTERFACE" =~ ^docker ]] ; then
    sleep 60s
    NET_INTERFACE="`route | awk '/default/ { print $8 "_" $5 }' | tr '\n' '|' | sed 's/.$//'`"
  else
    C=4
  fi
done

# JSON_DATA start
JSON_DATA="{"

# JSON_DATA contents
### SERIAL_NUMBER
JSON_DATA="$JSON_DATA\"serial_number\":\"$SERIAL\","
### UPDATER_VERSION
JSON_DATA="$JSON_DATA\"updater_version\":\"$UPDATER_VERSION\","
### REVISION
JSON_DATA="$JSON_DATA\"revision\":\"$REVISION\","
### HOSTNAME
JSON_DATA="$JSON_DATA\"hostname\":\"$HOSTNAME\","
### NETWORK_INTERFACE
JSON_DATA="$JSON_DATA\"network_interface\":\"$NET_INTERFACE\","
### MAC_ADDRESS
JSON_DATA="$JSON_DATA\"mac_address\":\"$MAC_ADDRESS\","
### FLASH_DATE
JSON_DATA="$JSON_DATA\"flash_date\":\"$FLASH_DATE\","
### SDCARD_SIZE
JSON_DATA="$JSON_DATA\"sdcard_size\":\"$SDCARD_SIZE\","
### OS_VERSION
JSON_DATA="$JSON_DATA\"os_version\":\"$OS_VERSION\","
### IP_ADDRESS
JSON_DATA="$JSON_DATA\"ip_address\":\"$IP_ADDRESS\","
### METRIC
JSON_DATA="$JSON_DATA\"metric\":\"$METRIC\","
### FIRMWARE
JSON_DATA="$JSON_DATA\"firmware\":\"$FIRMWARE\","
### KERNEL
JSON_DATA="$JSON_DATA\"kernel\":\"$KERNEL\","
### RSS
JSON_DATA="$JSON_DATA\"rss\":\"$RSS\","
### SYSCON
if [ "$SYSCON" != "" ]; then
  JSON_DATA="$JSON_DATA\"syscon\":\"$SYSCON\","
fi
### BSSID
if [ "$BSSID" != "" ]; then
  JSON_DATA="$JSON_DATA\"bssid\":\"$BSSID\","
fi
### SHADOW
if [ "$OS_VERSION" != "b28686c2-213e-11ea-b32c-0242ac110002" ]; then
  if [ "$SHADOW" == "$DEFAULT_SHADOW" ]; then
    JSON_DATA="$JSON_DATA\"shadow\":\"$SHADOW\","
  else
    JSON_DATA="$JSON_DATA\"shadow\":\"0\","
  fi
else
  JSON_DATA="$JSON_DATA\"shadow\":\"$SHADOW\","
fi
### PARTITIONS_INFO
JSON_DATA="$JSON_DATA\"partitions_info\":["
while IFS='|' read -d'|' LINE
do
  JSON_DATA="$JSON_DATA\"$LINE\","
done <<< "$PARTITION_INFO"
if [ ${JSON_DATA: -1} != "[" ]; then
  JSON_DATA="${JSON_DATA::-1}"
fi
JSON_DATA="$JSON_DATA],"
### DOCKER_COMPOSE
if [ -f "$COMPOSE_YML" ]; then
  JSON_DATA="$JSON_DATA\"docker_compose\":["
  while IFS='' read -r LINE
  do
    JSON_DATA="$JSON_DATA\"`echo -n \"$LINE\" | sed 's/\t/       /g' | tr -d "\r" | tr -d "\n" | tr '"' "'"`\","
  done < "$COMPOSE_YML"
  JSON_DATA="${JSON_DATA::-1}"
  JSON_DATA="$JSON_DATA]"
else
  JSON_DATA="$JSON_DATA\"docker_compose\":[]"
fi

# JSON_DATA end
JSON_DATA="$JSON_DATA}"

DONE=0
COUNTER=0

#echo "$JSON_DATA"
echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Sending daily pi-update details to server..."

until [ $DONE -eq 1 ] || [ $COUNTER -gt 2 ]; do
  CLIENT_INFO="`curl -s -X POST \"$UPDATE_SERVER/api/v1.0/clientinfo\" -d \"$JSON_DATA\" -H \"$CURL_HEADER\"`"

  if [ "$CLIENT_INFO" == "Data received." ]; then
    if [ -f /root/pi-daily-updater ]; then
      rm -f /root/pi-daily-updater
    fi

    echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Data received at server side."
    DONE=1
  else
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Retrying..."
    ((COUNTER++))
    sleep 30s
  fi

  if [ -f /root/pi-daily-updater ] && [ $COUNTER -gt 2 ]; then
    sleep 1800s
    COUNTER=0
  fi
done