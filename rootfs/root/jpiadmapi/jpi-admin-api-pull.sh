#!/bin/bash
#version=2.0.0

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

set +m
shopt -s lastpipe
/usr/local/bin/docker-compose -f /root/jpiadmapi/docker-compose.yml pull --no-parallel 2>&1 | 
while IFS= read -r line; do 
  lines[i]="$line"; ((i++));
  echo "[$(date -u +"%Y-%m-%d %H:%M:%S.%N")] ${lines[i-1]}";

  if [[ ${lines[i-1]} == *"Downloaded newer image"* ]]; then
    IMAGE_NAME=`echo "${lines[i-1]}" | cut -c9- | tr -d '\n'`
    /usr/bin/sqlite3 /storage/var/jpiadmapi/restart.db3 \
      "insert into history ('scope','updated_by','reason','restart_complete','created_at','updated_at') \
      values ('Admin','Host','System Container updated.',0,strftime('%Y-%m-%d %H:%M:%f +00:00', 'NOW'),strftime('%Y-%m-%d %H:%M:%f +00:00', 'NOW'));"

    # Call auto restart system container service
    systemctl start jpi-admin-api-autorestart.service
  fi
done