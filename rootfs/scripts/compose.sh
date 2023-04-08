#!/bin/bash
#version=2.0.0
UPDATER_VERSION="v2.0.0"

# Check the kernel modules are not in sync
if [ ! -d "/lib/modules/`uname -r`/" ]; then
  exit 0
fi

# Boot docker container for the application
COMPOSE="/boot/compose.yml"
COUNTER=0
UPDATE_SERVER="http://pi-update.docker.corp.jabil.org"

while [ -f /root/first ]; do
  NTP_SYNC="`timedatectl | grep 'synchronized:' | grep 'yes'`"

  if [ "$NTP_SYNC" != "" ] || [ $COUNTER -eq 180 ]; then
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

clear_restart_complete_flag() {
  # Update record where scope is App, set restart_complete column to 1.
  /usr/bin/sqlite3 /storage/var/jpiadmapi/restart.db3 'UPDATE history SET restart_complete=1 WHERE scope="App";'
}

case "$1" in
  "start")
    if [ -f $COMPOSE ]; then
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

      if [ -d /boot/appconfig/ ]; then
        mv -f /boot/appconfig/* /storage/pi/appconfig/ 2> /dev/null
        mv -f /boot/appconfig/.* /storage/pi/appconfig/ 2> /dev/null
        chmod -R 775 /storage/pi/appconfig/
      fi

      (
        function APPEND_COMPOSE_LOG {
          COMPOSE_APP_TEMP_LOG="/scripts/compose.temp"
          COMPOSE_BACKUP_PATH="/storage/var/compose"

          if [ ! -f $COMPOSE_APP_TEMP_LOG ]; then
            tail -n 5040 $COMPOSE_APP_LOG > $COMPOSE_APP_TEMP_LOG
          fi

          mv $COMPOSE_APP_TEMP_LOG $COMPOSE_APP_LOG

          NOW="$(date -u +"%Y-%m-%d_%H:%M:%S.%N")"
          NOWS=""
          COMPOSE_LASTMODS=""

          for APP_IMAGE in $APP_IMAGES; do
            if [ "$NOWS" == "" ]; then
              NOWS="$NOW"
              COMPOSE_LASTMODS="$COMPOSE_LASTMOD"
            else
              NOWS="$NOWS\n$NOW"
              COMPOSE_LASTMODS="$COMPOSE_LASTMODS\n$COMPOSE_LASTMOD"
            fi
          done
          paste -d ' ' <(echo -e "$NOWS") <(echo "$APP_IMAGES") <(echo "$APP_IMAGES_ID") <(echo "$APP_REPOS_ID") <(echo -e "$COMPOSE_LASTMODS") >> $COMPOSE_APP_LOG

          if [ ! -d $COMPOSE_BACKUP_PATH ]; then
            mkdir -p $COMPOSE_BACKUP_PATH
          fi

          if [ ! -f $COMPOSE_BACKUP_PATH/$COMPOSE_LASTMOD ]; then
            cp $COMPOSE $COMPOSE_BACKUP_PATH/$COMPOSE_LASTMOD
          fi
        }

        function APPEND_COMPOSE_PULL_LOG {
          COMPOSE_PULL_LOG="/scripts/compose-pull.log"
          COMPOSE_PULL_TEMP_LOG="/scripts/compose-pull.temp"
          COMPOSE_PULL_DATA=`paste -d '|' <(echo "$APP_IMAGES") <(echo "$APP_IMAGES_ID") <(echo "$APP_REPOS_ID")`
          APP_IMAGE_ID_FOUND=""

          if [ ! -f $COMPOSE_PULL_LOG ]; then
            touch $COMPOSE_PULL_LOG
          fi

          if [ ! -f $COMPOSE_PULL_TEMP_LOG ]; then
            tail -n 5040 $COMPOSE_PULL_LOG > $COMPOSE_PULL_TEMP_LOG
          fi

          mv $COMPOSE_PULL_TEMP_LOG $COMPOSE_PULL_LOG

          for COMPOSE_PULL_RECORD in $COMPOSE_PULL_DATA; do
            IMAGE_NAME=`echo $COMPOSE_PULL_RECORD | awk -F "|" '{print $1}'`
            IMAGE_ID=`echo $COMPOSE_PULL_RECORD | awk -F "|" '{print $2}'`
            REPO_ID=`echo $COMPOSE_PULL_RECORD | awk -F "|" '{print $3}'`
            APP_IMAGE_ID_FOUND=`cat /scripts/compose-pull.log | grep $IMAGE_ID`

            if [ "$APP_IMAGE_ID_FOUND" == "" ]; then
              echo "$(date -u +"%Y-%m-%d_%H:%M:%S.%N") $IMAGE_NAME $IMAGE_ID $REPO_ID" >> $COMPOSE_PULL_LOG
              APP_IMAGE_ID_FOUND=""
            fi
          done
        }

        COMPOSE_APP_LOG="/scripts/compose.log"

        if [ ! -f $COMPOSE_APP_LOG ]; then
          touch $COMPOSE_APP_LOG
        fi

        COMPOSE_LASTMOD=`stat -c %y $COMPOSE | sed 's/ /_/g'`
        COMPOSE_CHANGE=`tail -n 1 $COMPOSE_APP_LOG | grep "$COMPOSE_LASTMOD"`
        APP_IMAGES=`cat $COMPOSE | grep "image:" | tr -d ' \t' | cut -c7-`
        APP_IMAGES_ID=`docker inspect $APP_IMAGES | grep Id | tr -d ' ",' | cut -c11-`
        APP_REPOS_ID=`docker inspect $APP_IMAGES | grep "@sha256:" | awk -F "@sha256:" '{print $2}' | tr -d '"'`

        until [ "$APP_IMAGES_ID" == "[]" ]; do
          LOOP_COUNTER=0

          if [ "$APP_IMAGES_ID" != "[]" ]; then
            APP_IMAGE_ID_FOUND=""
            APP_IMAGE_ID_EXECUTED=""
            COMPOSE_REPO_DIGEST="["

            for APP_IMAGE_ID in $APP_IMAGES_ID; do
              APP_IMAGE_ID_FOUND=`cat /scripts/compose.log | grep $APP_IMAGE_ID`
              APP_DIGEST_ID=`docker image inspect --format '{{ .RepoDigests }}' sha256:$APP_IMAGE_ID | tr -d '[]'`
              COMPOSE_REPO_DIGEST="$COMPOSE_REPO_DIGEST\"$APP_DIGEST_ID\","

              if [ "$APP_IMAGE_ID_FOUND" == "" ] && [ "$APP_IMAGE_ID_EXECUTED" == "" ]; then
                APP_IMAGE_ID_EXECUTED="DONE"
                APPEND_COMPOSE_LOG
                APPEND_COMPOSE_PULL_LOG
                APP_IMAGE_ID_FOUND=""
              fi
            done

            if [ "$APP_IMAGE_ID_EXECUTED" == "" ] && [ "$COMPOSE_CHANGE" == "" ]; then
                APPEND_COMPOSE_LOG
                APPEND_COMPOSE_PULL_LOG
            fi

            if [ $COMPOSE_REPO_DIGEST == "[" ]; then
              COMPOSE_REPO_DIGEST="[]"
            else
              COMPOSE_REPO_DIGEST="${COMPOSE_REPO_DIGEST::-1}]"
            fi

            CURL_HEADER="Content-Type: application/json"
            COMPOSE_YML="/boot/compose.yml"
            SERIAL="`cat /proc/cpuinfo | grep ^Serial | cut -d: -f 2 | tr -d ' '`"

            JSON_DATA="{\"serial_number\":\"$SERIAL\",\"run_repo_digest\":$COMPOSE_REPO_DIGEST,\"compose_updater\":\"$UPDATER_VERSION\","

            if [ -f "$COMPOSE_YML" ]; then
              JSON_DATA="$JSON_DATA\"docker_compose\":["
              while IFS='' read -r LINE; do
                JSON_DATA="$JSON_DATA\"`echo -n \"$LINE\" | sed 's/\t/       /g' | tr -d "\r" | tr -d "\n" | tr '"' "'"`\","
              done < "$COMPOSE_YML"
              JSON_DATA="${JSON_DATA::-1}"
              JSON_DATA="$JSON_DATA]"
            else
              JSON_DATA="$JSON_DATA\"docker_compose\":[]"
            fi

            JSON_DATA="$JSON_DATA}"
            #echo "$JSON_DATA"
            COMPOSE_COUNTER=0
            COMPLETE=0
            APP_EXIT_COUNT="`docker events --since '30m' --until '0s' --filter 'event=die' | grep -Ev 'name=jpiadmapi_nodejs|name=jpiadmapi_redis' | wc -l`"

            if [ "$APP_EXIT_COUNT" -lt 5 ]; then
              until [ $COMPLETE -eq 1 ] || [ $COMPOSE_COUNTER -gt 2 ]; do
                COMPOSE_INFO="`curl -s -X POST \"$UPDATE_SERVER/api/v1.0/composeinfo\" -d \"$JSON_DATA\" -H \"$CURL_HEADER\"`"

                if [ "$COMPOSE_INFO" == "Data received." ]; then
                  COMPLETE=1
                else
                  ((COMPOSE_COUNTER++))
                  sleep 30s
                fi
              done
            fi

            APP_IMAGES_ID="[]"
          else
            CURL_RESULT="`curl -s -m 3 -o /dev/null -I -k -w "%{http_code}" https://docker.corp.jabil.org`"

            if [ "$CURL_RESULT" == "200" ] && [ $LOOP_COUNTER -lt 3 ]; then
              sleep 300s
              APP_IMAGES_ID=`docker inspect $APP_IMAGES | grep Id | tr -d ' ",' | cut -c11-`
              ((LOOP_COUNTER++))
            else
              APP_IMAGES_ID="[]"
            fi
          fi
        done
      ) &

      echo "[$(date -u +"%Y-%m-%d %H:%M:%S")]"
      rm -f /boot/compose-running.yml &> /dev/null
      cp $COMPOSE /boot/compose-running.yml &> /dev/null
      COMPOSE_HTTP_TIMEOUT=180 /usr/local/bin/docker-compose -f $COMPOSE up -d --remove-orphans
      /usr/local/bin/docker-compose -f $COMPOSE logs -t -f --tail=20
      clear_restart_complete_flag

      SYSTEM_MSG="`systemctl status docker-compose`"

      if echo $SYSTEM_MSG | grep "port is already allocated"; then
        /bin/systemctl restart docker
      fi
    else
      sleep 1
      echo -e "$(date -u +"%Y-%m-%d %H:%M:%S")] \033[0;31mERROR\033[0m: File '$COMPOSE' not found (Retrying in 30 seconds...)"
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
    if [ -f $COMPOSE ]; then
      COMPOSE_HTTP_TIMEOUT=180 /usr/local/bin/docker-compose -f $COMPOSE restart
      clear_restart_complete_flag
    fi
    ;;
  *)
    ;;
esac
