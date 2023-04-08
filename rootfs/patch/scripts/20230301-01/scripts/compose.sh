#!/bin/bash
#version=1.0.0

# Check the kernel modules are not in sync
if [ ! -d "/lib/modules/`uname -r`/" ]; then
  exit 0
fi

# Boot docker container for the application
COUNTER=0

while [ -f /root/first ]; do
  STATUS=`timedatectl status | grep "System clock synchronized:" | awk '{print $4}'`

  if [ "$STATUS" == "yes" ] || [ $COUNTER -eq 180 ]; then
    # setup keyboard after OS upgrade & NTP sync
    # run one time only
    touch /boot/keyboard
    setupcon -k
    mkdir -p /storage/pi/appconfig

    rm -f /root/first
  else
    COUNTER=$((COUNTER+1))
    sleep 1
  fi
done

function ctrl_c() {
  if [ -f /boot/compose-running.yml ]; then
    COMPOSE_HTTP_TIMEOUT=180 /usr/local/bin/docker-compose -f /boot/compose-running.yml stop
    rm -f /boot/compose-running.yml
  fi
}

trap ctrl_c SIGINT

clearRestartCompleteFlag() {
  # Update record where scope is App, set restart_complete column to 1.
  /usr/bin/sqlite3 /storage/var/jpiadmapi/restart.db3 'UPDATE history SET restart_complete=1 WHERE scope="App";'
}

case "$1" in
  "start")
    if [ -f /boot/compose.yml ]; then
      if [ -d /boot/appconfig/ ]; then
        mv -f /boot/appconfig/* /storage/pi/appconfig/ 2> /dev/null
        mv -f /boot/appconfig/.* /storage/pi/appconfig/ 2> /dev/null
        chmod -R 775 /storage/pi/appconfig/
      fi

      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")]"
      rm -f /boot/compose-running.yml &> /dev/null
      cp /boot/compose.yml /boot/compose-running.yml &> /dev/null
      COMPOSE_HTTP_TIMEOUT=180 /usr/local/bin/docker-compose -f /boot/compose.yml up -d --remove-orphans
      /usr/local/bin/docker-compose -f /boot/compose.yml logs -t -f --tail=20
      clearRestartCompleteFlag
    else
      sleep 1
      echo -e "$(date -u +"%Y-%m-%d %H:%M:%S")] \033[0;31mERROR\033[0m: File '/boot/compose.yml' not found (Retrying in 30 seconds...)"
      sleep 29
    fi
    ;;
  "stop")
    if [ -f /boot/compose-running.yml ]; then
      COMPOSE_HTTP_TIMEOUT=180 /usr/local/bin/docker-compose -f /boot/compose-running.yml stop
      rm -f /boot/compose-running.yml
    fi
    ;;
  "reload")
    if [ -f /boot/compose.yml ]; then
      COMPOSE_HTTP_TIMEOUT=180 /usr/local/bin/docker-compose -f /boot/compose.yml restart
      clearRestartCompleteFlag
    fi
    ;;
  *)
    ;;
esac