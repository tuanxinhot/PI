#!/bin/bash
#version=1.0.1

case "$1" in
  "start")
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S")]"

    if [ -f /boot/compose.yml ]; then
      SERVER="http://pi-image.docker.corp.jabil.org"
      SERIAL="`cat /proc/cpuinfo | grep ^Serial | cut -d: -f 2 | tr -d ' '`"
      STATUS="`curl -f -s \"${SERVER}/pull?serial=${SERIAL}\"`"

      if [ "$STATUS" != "false" ]; then
        set +m
        shopt -s lastpipe
        /usr/local/bin/docker-compose -f /boot/compose.yml pull --no-parallel 2>&1 | 
        while IFS= read -r line; do
          lines[i]="$line"; ((i++));
          echo "[$(date -u +"%Y-%m-%d %H:%M:%S.%N")] ${lines[i-1]}";

          if [[ ${lines[i-1]} == *"Downloaded newer image"* ]]; then
            IMAGE_NAME=`echo "${lines[i-1]}" | cut -c9- | tr -d '\n'`
            /usr/bin/sqlite3 /storage/var/jpiadmapi/restart.db3 \
              "insert into history ('scope','updated_by','reason','restart_complete','created_at','updated_at') \
              values ('App','System','$IMAGE_NAME.',0,strftime('%Y-%m-%d %H:%M:%f +00:00', 'NOW'),strftime('%Y-%m-%d %H:%M:%f +00:00', 'NOW'));"
          fi
        done

        curl -f -s "${SERVER}/complete?serial=${SERIAL}"
      else
        echo -e "\033[0;31mWARNING\033[0m: Site download reaches maximium limit and will retry again later."
      fi
    else
      echo -e "\033[0;31mERROR\033[0m: File '/boot/compose.yml' not found."
    fi

    echo ""
    ;;
  *)
    ;;
esac
