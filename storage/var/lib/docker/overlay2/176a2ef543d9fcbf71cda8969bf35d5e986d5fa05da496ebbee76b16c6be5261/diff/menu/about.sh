#!/bin/bash

# === CONSTANTS VARIABLES ====
log_status=("INFO" "WARNING" "ERROR" "DEBUG")

readonly PROCESS_NAME="about"

# === color codes =====
readonly RED_COLOR='\033[1;31m'   # red
readonly CYAN_COLOR='\033[1;36m'  # cyan
readonly YLW_COLOR='\033[1;33m'   # yellow
readonly GRN_COLOR='\033[1;32m'   # green
readonly NC='\033[0m'
# === END of CONSTANT VARIABLES ===

function _show_panel_info {
  local warning_txt="$1"

  if [[ -z "$warning_txt" ]]; then
    # Need /dev/null for 1 as empty output will display when clicked ok
    yad --center --fixed --height=250 --width=360 --borders=25  \
        --title="About" --form --separator="" \
        --field="<span><big><b>Serial Number    \t</b></big></span><big> $serial_num</big>  ":LBL \
        --field="<span><big><b>Device Hostname  \t</b></big></span><big>  $hostname</big>  ":LBL \
        --field="<span><big><b>IP Address  \t\t</b></big></span><big>  $ip_address</big>  ":LBL \
        --field="<span><big><b>Interface  \t\t</b></big></span><big>  $interface  $wlan_ssid_signal </big>  ":LBL \
        --field="<span><big><b>Mac Address  \t\t</b></big></span><big>  $mac_address</big>  ":LBL \
        --field="<span><big><b>Machine uptime     \t</b></big></span><big>  $machine_uptime</big>  ":LBL \
        --button=OK --buttons-layout=end \
        1>/dev/null &
       # /dev/null 2>&1 &
  else
    yad --center --fixed --height=250 --width=360 --borders=25  \
        --title="About" --form --separator="" \
        --field="<span><big><b>Serial Number    \t</b></big></span><big> $serial_num</big>  ":LBL \
        --field="<span><big><b>Device Hostname  \t</b></big></span><big>  $hostname</big>  ":LBL \
        --field="<span><big><b>IP Address  \t\t</b></big></span><big>  $ip_address</big>  ":LBL \
        --field="<span><big><b>Interface  \t\t</b></big></span><big>  $interface  $wlan_ssid_signal </big>  ":LBL \
        --field="<span><big><b>Mac Address  \t\t</b></big></span><big>  $mac_address</big>  ":LBL \
        --field="<span><big><b>Machine uptime     \t</b></big></span><big>  $machine_uptime</big>  ":LBL \
        --field="$warning_txt":LBL \
        --button=OK --buttons-layout=end \
        1>/dev/null &
  fi
}

# ====== MAIN ======
export DISPLAY=:0

# == GLOBAL Variables ===
serial_num=$(cat /proc/cpuinfo | grep "Serial" | cut -d':' -f2)
machine_uptime=$(uptime -p)
ip_address=""
hostname=""
interface="N/A"
mac_address="N/A"
wlan_ssid_signal="(<b>ssid:</b> N/A, <b>link quality:</b> N/A)"

#ip_address=$(curl -s http://whatismyip.docker.corp.jabil.org)
#ip_address=$(curl -Ss -X GET "http://$SYSCON_IP/api/v1.0/system/info" | jq '.ip_address' | sed s/\"//g )

# Check for xwindow compatibility
. /usr/share/jabil/compatibility_checking.sh
is_compatible=$(_check_compatibility)
echo "[${log_status[3]}] $PROCESS_NAME - $is_compatible"

# is_compatible value: status OK: 200
status_msg=$(echo "$is_compatible" | cut -d':' -f1 | sed 's/status//' | sed 's/^ *//;s/ *$//;s/  */ /;')

