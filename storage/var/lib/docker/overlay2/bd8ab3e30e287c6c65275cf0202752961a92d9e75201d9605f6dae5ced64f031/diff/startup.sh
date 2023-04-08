#!/bin/bash

# set compose.yml version as ENV
export APP_COMPOSE_VER="v5.2"

#/jabil/compose-check.sh
RES="$?"

if [ "$RES" -eq 0 ]; then
  function CHECKER {
    if [ ! -f "$DIR3" ]; then
      # Display a message
      DISPLAY=:0.0 yad --info \
      --title="Information" \
      --text="<b>\n  Please save your username and password for web login.</b>" \
      --button="OK" \
      2>/dev/null

      # Creating the credentials file
      echo "---"
      echo "No credentials found. Creating credentials file."
      echo "---"
      mkdir -p $DIR2
      touch $DIR3
      chmod -R 755 "$DIR2"
      STORE_WEB_LOGIN_PASSWORD
    fi
  }

  # ----------
  # Web Login
  # ----------

  function STORE_WEB_LOGIN_PASSWORD {
    echo -e "${COLOUR1}"

    # Creating a form for web login details
    WEBLOGIN=$(DISPLAY=:0.0 yad --form --width=300 --height=170 \
      --title="Web Login Details" \
      --text="<b>Enter in your login details</b>" \
      --image="/icons/password.png" --image-on-top \
      --field="  Login" \
      --field="  Password:H" \
      2>/dev/null )

    # Creating a case to correspond to the Zenity popup
    case $? in
    0)
      # Get the details from the user
      WUSER="$(echo "$WEBLOGIN" | cut -d'|' -f1)"
      DECPASS="$(echo "$WEBLOGIN" | cut -d'|' -f2)"

      # Exporting the variables
      echo '#!/bin/bash' > "$DIR3"
      echo "export WUSER=\"$WUSER\"" >> "$DIR3"

      # Saving encrypted password into a file
      echo $DECPASS | openssl rsautl -inkey $DIR5 -encrypt | base64 > $DIR4
      DISPLAY=:0.0 yad --info \
      --title="Web Login Details" --timeout=10 \
      --text="<b>\n  Login details saved!</b>" \
      --width=300 \
      --height=100 \
      --button="OK" \
      2>/dev/null &
      ;;
    *)
      echo "No web login details entered."
      ;;
    esac
  }

  function CHECK_CRONTASK_ON {
    MINON=$(cat "$DIR9" 2>/dev/null | grep -w 'on 0' | awk '{print $1}')
    HOURON=$(cat "$DIR9" 2>/dev/null | grep -w 'on 0' | awk '{print $2}')

    if [ -s $DIR9 ]; then
      TIMEON="$(date --date="$HOURON:$MINON" +"%H:%M")"
      echo "Detected previous Display Power ON scheduler."
      echo "Display will Power ON automatically at $TIMEON"
      service cron start
      cat $DIR9 $DIR10 | crontab
    else
      echo "No Display Power ON scheduler detected."
    fi
  }

  function CHECK_CRONTASK_OFF {
    MINOFF=$(cat "$DIR10" 2>/dev/null | grep -w 'standby 0' | awk '{print $1}')
    HOUROFF=$(cat "$DIR10" 2>/dev/null | grep -w 'standby 0' | awk '{print $2}')

    if [ -s $DIR10 ]; then
      TIMEOFF="$(date --date="$HOUROFF:$MINOFF" +"%H:%M")"
      echo "Detected previous Display Power OFF scheduler."
      echo "Display will Power OFF automatically at $TIMEOFF"
      service cron start
      cat $DIR9 $DIR10 | crontab
    else
      echo "No Display Power OFF scheduler detected."
    fi
  }

  function REFRESH {
    if [ ! -z "$AUTO_REFRESH" ]; then
      re='^[0-9]+$'
      if [[ $AUTO_REFRESH =~ $re ]]; then
        INT_CHECK="TRUE"
        if [ $AUTO_REFRESH -lt 10 ]; then
          AUTO_REFRESH=10
          echo "The AUTO_REFRESH interval must be higher/equal than 10 second."
          echo "x11-webkiosk auto refresh enabled with default interval $AUTO_REFRESH second."
        else
          echo "x11-webkiosk auto refresh enabled with custom interval $AUTO_REFRESH second."
        fi
      else
        echo "Invalid Argument: AUTO_REFRESH only accept DIGIT value."
        echo "x11-webkiosk auto refresh disabled."
      fi
    else
      echo "x11-webkiosk auto refresh disabled."
    fi

    if [ "$INT_CHECK" == "TRUE" ]; then
      while true; do
        sleep $AUTO_REFRESH
        DISPLAY=:0.0 xdotool key F5
      done &
    fi
  }

  function OFFLINE_SETUP {
    if [ -s "$DIR12" ]; then
      NTID=$(cat $DIR12 | grep -i ntid | awk -F'=' '{print $2}' | awk -F'"' '{print $2}')
      PASS=$(cat $DIR12 | grep -i password | awk -F'=' '{print $2}' | awk -F'"' '{print $2}')

      if [ ! -z "$NTID" ] && [ ! -z "$PASS" ]; then
        mkdir -p "$DIR2"
        echo '#!/bin/bash' > "$DIR3"
        echo "export WUSER=\"$NTID\"" >> "$DIR3"
        echo "$PASS" | openssl rsautl -inkey $DIR5 -encrypt | base64 > $DIR4
        echo "Web auto login setup completed."
      else
        echo "Detected invalid user input in 'web-login.conf'. Web auto login setup failed"
      fi

      ## Setup complete remove the user details
      rm -f $DIR12
    fi
  }

  # ----------
  # Main Code
  # ----------
  # Initializing variables

  # Variables
  TEXT1="Run Application"
  TEXT2="Change VNC Password"
  TEXT3="Change Web Login/Password"
  HEADER_NTLM="WWW-Authenticate: NTLM"
  COUNTER=0

  # Commands to make consistent layout
  shopt -s nocasematch

  echo "=========================================================================="
  DIR2="/storage/pi/.secret/"
  DIR3="/storage/pi/.secret/credentials.sh"
  DIR4="/storage/pi/.secret/encpass"
  DIR5="/key"
  DIR6="/usr/share/zoneinfo/"
  DIR7="/etc/localtime"
  DIR8="/etc/timezone"
  DIR9="/storage/pi/.cec/tvon"
  DIR10="/storage/pi/.cec/tvoff"
  DIR11="/storage/pi/appconfig/chromium.conf"
  DIR12="/storage/pi/appconfig/web-login.conf"

  # ==========================================================================
  if [ "$AUTOLOGIN" == "TRUE" ] || [ "$AUTOLOGIN" == "FORCE" ]; then
    OFFLINE_SETUP
    CHECKER
  fi

  # Additional configuration file
  if [ -f "$DIR11" ]; then
    echo "Detected additional configuration. /storage/pi/appconfig/chromium.conf file exist."
  else
    echo "No additional configuration. /storage/pi/appconfig/chromium.conf file not exist."
  fi

  (
  echo 'on 0' | cec-client -s -d 1 -o 'Webkiosk' &>/dev/null
  sleep 5
  echo 'as' | cec-client -s -d 1 -o 'Webkiosk' &>/dev/null
  ) &

  CHECK_CRONTASK_ON
  CHECK_CRONTASK_OFF

  # ==========================================================================
  # If the user wants the virtual keyboard to show up
  if [ "$KEYBOARD" == "ENG" ]; then
    /menu/onboard.sh &
  fi

  # ==========================================================================
  # Run forever
  while [ 1 ]; do
    echo "--- $COUNTER --- "
    echo ""

    # Additional configuration file
    # Eg, AUTO_REFRESH
    if [ -f "$DIR11" ]; then
      source "$DIR11"
    fi

    # Webkiosk Choice
    if [ "$AUTOLOGIN" == "TRUE" ]; then
      (
        # Make sure encrypt password file existed
        if [ -f "$DIR3" ] && [ -f "$DIR4" ]; then
          if [ ! -z "$TIME_AUTOLOGIN" ]; then
            sleep $TIME_AUTOLOGIN
          else
            sleep 10
          fi

          # If password text variable not defined
          if [ -z $DECPASS ]; then
            # Set password text variable
            source $DIR3
            DECPASS=`cat $DIR4 | base64 -d | openssl rsautl -inkey $DIR5 -decrypt`
          fi

          NTLM_STATUS=`curl -sI ${@: -1} | grep "$HEADER_NTLM"`
          # Make sure web title is actually asking for authentication
          if [ ${#NTLM_STATUS} -gt 0 ]; then
            echo "${@: -1} website header request for NTLM authentication."
            echo "Passing username and password..."
            # Login website
            DISPLAY=:0.0 xdotool type $WUSER
            DISPLAY=:0.0 xdotool key Tab
            DISPLAY=:0.0 xdotool type $DECPASS
            DISPLAY=:0.0 xdotool key Return
          else
            echo "${@: -1} website header does not request for NTLM authentication."
          fi
        fi
        REFRESH
      ) &
    elif [ "$AUTOLOGIN" == "FORCE" ]; then
      (
        # Make sure encrypt password file existed
        if [ -f "$DIR3" ] && [ -f "$DIR4" ]; then
          if [ ! -z "$TIME_AUTOLOGIN" ]; then
            sleep $TIME_AUTOLOGIN
          else
            sleep 10
          fi

          # If password text variable not defined
          if [ -z $DECPASS ]; then
            # Set password text variable
            source $DIR3
            DECPASS=`cat $DIR4 | base64 -d | openssl rsautl -inkey $DIR5 -decrypt`
          fi

          echo "Passing username and password..."
          # Login website
          DISPLAY=:0.0 xdotool type $WUSER
          DISPLAY=:0.0 xdotool key Tab
          DISPLAY=:0.0 xdotool type $DECPASS
          DISPLAY=:0.0 xdotool key Return
        fi
        REFRESH
      ) &
    else
      REFRESH
    fi
    #no-sandbox, because we're already running in a cgroup sandbox with docker
    #no-first-run, because we don't need to be bothered about search engines, etc
    #kiosk mode since we want to trim down the functionality
    #incognito so we are not bothered to "restore" old tabs on a crash restart, not worried about stale content, or storing content
    #disable-dev-shm-usage, to remove the /dev/shm 64mb shared memory cap in docker

    # replace & to '&' to prevent conflict
    FLAGS="$(echo $@ | sed "s/\&/\'&'/g")"
    su - pi -c "DISPLAY=:0.0 /usr/bin/chromium-browser --no-first-run --dbus-stub --incognito --disable-gpu --start-fullscreen --check-for-update-interval=1 --simulate-critical-update $FLAGS 2>/dev/null"

    echo ""
    echo "--- $COUNTER --- "
    ((COUNTER++))
  done
else
  exit 1
fi
