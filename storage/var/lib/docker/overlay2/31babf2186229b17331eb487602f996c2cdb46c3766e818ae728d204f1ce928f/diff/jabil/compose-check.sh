#!/bin/bash
COMPOSE_OLD="compose-old.yml"
COMPOSE_LATEST="/jabil/compose-latest.yml"
COMPOSE_NEW="compose-new.yml"
COMPOSE_YML="compose.yml"

# checking status
APP_NAME="docker.corp.jabil.org/raspberry-pi/x11-webkiosk"
STATUS=0
PARAMS=0
COMMAND=""
PORT="8080"
ENV_CONFIGS=()

# static text
TEXT_02="http://172.16.0.1:3000/api/v1.0"
TEXT_03="volumes:"
TEXT_04="command:"
TEXT_05="environment:"
TEXT_06="ports:"

# System container health check response code
RES_STATUS="$(curl -sL -w "%{http_code}" "$TEXT_02/commands" -o /dev/null)"
# List the file /storage/pi/compose-$(date +%Y%m%d_%H%M%S).yml
CHECK_STORAGE="$(ls /storage/pi | grep -E "compose-[[:digit:]]+_[[:digit:]]+.yml")"


# method appends number of spaces
function SPACE {
  COUNTER=0
  while [ $COUNTER -lt $1 ]; do
    echo -n " "
    ((COUNTER++))
  done
}

# cleanup /storage/pi/compose-$(date +%Y%m%d_%H%M%S).yml
if [ ! -z "$CHECK_STORAGE" ]; then
  # get total count of compose-backup file in /storage/pi
  FILE_COUNT="$(echo "$CHECK_STORAGE" | wc -l)"
  if [ "$FILE_COUNT" -gt 3 ]; then

    # only keep 3 compose-backup file in /storage/pi
    FILE_KEEP="$(($FILE_COUNT - 3))"
    n=1
    while IFS='' read -r LINE || [[ -n "$LINE" ]]; do
      if [ "$n" -le "$FILE_KEEP" ]; then
        rm "/storage/pi/$LINE"
        echo "$n) $LINE has been removed."
      fi
      n=$((n+1))
    done <<< "$CHECK_STORAGE"
  else
    echo "Less than three compose-backup file is found from /storage/pi. The auto-cleanup is skipped."
  fi
else
  echo "No compose-backup file is found from /storage/pi. The auto-cleanup is skipped."
fi

if [ ! -f "$COMPOSE_OLD" ]; then
  # system container is up
  if [ "$RES_STATUS" == "200" ]; then
    # get current compose.yml
    curl -s -X GET "$TEXT_02/sysconf/compose" -o $COMPOSE_OLD
  else
    echo "Error $RES_STATUS. System container unavailable"
    echo "The /boot/compose.yml auto-update is skipped."
    exit $STATUS
  fi
fi

# calculate the number of apps
APP_COUNT="$(cat "$COMPOSE_OLD" | grep 'image:' | sed '/^\s*#/ d' | wc -l)"
CURRENT_COMPOSE_VER="$(cat "$COMPOSE_OLD" | grep -m 1 "### v[[:digit:]].[[:digit:]]" | tr -d ' #')"
CURRENT_APP="$(cat "$COMPOSE_OLD" | sed '/^\s*#/ d' | grep -m 1 "$APP_NAME" | awk '{print $2}' | awk -F':' '{print $1}')"

