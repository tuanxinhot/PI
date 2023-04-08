#!/bin/bash
#version=1.2.0

echo "Please wait while starting..."

CURL_PATH="/scripts/curl"
mkdir -p $CURL_PATH/
rm -f $CURL_PATH/*

FIRST="`awk '{ print $1 }' /proc/uptime | cut -d. -f1`"
while [ "$FIRST" -lt "60" ]; do
  sleep 1s
  FIRST="`awk '{ print $1 }' /proc/uptime | cut -d. -f1`"
done

CUR_TTY="tty10"
COLUMN_SIZE="`stty size | awk '{ print $2 }'`"

if [ "$COLUMN_SIZE" -gt 100 ]; then
  while [ true ]; do
    if [ "$COUNTDOWN_PID" != "" ]; then
      kill -9 $COUNTDOWN_PID
      wait $COUNTDOWN_PID 2> /dev/null
    fi

    COUNTDOWN_PID=""

    if [ "$CUR_TTY" == "tty10" ]; then
      rm -f /root/jpiadmapi/sysinfo 2>/dev/null
      clear
      echo "Loading..."

      DEVICE_PART_2=$(findmnt / -o source -n)
      DEVICE_PART_2_NAME=$(echo "$DEVICE_PART_2" | cut -d "/" -f 3)
      DEVICE_NAME=$(echo /sys/block/*/"${DEVICE_PART_2_NAME}" | cut -d "/" -f 4)
      DEVICE="/dev/${DEVICE_NAME}"

      TIMEZONE="`cat /etc/timezone`"
      DATE="`date +\"%s\"`"
      UTCDATE="`date -d @\"$DATE\" -u +\"%Y-%m-%d %H:%M:%S\"`"
      LOCALDATE="`date -d @\"$DATE\" +\"%Y-%m-%d %H:%M:%S\"`"
      SERIAL="`cat /proc/cpuinfo | grep ^Serial | cut -d: -f 2 | tr -d ' '`"
      OS="`dumpe2fs -h $DEVICE_PART_2 2>&1 | grep 'Filesystem UUID' | cut -d: -f 2 | tr -d ' '`"
      MODEL="`tr -d '\0' < /sys/firmware/devicetree/base/model`"
      HOSTNAME="`cat /etc/hostname | tr -d \" \t\n\r\"`"
      UPTIME="`uptime -p | cut -c4-`"
      IPADDR="`ip route | grep default | awk 'NR==1 { print $(NF-2) }'`"
      INTERFACE="N/A"
      MAC="N/A"
      SDCARD="`df -h /boot / /storage | tr '\n' '|' | sed 's/|/\n  /g'`"
      SDCARD_SIZE="`grep $DEVICE_NAME'$' /proc/partitions | awk '{ print $3 }'`"
      SDCARD_SIZE_ROUND="`awk -v var=\"$SDCARD_SIZE\" 'BEGIN { rounded = sprintf(\"%.0fG\", var * 1024 / 1000000000); print rounded }'`"
      MEMORY="`free -h | tr '\n' '|' | sed 's/|/\n  /g'`"
      #VCGTEMP="`vcgencmd measure_temp | cut -c6-`"
      THERMAL_ZONE="`cat /sys/class/thermal/thermal_zone0/temp`"
      MAIN_TEMP="`echo $THERMAL_ZONE | cut -c1-2`"
      DECIMAL_TEMP="`echo $THERMAL_ZONE | cut -c3-3`"
      TEMPERATURE="$MAIN_TEMP.$DECIMAL_TEMP C"
      IPADDR_STATUS=""
      IPADDR_VALID=""
      SYSCON_VERSION="`timeout 3 curl -s -m 3 http://127.0.0.1:3000/api/v1.0/version`"
      BAD_HOSTNAME=""
      RESTART_INFO=""
      METRIC=$(ip route | grep default | awk '{ print "{\"nw_interface\":\""$5"\",\"metric\":\""$NF"\",\"ip_address\":\""$(NF-2)"\"}" }' | tr '\n' ',' | sed 's/.$//')

      if [ -f /storage/var/jpiadmapi/restart.db3 ]; then
        RESTART_INFO=$(/usr/bin/sqlite3 /storage/var/jpiadmapi/restart.db3 "select count() from history where restart_complete=0")
      fi

      if [ "$HOSTNAME" = "raspberrypi" ] || [[ "$HOSTNAME" =~ [^a-zA-Z0-9_] ]]; then
        BAD_HOSTNAME="(Failed to configure)"
      fi

      if [ ! -z "$IPADDR" ]; then
        if [[ ${IPADDR:0:4} != "169." ]]; then
          INTERFACE="`netstat -ie | grep -B1 $IPADDR | awk NR==1'{ print $1 }' | tr -d ':'`"
          if [[ "$INTERFACE" == "wlan"* ]]; then
            SIGNAL="`cat /proc/net/wireless | awk 'END { print $3 }' | sed 's/\.$//'`"
            SSID="`iwgetid $INTERFACE -r`"
            BAND="`iwconfig $INTERFACE | awk 'NR==2 { print $2 $3 }' | cut -c11-`"
            QUALITY="(SSID: $SSID, Link Quality: $SIGNAL/70, Band: $BAND)"
          else
            if [[ "$INTERFACE" == "br-"* ]] || [[ "$INTERFACE" == "docker"* ]]; then
              IPADDR="N/A"
              INTERFACE="N/A"
            fi
            SIGNAL=""
            SSID=""
            BAND=""
            QUALITY=""
          fi
        else
          IPADDR="N/A"
        fi
      else
        IPADDR="N/A"
      fi

      if [ "$INTERFACE" != "N/A" ]; then
        MAC="`find /sys/class/net/${INTERFACE}/address | grep -E $(route -n | awk '/0.0.0.0/ { print $NF }'| tr '\n' '|' | sed 's/.$//') 2> /dev/null | awk '{print $0}' | xargs cat`"

        if [ -z "$MAC" ]; then
          IPADDR="N/A"
          INTERFACE="N/A"
          MAC="N/A"
        fi
      fi

      if [ $IPADDR != "N/A" ]; then
        if [[ ${IPADDR:0:4} == "169." ]]; then
          IPADDR_VALID="(Invalid)"
        else
          IPADDR_VALID="(Valid)"
        fi
      fi

      SYSCON="`docker ps --filter=\"name=jpiadmapi\" --format \"table {{.Names}}\t{{.Status}}\" | tr '\n' '|' | sed 's/|/\n  /g'`"
      DOCKER="`docker ps --format \"table {{.Image}}\t{{.CreatedAt}}\t{{.Status}}\" | sed '/devservices\/jpi-admin-api/d' | sed '/devservices\/jpi-redis/d' | tr '\n' '|' | sed 's/|/\n  /g'`"

      clear
      echo ""
      echo "** JABIL PI *********************************************************************************************************"
      echo ""
      echo "  UTC Date      : $UTCDATE"
      echo "  Local Date    : $LOCALDATE ($TIMEZONE)"
      echo ""
      echo "** DEVICE INFO ******************************************************************************************************"
      echo ""
      echo "  Serial Number : $SERIAL"
      echo "  Model         : $MODEL"
      echo "  OS Version    : $OS"
      echo "  Hostname      : $HOSTNAME $BAD_HOSTNAME"
      echo "  Nw. Interface : $INTERFACE $QUALITY"
      echo "  IP Address    : $IPADDR $IPADDR_VALID"
      echo "  MAC Address   : $MAC"
      echo "  Uptime        : $UPTIME"
      echo "  Temperature   : $TEMPERATURE"
      if [ -z "$RESTART_INFO" ] || [ "$RESTART_INFO" == "" ] || [ "$RESTART_INFO" == "0" ]; then
        echo "  Restart Info  : NONE"
      else
        echo "  Restart Info  : $RESTART_INFO"
      fi
      echo ""
      echo "** SD CARD INFO *****************************************************************************************************"
      echo ""
      echo "  $SDCARD"
      echo "  # Total Size  : $SDCARD_SIZE_ROUND #"
      echo ""
      echo "** MEMORY INFO ******************************************************************************************************"
      echo ""
      echo "  $MEMORY"
      echo "** SYSTEM CONTAINER INFO ********************************************************************************************"
      echo ""
      echo "  # Version       : $SYSCON_VERSION #"
      echo ""
      echo "  $SYSCON"
      echo "** USER APPLICATION INFO ********************************************************************************************"
      echo ""
      echo "  $DOCKER"
      echo "** NETWORK STATUS ***************************************************************************************************"
      echo ""
      echo -ne "  Please wait while the system may take a while to run the network diagnosis...\033[0K\r"

      if [ $IPADDR != "N/A" ]; then
        CURRENT_CURL=$(echo $RANDOM | md5sum | head -c 8)

        URL_CHECK_COUNTER=0
        MAX_URL_CHECK_COUNTER=2
        FOUND_INTERNET=0
        FOUND_JABIL_NETWORK=0
        FOUND_DOCKER_HOME=0
        FOUND_PIUPDATE_HOME=0
        FOUND_PILOGIN_HOME=0

        (
          while [ $URL_CHECK_COUNTER -lt $MAX_URL_CHECK_COUNTER ]; do
            URL_TO_CHECK=""

            if [ $URL_CHECK_COUNTER == 0 ]; then
              URL_TO_CHECK="http://www.google.com/"
            fi

            if [ $URL_CHECK_COUNTER == 1 ]; then
              URL_TO_CHECK="http://www.baidu.com/"
            fi

            CURL_RESULT="`timeout 5 curl -s -m 3 -o /dev/null -I -w "%{http_code}" $URL_TO_CHECK`"

            if [ "$CURL_RESULT" == "200" ]; then
              URL_CHECK_COUNTER=($MAX_URL_CHECK_COUNTER + 1)
              FOUND_INTERNET=1
              touch $CURL_PATH/${CURRENT_CURL}1
            fi

            if [ $URL_CHECK_COUNTER -lt $MAX_URL_CHECK_COUNTER ]; then
              ((URL_CHECK_COUNTER++))
            fi
          done
        ) &
        CURL1_PID=$!

        (
          CURL_RESULT="`timeout 5 curl -s -m 3 -o /dev/null -I -k -w "%{http_code}" https://ipam.corp.jabil.org`"

          if [ "$CURL_RESULT" == "200" ]; then
            FOUND_JABIL_NETWORK=1
            touch $CURL_PATH/${CURRENT_CURL}2
          fi
        ) &
        CURL2_PID=$!

        (
          CURL_RESULT="`timeout 5 curl -s -m 3 -o /dev/null -I -k -w "%{http_code}" https://pi-update.docker.corp.jabil.org`"

          if [ "$CURL_RESULT" == "200" ]; then
            FOUND_PIUPDATE_HOME=1
            touch $CURL_PATH/${CURRENT_CURL}3
          fi
        ) &
        CURL3_PID=$!

        (
          CURL_RESULT="`timeout 5 curl -s -m 3 -o /dev/null -I -k -w "%{http_code}" https://pi-login.docker.corp.jabil.org`"

          if [ "$CURL_RESULT" == "200" ]; then
            FOUND_PILOGIN_HOME=1
            touch $CURL_PATH/${CURRENT_CURL}4
          fi
        ) &
        CURL4_PID=$!

        (
          CURL_RESULT="`timeout 5 curl -s -m 3 -o /dev/null -I -k -w "%{http_code}" https://docker.corp.jabil.org`"

          if [ "$CURL_RESULT" == "200" ]; then
            FOUND_DOCKER_HOME=1
            touch $CURL_PATH/${CURRENT_CURL}5
          fi
        ) &
        CURL5_PID=$!

        wait $CURL1_PID $CURL2_PID $CURL3_PID $CURL4_PID $CURL5_PID

        if [ -f $CURL_PATH/${CURRENT_CURL}1 ]; then
          IPADDR_STATUS="$IPADDR_STATUS Internet: Reachable,"
          FOUND_INTERNET="Reachable"
        else
          IPADDR_STATUS="$IPADDR_STATUS Internet: N/A,"
          FOUND_INTERNET="N/A"
        fi

        if [ -f $CURL_PATH/${CURRENT_CURL}2 ]; then
          IPADDR_STATUS="$IPADDR_STATUS Jabil Network: Reachable,"
          FOUND_JABIL_NETWORK="Reachable"
        else
          IPADDR_STATUS="$IPADDR_STATUS Jabil Network: N/A,"
          FOUND_JABIL_NETWORK="N/A"
        fi

        if [ -f $CURL_PATH/${CURRENT_CURL}3 ]; then
          IPADDR_STATUS="$IPADDR_STATUS Pi-Update: Reachable,"
          FOUND_PIUPDATE_HOME="Reachable"
        else
          IPADDR_STATUS="$IPADDR_STATUS Pi-Update: N/A,"
          FOUND_PIUPDATE_HOME="N/A"
        fi

        if [ -f $CURL_PATH/${CURRENT_CURL}4 ]; then
          IPADDR_STATUS="$IPADDR_STATUS Pi-Login: Reachable,"
          FOUND_PILOGIN_HOME="Reachable"
        else
          IPADDR_STATUS="$IPADDR_STATUS Pi-Login: N/A,"
          FOUND_PILOGIN_HOME="N/A"
        fi

        if [ -f $CURL_PATH/${CURRENT_CURL}5 ]; then
          IPADDR_STATUS="$IPADDR_STATUS Jabil Docker: Reachable"
          FOUND_DOCKER_HOME="Reachable"
        else
          IPADDR_STATUS="$IPADDR_STATUS Jabil Docker: N/A"
          FOUND_DOCKER_HOME="N/A"
        fi

        rm -f $CURL_PATH/${CURRENT_CURL}? &

        echo " $IPADDR_STATUS"
      else
        echo " Internet: N/A, Jabil Network: N/A, Pi-Update: N/A, Pi-Login: N/A, Jabil Docker: N/A"
        FOUND_INTERNET="N/A"
        FOUND_JABIL_NETWORK="N/A"
        FOUND_PIUPDATE_HOME="N/A"
        FOUND_PILOGIN_HOME="N/A"
        FOUND_DOCKER_HOME="N/A"
      fi

      # JSON_DATA start
      JSON_DATA="{"
      JSON_DATA="$JSON_DATA\"serial_number\":\"$SERIAL\","
      JSON_DATA="$JSON_DATA\"os_version\":\"$OS\","
      JSON_DATA="$JSON_DATA\"model\":\"$MODEL\","
      JSON_DATA="$JSON_DATA\"hostname\":\"$HOSTNAME\","
      JSON_DATA="$JSON_DATA\"interface\":\"$INTERFACE\","
      if [[ "$INTERFACE" == "wlan"* ]]; then
        JSON_DATA="$JSON_DATA\"wlan_ssid\":\"$SSID\","
        JSON_DATA="$JSON_DATA\"wlan_signal\":\"$SIGNAL/70\","
      fi
      JSON_DATA="$JSON_DATA\"ip_address\":\"$IPADDR\","
      JSON_DATA="$JSON_DATA\"network_status\":[{"
      JSON_DATA="$JSON_DATA\"internet\":\"$FOUND_INTERNET\","
      JSON_DATA="$JSON_DATA\"jabil_network\":\"$FOUND_JABIL_NETWORK\","
      JSON_DATA="$JSON_DATA\"dtr\":\"$FOUND_DOCKER_HOME\","
      JSON_DATA="$JSON_DATA\"piupdate\":\"$FOUND_PIUPDATE_HOME\","
      JSON_DATA="$JSON_DATA\"pilogin\":\"$FOUND_PILOGIN_HOME\""
      JSON_DATA="$JSON_DATA}],"
      if [ $(ip route | grep default | wc -l) -gt 1 ]; then 
        JSON_DATA="$JSON_DATA\"metric\":[$METRIC],"
      fi
      JSON_DATA="$JSON_DATA\"mac_address\":\"$MAC\","
      JSON_DATA="$JSON_DATA\"uptime\":\"$UPTIME\","
      JSON_DATA="$JSON_DATA\"temperature\":\"$TEMPERATURE\","
      JSON_DATA="$JSON_DATA\"timezone\":\"$TIMEZONE\","
      JSON_DATA="$JSON_DATA\"utc_date\":\"$UTCDATE\","
      JSON_DATA="$JSON_DATA\"local_date\":\"$LOCALDATE\","
      JSON_DATA="$JSON_DATA\"sd_card\":\"$SDCARD_SIZE\","
      JSON_DATA="$JSON_DATA\"partitions_info\":["
      COUNTER=0
      while IFS= read -r LINE
      do
        if [ "$COUNTER" -gt "0" ] && [ "$COUNTER" -lt "4" ]; then
          JSON_DATA="$JSON_DATA{"
          JSON_DATA="$JSON_DATA\"file_system\":\"$(echo $LINE | cut -d' ' -f1)\","
          JSON_DATA="$JSON_DATA\"size\":\"$(echo $LINE | cut -d' ' -f2)\","
          JSON_DATA="$JSON_DATA\"used\":\"$(echo $LINE | cut -d' ' -f3)\","
          JSON_DATA="$JSON_DATA\"available\":\"$(echo $LINE | cut -d' ' -f4)\","
          JSON_DATA="$JSON_DATA\"use_percentage\":\"$(echo $LINE | cut -d' ' -f5)\""
          JSON_DATA="$JSON_DATA},"
        fi
        ((COUNTER++))
      done <<< "$SDCARD"
      if [ "$SDCARD" != "" ]; then
        JSON_DATA="${JSON_DATA::-1}"
      fi
      JSON_DATA="$JSON_DATA],"
      JSON_DATA="$JSON_DATA\"memory\":["
      COUNTER=0
      while IFS= read -r LINE
      do
        if [ "$COUNTER" -gt "0" ] && [ "$COUNTER" -lt "3" ]; then
          JSON_DATA="$JSON_DATA{"
          JSON_DATA="$JSON_DATA\"desc\":\"$(echo $LINE | cut -d' ' -f1 | tr -d ':')\","
          JSON_DATA="$JSON_DATA\"total\":\"$(echo $LINE | cut -d' ' -f2)\","
          JSON_DATA="$JSON_DATA\"used\":\"$(echo $LINE | cut -d' ' -f3)\","
          JSON_DATA="$JSON_DATA\"free\":\"$(echo $LINE | cut -d' ' -f4)\","
          JSON_DATA="$JSON_DATA\"shared\":\"$(echo $LINE | cut -d' ' -f5)\","
          JSON_DATA="$JSON_DATA\"buff\":\"$(echo $LINE | cut -d' ' -f6)\","
          JSON_DATA="$JSON_DATA\"avail\":\"$(echo $LINE | cut -d' ' -f7)\""
          JSON_DATA="$JSON_DATA},"
        fi
        ((COUNTER++))
      done <<< "$MEMORY"
      if [ "$MEMORY" != "" ]; then
        JSON_DATA="${JSON_DATA::-1}"
      fi
      JSON_DATA="$JSON_DATA]"
      JSON_DATA="$JSON_DATA}"
      JSON_DATA="$JSON_DATA<end>"

      echo "$JSON_DATA" > /root/jpiadmapi/sysinfo

      echo ""
      echo "*********************************************************************************************************************"
      echo ""
      echo "Press r key to check Restart Information..."
      echo ""

      (
        secs=60
        while [ $secs -gt 0 ]; do
          echo -ne "Press any other key to refresh this System Information page OR it will be auto-refreshed in ${secs}s...\033[0K\r" > /dev/tty10
          sleep 1
          : $((secs--))
        done
      ) &
      COUNTDOWN_PID=$!

      read -t 60 -n1 -p "" RESTART_INFO_KEY
      if [ "$RESTART_INFO_KEY" == "r" ] || [ "$RESTART_INFO_KEY" == "R" ]; then
        kill -9 $COUNTDOWN_PID
        wait $COUNTDOWN_PID 2> /dev/null
        /scripts/restart_info.sh
      fi
    else
      sleep 1s
    fi

    CUR_TTY="`head -n 1 /sys/devices/virtual/tty/tty0/active`"
  done
else
  /scripts/sysinfo_m.sh
fi