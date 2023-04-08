#!/bin/bash
#version=2.0.0

case "$1" in
  "start")
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S")]"

    if [ -f /boot/compose.yml ]; then
      TAR_DIR="/storage/var/loadtars/"
      WAIT_IMAGE_EXTRACT=0
      TAR_FILES=""

      #Wait for image-importer service to extract docker images (timeout 5 minutes)
      if [ -d $TAR_DIR ]; then
        while [ "$WAIT_IMAGE_EXTRACT" -lt 301 ]; do
          TAR_FILES="$(ls "$TAR_DIR" | grep -E "*.tar.gz")"

          if [ "$TAR_FILES" == "" ]; then
            WAIT_IMAGE_EXTRACT=301
          else
            if [ "$WAIT_IMAGE_EXTRACT" -eq 0 ]; then
              echo "Please wait while image-importer service is extracting docker images..."
            fi

            ((WAIT_IMAGE_EXTRACT++))
            sleep 1
          fi
        done
      fi

      PIIMAGE_SERVER="http://pi-image.docker.corp.jabil.org"
      SERIAL="`cat /proc/cpuinfo | grep ^Serial | cut -d: -f 2 | tr -d ' '`"
      STATUS="`curl -f -s \"${PIIMAGE_SERVER}/pull?serial=${SERIAL}\"`"

      if [ "$STATUS" != "false" ]; then
        set +m
        shopt -s lastpipe
        /usr/local/bin/docker-compose -f /boot/compose.yml pull --no-parallel 2>&1 | 
        while IFS= read -r line; do
          lines[i]="$line"; ((i++));
          echo "[$(date -u +"%Y-%m-%d %H:%M:%S.%N")] ${lines[i-1]}";

          if [[ ${lines[i-1]} == *"Downloaded newer image"* ]]; then
            DESC=`echo "${lines[i-1]}" | cut -c9- | tr -d '\n'`
            IMAGE_NAME=`echo "${lines[i-1]}" | cut -c36- | tr -d '\n'`
            /usr/bin/sqlite3 /storage/var/jpiadmapi/restart.db3 \
              "insert into history ('scope','updated_by','reason','restart_complete','created_at','updated_at') \
              values ('App','Host','$DESC.',0,strftime('%Y-%m-%d %H:%M:%f +00:00', 'NOW'),strftime('%Y-%m-%d %H:%M:%f +00:00', 'NOW'));"
            IMAGE_ID=`docker inspect $IMAGE_NAME | grep Id | awk -F ":" '{ print $3 }' | rev | cut -c3- | rev`
            DIGEST_IMAGE=`docker inspect $IMAGE_NAME | grep "@sha256:" | tr -d '" '`
            REPO_ID=`echo $DIGEST_IMAGE | grep "@sha256:" | awk -F "@sha256:" '{print $2}' | tr -d '"\n\r'`

            COMPOSE_PULL_LOG="/scripts/compose-pull.log"
            COMPOSE_PULL_TEMP_LOG="/scripts/compose-pull.temp"

            if [ ! -f $COMPOSE_PULL_LOG ]; then
              touch $COMPOSE_PULL_LOG
            fi

            if [ ! -f $COMPOSE_PULL_TEMP_LOG ]; then
              tail -n 5040 $COMPOSE_PULL_LOG > $COMPOSE_PULL_TEMP_LOG
            fi

            mv $COMPOSE_PULL_TEMP_LOG $COMPOSE_PULL_LOG
            echo "$(date -u +"%Y-%m-%d_%H:%M:%S.%N") $IMAGE_NAME $IMAGE_ID $REPO_ID" >> $COMPOSE_PULL_LOG

            COMPOSE_YML="/boot/compose.yml"
            SERIAL="`cat /proc/cpuinfo | grep ^Serial | cut -d: -f 2 | tr -d ' '`"
            JSON_DATA="{\"serial_number\":\"$SERIAL\",\"download_repo_digest\":[\"$DIGEST_IMAGE\"],\"docker_compose\":["
            while IFS='' read -r LINE; do
              JSON_DATA="$JSON_DATA\"`echo -n \"$LINE\" | sed 's/\t/       /g' | tr -d "\r" | tr -d "\n" | tr '"' "'"`\","
            done < "$COMPOSE_YML"
            JSON_DATA="${JSON_DATA::-1}"
            JSON_DATA="$JSON_DATA]}"
            PIUPDATE_SERVER="http://pi-update.docker.corp.jabil.org"
            CURL_HEADER="Content-Type: application/json"
            COMPOSE_COUNTER=0
            COMPLETE=0

            until [ $COMPLETE -eq 1 ] || [ $COMPOSE_COUNTER -gt 2 ]; do
              COMPOSE_INFO="`curl -s -X POST \"$PIUPDATE_SERVER/api/v1.0/composeinfo\" -d \"$JSON_DATA\" -H \"$CURL_HEADER\"`"

              if [ "$COMPOSE_INFO" == "Data received." ]; then
                COMPLETE=1
              else
                ((COMPOSE_COUNTER++))
                sleep 30s
              fi
            done
          fi
        done

        curl -f -s "${PIIMAGE_SERVER}/complete?serial=${SERIAL}"
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