# For older versions (UUID: bff... and below for Stretch & b1183794... and below for Buster)
# still need to curl from whatismyip.
# Curl from whatismyip can be removed after no user using older version image.
case "$status_msg" in
  "OK")
    sys_info=$(curl -Ss -X GET "http://$SYSCON_IP/api/v1.0/system/info")

    if [[ -n "$sys_info" ]]; then
      ip_address=$(echo "$sys_info" | jq '.ip_address' | sed s/\"//g )
      hostname=$(echo "$sys_info"  | jq '.hostname' | sed s/\"//g )
      interface=$(echo "$sys_info"  | jq '.interface' | sed s/\"//g )
      mac_address=$(echo "$sys_info" | jq '.mac_address' | sed s/\"//g )
      
      if [[ "$interface" == "wlan"* ]]; then
        wlan_ssid=$(echo "$sys_info"  | jq '.wlan_ssid' | sed s/\"//g )
        wlan_signal=$(echo "$sys_info"  | jq '.wlan_signal' | sed s/\"//g )
        wlan_ssid_signal="(<b>ssid:</b> $wlan_ssid, <b>link quality:</b> $wlan_signal)"
      else
        wlan_ssid_signal="(<b>ssid:</b> N/A, <b>link quality:</b> N/A)"
      fi

      _show_panel_info "" 
    else
      ip_address=$(curl -s http://whatismyip.docker.corp.jabil.org)
      hostname=$(host "$ip_address" | awk '{ print $5 }' | cut -d'.' -f1)

      warning_msg="\n<span><b> Failed to contact system container. \n Please reach out to Site IT or Pi Support (pi_support@jabil.com).</b></span>\n"
      _show_panel_info "$warning_msg" 

      echo -e "${RED_COLOR}[${log_status[2]}] $PROCESS_NAME: Failed to contact system container. ${NC} Please reach out to Site IT or Pi Support (pi_support@jabil.com)."

      # Need /dev/null for 1 as empty output will display when clicked ok
    #  yad --center --fixed --height=180 --width=360 --borders=25  \
    #      --title="About" --form --separator="" \
    #      --field="<span><big><b>Device Hostname  \t</b></big></span><big>  $hostname</big>  ":LBL \
    #      --field="<span><big><b>IP Address  \t\t</b></big></span><big>  $ip_address</big>  ":LBL \
    #      --field="<span><big><b>Interface  \t</b></big></span><big>  N/A </big>  ":LBL \
    #      --field="<span><big><b>Mac Address  </b></big></span><big>  N/A</big>  ":LBL \
    #      --field="<span><big><b>Serial Number  </b></big></span><big>  $serial_num</big>  ":LBL \
    #      --field="<span><big><b>Machine uptime  </b></big></span><big>$machine_uptime</big>  ":LBL \
    #      --field="\n<span><b> System container failed to up. \n Please reach out to Site IT or Pi Support (pi_support@jabil.com).</b></span>\n":LBL \
    #      --button=OK --buttons-layout=end \
    #    /dev/null 2>&1 &
    fi
  ;;
  "NOT OK")
    ip_address=$(curl -s http://whatismyip.docker.corp.jabil.org)
    hostname=$(host "$ip_address" | awk '{ print $5 }' | cut -d'.' -f1)

    warning_msg="\n<span> You have an incompatible OS version. \n Please check and download for newer OS version to enjoy \n enhanced IP address retrieving method.</span>\n"
    _show_panel_info "$warning_msg" 

    #yad --info --center --fixed --height=130 --width=250 --wrap --borders=20 --timeout=5 \
    #  --title="Incompatible version" \
    #  --text "<big><b>You have an incompatible OS version.</b>\nPlease check and download for newer OS version \nto enjoy enhanced IP address retrieving method.</big>\n"
    #  --button="OK" --buttons-layout=end 2>/dev/null &
    #yad --center --fixed --height=230 --width=360 --borders=25 \
    #    --title="About" --form --separator="" \
     #   --field="<span><big><b>IP address  \t</b></big></span><big>  $ip_address</big>  ":LBL \
    #    --field="<span><big><b>Serial Number  </b></big></span><big>  $serial_num</big>  ":LBL \
    #    --field="<span><big><b>Machine uptime  </b></big></span><big>$machine_uptime</big>  ":LBL \
    #    --field="\n<span> You have an incompatible OS version. \n Please check and download for newer OS version to enjoy \n enhanced IP address retrieving method.</span>\n":LBL \
    #    --button=OK --buttons-layout=end \
    #    1>/dev/null &

    echo -e "${YLW_COLOR}[${log_status[1]}] $PROCESS_NAME: You have an incompatible OS version. ${NC} Please check and download for newer OS version to enjoy enhanced IP address retrieving method."
    #sleep 6
  ;;
  "invalid")
    status_code=`echo "$is_compatible" | cut -d':' -f2 | sed 's/^ *//;s/ *$//;s/  */ /;'`

    yad --info --center --fixed --height=130 --width=230 --wrap --borders=25 \
        --title=" [ERR] Invalid IP address! " \
        --text="<big> Whoops! A bug has eaten the IP address.\n Please contact Jabil Pi Support (pi_support@jabil.com) \n for investigation.</big>\n\n<span><b> Error Code: $status_code </b></span>\n"  \
        --button=OK --buttons-layout=end 2>/dev/null &

    echo -e "${RED_COLOR}[${log_status[2]}] $PROCESS_NAME: (Err Code: $status_code) Whoops! A bug has eaten the IP address.${NC} Please contact Jabil Pi Support (pi_support@jabil.com) for investigation." 
    exit 1
  ;;
esac