# verify current compose.yml version
if [ "$CURRENT_COMPOSE_VER" != "$APP_COMPOSE_VER" ]; then
  if [ "$APP_COUNT" -eq 1 ]; then
    if [ "$CURRENT_APP" == "$APP_NAME" ]; then
      while IFS='' read -r LINE || [[ -n "$LINE" ]]; do
        # continue logic if the first character is not # string
        if [[ "${LINE//" "/}" != "#"* ]]; then
          # when first 6 characters are not spaces, change params status to 0
          if [[ "${LINE}" != "$(SPACE 6)"* ]]; then
            # make sure the line is new tag
            if [[ "${LINE}" == *":"* ]]; then
              PARAMS=0
            fi
          else
            # make sure the 7th character is not space
            if [ "${LINE:6:1}" != "$(SPACE 1)" ]; then
              # when first 6 characters are spaces, then continue to the logic
              # this purpose is to check parameters for a tag
              case "$PARAMS" in
                # checking parameters for volumes
                1)
                  # 8th character of the line sets as the first line of the character
                  VOLUME_MAPPING=${LINE:8}
                  # remove carriage return character
                  VOLUME_MAPPING=${VOLUME_MAPPING//$'\r'/}
                  # remove new line character
                  VOLUME_MAPPING=${VOLUME_MAPPING//$'\n'/}
                  # split into array by : character
                  VOLUME_MAPPING=(${VOLUME_MAPPING//":"/ })
                  ;;
                # checking parameters for environment
                2)
                  # 8th character of the line sets as the first line of the character
                  ENV_LINE=${LINE:8}
                  # remove carriage return character
                  ENV_LINE=${ENV_LINE//$'\r'/}
                  # remove new line character
                  ENV_LINE=${ENV_LINE//$'\n'/}
                  # set previous settings into array variable
                  ENV_CONFIGS+=($ENV_LINE)
                  ;;
                # checking parameters for ports
                3)
                  # 8th character of the line sets as the first line of the character
                  PORT=${LINE:8}
                  # remove carriage return character
                  PORT=${PORT//$'\r'/}
                  # remove new line character
                  PORT=${PORT//$'\n'/}
                  # split into array by : character
                  PORT=(${PORT//":"/ })
                  # get the host vnc port value
                  PORT=${PORT[0]}
                  ;;
                *)
                  ;;
              esac
            fi
          fi

          # check volume tag and set params status to 1
          if [[ "${LINE}" == "$(SPACE 4)$TEXT_03"* ]]; then
            PARAMS=1
          fi

          # check command tag and get command's value
          if [[ "${LINE}" == "$(SPACE 4)$TEXT_04"* ]]; then
            COMMAND=${LINE:13}
          fi

          # check environment tag and set params status to 2
          if [[ "${LINE}" == "$(SPACE 4)$TEXT_05"* ]]; then
            PARAMS=2
          fi

          # check ports tag and make sure it existed
          if [[ "${LINE}" == "$(SPACE 4)$TEXT_06"* ]]; then
            PARAMS=3
          fi
        fi
      done < $COMPOSE_OLD

      ####
      if [ $(wc -c $COMPOSE_LATEST | awk '{print $1}') != "0" ]; then
        # read /boot/compose.yml line-by-line
        while IFS='' read -r LINE || [[ -n "$LINE" ]]; do
          if [[ "${LINE//" "/}" != "###"* ]]; then
            # continue logic if the first character is not # string
            if [[ "${LINE}" != "$(SPACE 6)"* ]]; then
              # when first 6 characters are not spaces, change params status to 0
              PARAMS=0
            else
              # when first 6 characters are spaces, then continue to the logic
              # this purpose is to check parameters for a tag
              case "$PARAMS" in
                # checking parameters for volumes
                1)
                  # 8th character of the line sets as the first line of the character
                  VOLUME_MAPPING=${LINE:8}
                  # remove carriage return character
                  VOLUME_MAPPING=${VOLUME_MAPPING//$'\r'/}
                  # remove new line character
                  VOLUME_MAPPING=${VOLUME_MAPPING//$'\n'/}
                  # split into array by : character
                  VOLUME_MAPPING=(${VOLUME_MAPPING//":"/ })
                  ;;
                # checking parameters for environments
                2)
                  # 8th character of the line sets as the first line of the character
                  ENV_NEW=${LINE:8}
                  # remove carriage return character
                  ENV_NEW=${ENV_NEW//$'\r'/}
                  # remove new line character
                  ENV_NEW=${ENV_NEW//$'\n'/}
                  # split into array by = character
                  ENV_NEW=(${ENV_NEW//"="/ })

                  # for-loop to the old environments settings
                  for ENV_CONFIG in "${ENV_CONFIGS[@]}"; do
                    # get environment name and environment value
                    ENV_CONF=(${ENV_CONFIG//"="/ })

                    # compare if environment name will be used in new compose.yml file
                    if [ ${ENV_NEW[0]} == ${ENV_CONF[0]} ]; then
                      # if exist, then use the old environments settings
                      LINE="$(SPACE 6)- $ENV_CONFIG"
                    fi
                  done
                  ;;
                # checking parameters for ports
                3)
                  # using old host vnc port configuration
                  LINE="$(SPACE 6)- $PORT:5900"
                  ;;
                *)
                  ;;
              esac
            fi

            # check volume tag and set params status to 1
            if [[ "${LINE}" == "$(SPACE 4)$TEXT_03"* ]]; then
              PARAMS=1
            fi

            # check command tag and get command's value
            if [[ "${LINE}" == "$(SPACE 4)$TEXT_04"* ]]; then
              LINE="$(SPACE 4)$TEXT_04 $COMMAND"
            fi

            # check environment tag and set params status to 2
            if [[ "${LINE}" == "$(SPACE 4)$TEXT_05"* ]]; then
              PARAMS=2
            fi

            # check ports tag and make sure it existed
            if [[ "${LINE}" == "$(SPACE 4)$TEXT_06"* ]]; then
              PARAMS=3
            fi
          fi

          # DEV_CASE_ONLY: to display the line content
          echo "DEBUG_INFO: $LINE"

          # write the result line into compose.yml
          echo "$LINE" >> $COMPOSE_NEW
        done < $COMPOSE_LATEST

        mv $COMPOSE_NEW $COMPOSE_YML

        # backup current compose.yml to /storage/pi/
        cp $COMPOSE_OLD /storage/pi/compose-$(date +%Y%m%d_%H%M%S).yml
        echo "The current /boot/compose.yml file has been backup to /storage/pi."

        # upload the new compose.yml to /boot
        UPDATE_COMPOSE="$(curl -sL -w "%{http_code}" -X POST "$TEXT_02/sysconf/compose" -H "accept: application/json" -H "Content-Type: multipart/form-data" -F "document=@/$COMPOSE_YML" -o /dev/null)"
        if [ "$UPDATE_COMPOSE" == "200" ]; then
          echo "The /boot/compose.yml auto-update successful"
          STATUS=1
        else
          rm -f $COMPOSE_OLD
          echo "Error $UPDATE_COMPOSE. Failed to update /boot/compose.yml"
        fi
      fi
    else
      echo "Application name: $CURRENT_APP mismatch. The /boot/compose.yml auto-update is skipped." 
    fi
  else
    echo "More than one application is found inside /boot/compose.yml. The /boot/compose.yml auto-update is skipped."
  fi
else
  echo "Current /boot/compose.yml is using latest version, /boot/compose.yml auto-update is skipped."
fi

exit $STATUS

