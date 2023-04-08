#!/bin/bash
#version=2.0.0

# System container
case "$1" in
  "start")
    if [ -f /root/jpiadmapi/docker-compose.yml ]; then
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

      # To prevent token hack, Redis password should be generated randomly.
      export REDISPWD=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo ''`
      COMPOSE_HTTP_TIMEOUT=180 /usr/local/bin/docker-compose -f /root/jpiadmapi/docker-compose.yml up
      #/usr/local/bin/docker-compose -f /root/jpiadmapi/docker-compose.yml logs -t -f

      SYSTEM_MSG="`systemctl status jpi-admin-api`"

      if echo $SYSTEM_MSG | grep "port is already allocated"; then
        /bin/systemctl restart docker
      elif echo $SYSTEM_MSG | grep "Error response from daemon:"; then
        sleep 30
      fi
      exit 0
    else
      echo -e "\033[0;31mERROR\033[0m: File '/root/jpiadmapi/docker-compose.yml' not found."
      exit 1
    fi
    ;;
  "stop")
    if [ -f /root/jpiadmapi/docker-compose.yml ]; then
      /usr/local/bin/docker-compose -f /root/jpiadmapi/docker-compose.yml stop
    fi
    exit 0
    ;;
  "reload")
    if [ -f /root/jpiadmapi/docker-compose.yml ]; then
      /usr/local/bin/docker-compose -f /root/jpiadmapi/docker-compose.yml restart
    fi
    exit 0
    ;;
  *)
    ;;
esac