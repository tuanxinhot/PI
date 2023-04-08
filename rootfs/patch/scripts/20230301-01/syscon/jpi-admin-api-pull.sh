#!/bin/bash
#version=1.0.3

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
    values ('Admin','System','System Container updated.',0,strftime('%Y-%m-%d %H:%M:%f +00:00', 'NOW'),strftime('%Y-%m-%d %H:%M:%f +00:00', 'NOW'));"

  # Call auto restart system container service
  systemctl start jpi-admin-api-autorestart.service
  fi
done

curl -f -s "${SERVER}/complete?serial=${SERIAL}"