#!/bin/bash

# === CONSTANTS VARIABLES ====
log_status=("INFO" "WARNING" "ERROR" "DEBUG")

# === color codes =====
readonly RED_COLOR='\033[1;31m'   # red
readonly CYAN_COLOR='\033[1;36m'  # cyan
readonly YLW_COLOR='\033[1;33m'   # yellow
readonly GRN_COLOR='\033[1;32m'   # green
readonly NC='\033[0m'
# == END of CONSTANT VARIABLES ===

export DISPLAY=:0

sn=$(cat /proc/cpuinfo | grep Serial | awk '{print $3}'| tail -c 9)

getinput=$(yad --center --fixed --width=250 --borders=25 \
               --title="SHUTDOWN" \
               --text="<big><b> Please type the '$sn' to SHUTDOWN!</b></big>\n" --entry \
               --button="Cancel":1 --button="OK":0 --buttons-layout=end);return_code=$?

if [[ $return_code -eq 0 ]] ; then
  if [[ "$getinput" == "$sn" ]] ; then
    #sudo shutdown -P now
    url_shutdown="http://$SYSCON_IP/api/v1.0/system/halt"
    shutdown_act=$(curl -X POST "$url_shutdown" 2>/dev/null)
    curl_ret_code=$(echo $?)

    if [[ ! -z "$shutdown_act" ]]; then
      yad --info --center --fixed --height=100 --width=250 --wrap --borders=25 \
          --title="Shutting Down" \
          --text=" <big><b>Have a break. \n Shutting Down $sn...</b></big> " \
          --no-buttons 1>/dev/null &

      echo -n "[${log_status[0]}] "
      echo $shutdown_act | awk -F":" '{ print $2 }' | cut -d "}" -f1
    fi

    # Run dbus-send if system-container API call failed
    if [[ $curl_ret_code -eq 7 ]]; then
      if [[ -d "/var/run/dbus" ]]; then
        yad --info --center --fixed --height=100 --width=250 --wrap --borders=25 \
            --title="Shutting Down" \
            --text=" <big><b>Have a break. \n Shutting down $sn...</b></big> " \
            --no-buttons 1>/dev/null &

        exec sudo /usr/local/bin/dbus_reboot_halt.sh "halt"
        echo -n -e "${CYAN_COLOR}[${log_status[0]}] Shutting down $sn... ${NC}"
      else
        echo -e "${RED_COLOR}[${log_status[2]}] Shutdown failed. System container is unavailable or dead. No halt service found. ${NC}"
        yad --center --fixed --width=250 --height=130 --borders=25 \
            --title="[ERR] SHUTDOWN" \
            --text="<big><b> Please make sure system container is running on your Pi.  \n Contact your System Administrator for further troubleshoot.</b></big>\n" \
            --wrap --button=OK --buttons-layout=end 2>/dev/null &
      fi
    else
      if [[ ! $curl_ret_code -eq 0 ]]; then
        echo -e "${RED_COLOR}[${log_status[2]}] Shutdown failed. Error_Code: $curl_ret_code ${NC}"

        yad --center --fixed --width=250 --height=130 --borders=25 \
            --title="[ERR] SHUTDOWN" \
            --text="<big><b> Shutdown failed. </b>\n Contact your System Administrator for further troubleshoot. </big>\n\n<span><b> Error_Code: $curl_ret_code </b></span>\n" \
            --wrap --button=OK --buttons-layout=end 2>/dev/null &
      fi
    fi
  else
    echo -e "${RED_COLOR}[${log_status[2]}] Shutdown failed. Invalid serial number. Please try again. ${NC}"
    yad --center --fixed --width=250 --height=130 --borders=25 \
	      --title="SHUTDOWN - MISMATCH SERIAL NUMBER!" --window-icon="gtk-dialog-error" \
	      --text="<big><b> Invalid serial number! \n Unable to shutdown. Please try again. </b></big>\n" \
        --wrap --button=OK --buttons-layout=end 2>/dev/null &
  fi
fi
