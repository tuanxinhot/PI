#!/bin/bash

# === CONSTANTS VARIABLES ====
log_status=("INFO" "WARNING" "ERROR" "DEBUG")

# === color codes =====
readonly RED_COLOR='\033[1;31m'   # red
readonly CYAN_COLOR='\033[1;36m'  # cyan
readonly YLW_COLOR='\033[1;33m'   # yellow
readonly GRN_COLOR='\033[1;32m'   # green
readonly NC='\033[0m'
# === END of CONSTANT VARIABLES ===

function _enable_vnc {
  x11vnc -forever -unixpw_cmd /usr/share/jabil/x11vnc.sh.x -http_oneport -display :0 2>/dev/null &

  # remove comment tag to show "Manage VNC User" menu item
  sed -i 's/<!--CHANGES//g' $default_menu 
  sed -i 's/CHANGES-->//g' $default_menu
}

function _remove_manage_user {
  # Remove Manage VNC User
  if [[ "$VNC" == "FALSE" ]]; then
     sed -i 's/pi ALL \= NOPASSWD \:\/menu\/manage_user.sh.x/\#pi ALL \= NOPASSWD \:\/menu\/manage_user.sh.x/' /etc/sudoers
  fi
}

# Check if the already_run_flag.txt exist. Append/overwrite menu ONLY if the flag file not exists.
function _check_flag_file {
  if [[ -f "$user_defined_menu" ]]; then
    if [[ ! -f "$flag_file" ]]; then
      _replace_menu $OVERWRITE_MENU
      _remove_manage_user
	  
      touch $flag_file
    fi
  else
    # User does not provide menu.xml
    if [[ ! -f "$flag_file" ]]; then
      if [[ "$OVERWRITE_MENU" == "FALSE" ]]; then
        # Call our menu.xml (default menu) since user does not provide menu.xml
        _get_default_menu
        _remove_manage_user
	    else
        # Reserved option for user if user doesn't want any menu
        sed -i 's/<action name="ShowMenu"><menu>root-menu/<\!-- <action name="ShowMenu"><menu>root-menu/g' /etc/xdg/openbox/rc.xml 
        sed -i 's/root-menu<\/menu><\/action>/root-menu<\/menu><\/action> -->/g' /etc/xdg/openbox/rc.xml
	  
        _get_nomenu_msg
	    fi
	  
	    touch $flag_file
	  else
      # Already perform tasks, don't need to carry out second time. Just display the message.
      if [[ "$OVERWRITE_MENU" == "FALSE" ]]; then
        _get_msg
      else
        _get_nomenu_msg
      fi
	  fi
  fi
}

function _get_nomenu_msg {
  echo -e "${YLW_COLOR}[${log_status[1]}] FAILED to find file "$user_defined_menu".${NC}" 
  echo -e "${CYAN_COLOR}[${log_status[0]}] No menu will be display.${NC}"
}

function _get_msg {
  echo -e "${YLW_COLOR}[${log_status[1]}] FAILED to find file "$user_defined_menu".${NC}"
  echo -e "${CYAN_COLOR}[${log_status[0]}] Default menu will be used.${NC}"
}

function _get_default_menu {
  _get_msg
  _append_script_sudoers
}

# Check the value of OVERWRITE_MENU on the compose.yml and apply logic to append/ovewrite menu.
function _replace_menu {
  # TRUE = OVERWRITE menu; FALSE = APPEND menu
  if [[ "$1" == "TRUE" ]]; then
    /bin/cp $user_defined_menu $default_menu
    _append_script_sudoers "replace"
  elif [[ "$1" == "FALSE" ]]; then
    OUTF="$default_menu.out.tmp"
 
    menu_item=$(sed -n '/<menu id="root-menu"/,/<\/openbox_menu>/p' $user_defined_menu | sed '1d' | sed 's/<\/openbox_menu>//' | sed 's/<\/menu>$//') 
    awk -v gitlog="$menu_item" '{print} /<!--default-->/{print gitlog}' $default_menu > $OUTF
    /bin/mv $OUTF $default_menu
 
    _append_script_sudoers "append"
  else
    echo -e "[${log_status[2]}]${RED_COLOR} Invalid value.${NC} Please check the environments in your compose.yml."
  fi
}

# Add the .sh files on the menu to the /etc/sudeors
function _append_script_sudoers {
  # Add script file called on menu.xml to /etc/sudoers
  case $1 in
    "append")
      # Get all .sh files in menu folder
      local menu_scripts=$(ls /menu/*.sh)
      scripts_ls_array=($menu_scripts)
      
      for script_file in "${scripts_ls_array[@]}"; do
        echo "pi ALL = NOPASSWD :$script_file" >> /etc/sudoers
      done
      
      # get the binary script
      binary_item=($(grep -Eo "([a-zA-Z0-9\_\-]+)(.sh.x)$" $default_menu))
      for binary_script in "${binary_item[@]}"; do
        echo "pi ALL = NOPASSWD :/menu/$binary_script" >> /etc/sudoers
      done
    ;;
    "replace")
      # Get .sh files only called on user's menu.xml
      replace_item=($(grep -Eo "([a-zA-Z0-9\_\-]+)(.sh|.sh.x)$" $default_menu))

      for script_file in "${replace_item[@]}"; do
        echo "pi ALL = NOPASSWD :/menu/$script_file" >> /etc/sudoers
      done
    ;;
    *)
      # Get only .sh files called on our default menu.xml
      default_item=($(grep -Eo "([a-zA-Z0-9\_\-]+)(.sh|.sh.x)$" $default_menu))

      for script_file in "${default_item[@]}"; do
        echo "pi ALL = NOPASSWD :/menu/$script_file" >> /etc/sudoers
      done
    ;;
  esac
}

# Get timezone from compose.yml and assigned 
function _set_local_time {
  local tz_region=$(echo "$TZ" | cut -d'"' -f2 | awk -F"/" '{ print $1 }')
  local tz_country=$(echo "$TZ" | cut -d'"' -f2 | awk -F"/" '{ print $2 }')

  local time_zone="${tz_region}"

  # Based on en.wikipedia.org/wiki/List_of_tz_database_time_zones, 
  if [[ -n "${tz_country}" ]]; then
    time_zone+="/${tz_country}"
    
    if [ "${tz_country}" == "Argentina" ] || [ "${tz_country}" == "Indiana" ] || 
       [ "${tz_country}" == "Kentucky" ] || [ "${tz_country}" == "North_Dakota" ]; then
      tz_city=$(echo "$TZ" | cut -d'"' -f2 | awk -F"/" '{ print $3 }')
      time_zone+="/${tz_city}"
    fi
  fi

  LOCALTIME_SYMLINK=$(readlink /etc/localtime)
  ZONEINFO_PATH="/usr/share/zoneinfo/${time_zone}"

  if [[ "${ZONEINFO_PATH}" != "${LOCALTIME_SYMLINK}" ]]; then
    if [[ -L "$LOCALTIME_SYMLINK" ]]; then
      unlink /etc/localtime
    else
      # Create backup copy
      mv /etc/localtime /etc/localtime.backup
    fi

    ln -s "$ZONEINFO_PATH" /etc/localtime
    echo "${time_zone}" > /etc/timezone
    dpkg-reconfigure -f noninteractive tzdata 1>/dev/null
  fi
}

function _get_touchscreen_name {
  device_name=""

  tmp_dir=$(mktemp -d)
  pushd $tmp_dir > /dev/null

  # Export whole database
  udevadm info --export-db > udevdb.txt

  # udev have classifies the input devices (https://wiki.kubuntu.org/X/InputConfiguration)
  # Found touchscreen device
  if [ ! -z "$(cat udevdb.txt | grep 'ID_INPUT_TOUCHSCREEN=1')" ]; then
    csplit -s udevdb.txt /^$/ {*}

    FILES=./xx*

    for f in $FILES; do
      if [[ ! -z $(grep "ID_INPUT_TOUCHSCREEN=1" $f) ]]; then 
        if [[ ! -z $(grep -w "NAME=" $f) ]]; then
          # Extract touchscreen name
          device_name=$(grep -w "NAME=" $f | cut -d "=" -f 2 | cut -d '"' -f 2)
        fi
      fi
    done
  fi

  popd > /dev/null
  rm -rf $tmp_dir

  echo "$device_name"
}

# ===== MAIN =====
# Get SYSCON_IP environment variable on this session
source /etc/environment

# Remove init "$@" and supress warning message on /dev/console 
# in the entry.sh before execute it
cat /usr/bin/entry.sh | sed '/init "$@"/d' | sed 's/\/dev\/console "$tmp_dir\/console"$/\/dev\/console "$tmp_dir\/console" 2\>\/dev\/null/g' > /usr/bin/entry2.sh

chmod +x /usr/bin/entry2.sh 
/usr/bin/entry2.sh

# This is not needed anymore as systemd-udevd is running in background on entry.sh
case $UDEV in
  [o|O][n|N] | [t|T][rue|RUE] | "1")
    $UDEV="on"
  ;;

  [o|O][ff|FF] | [f|F][alse|ALSE] | "0")
    $UDEV="off"
  ;;
esac

# Terminate systemd-udevd called from entry2.sh
# Somehow the unshare --net used when calling /lib/systemd/systemd-udevd --daemon in entry2.sh
# seems like unshared more than network which caused USB hotplug failed. 
# So, we kill the systemd-udevd created by entry2.sh and call it again here. 
if [ $UDEV == "on" ]; then
  kill -15 $(pidof /lib/systemd/systemd-udevd) 2>/dev/null
fi

/lib/systemd/systemd-udevd --daemon

rm /tmp/.X0-lock &>/dev/null || true
# Clean up leftover sockets
dbus-cleanup-sockets >/dev/null 2>&1

/etc/init.d/dbus start 2>/dev/null
# Sometimes when container restart, the service is remained at running. 
# Will caused internal errors and stopped the service. Ended up with "Invalid MIT-MAGIC-COOKIE-1"
dbus_status_code=$(echo $?)

# : equivalent to the built in true
while : ; 
  do
    if [[ "$dbus_status_code" -eq 0 ]]; then
      break
    else
      /etc/init.d/dbus restart 2>/dev/null
      dbus_status_code=$(echo $?)
    fi
done

export DISPLAY=:0
#export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/host/run/dbus/system_bus_socket
# Probably don't need it as there is DBUS_SYSTEM_BUS_ADDRESS exported on 20dbus_xdg-runtime - avoid crash.
# DBUS_SYSTEM_BUS_ADDRESS in here is not accessible out the shell/session running it
#export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/var/run/dbus/system_bus_socket

# ============== SETUP /STORAGE/PI ==============
# Check if there is volume map for /storage/pi
if [[ -d $STORAGE_HOME ]]; then
  # By default, for newly flashed OS, ownership of the .vnc file 
  # added to /boot/appconfig/ is root:root. So, need to change to enable R/W for pi user 
  # to add/remove VNC authorized user.
  
  #if [ -f "$STORAGE_HOME/appconfig/.vnc" ]; then
  #  grp=$(stat -c '%G' $STORAGE_HOME/appconfig/.vnc)

  #  if [ $grp != "pistorage" ]; then
  #    chown -R root:pistorage /storage/pi/appconfig
  #  fi
  #fi

  mkdir -p $STORAGE_HOME/screenshot
  chown -R root:pistorage $STORAGE_HOME
  chmod -R 775 $STORAGE_HOME
else
  echo -e "${YLW_COLOR}[${log_status[1]}] User doesn't volume maps /storage/pi folder.${NC}"
  echo -e "${YLW_COLOR}[${log_status[1]}] Please create volume mapping for /storage/pi/:/storage/pi/ in compose.yml for storage access.${NC}"
fi
# ============================================

# ============== SETUP TIMEZONE ==============
# Set clock time based on the timezone specify on compose.yml
_set_local_time "$TZ"
# ============================================

# ============== DEVICE INFO ==============
# Display Device's Serial Number on tty7
readonly device_serial=$(cat /proc/cpuinfo | grep "Serial" | cut -d':' -f2)
readonly device_model="$(cat /sys/firmware/devicetree/base/model | tr '\0' '\n')"

echo "---------------------------------------------------------------------------------------"
echo -e "[${log_status[0]}]${GRN_COLOR} Serial Number                   :$device_serial ${NC}"
echo -e "[${log_status[0]}]${GRN_COLOR} Device Model                    : $device_model ${NC}"
echo -e "[${log_status[0]}]${GRN_COLOR} X-Window Version                : $(cat /VERSION) ${NC}"
echo -e "[${log_status[0]}]${GRN_COLOR} Current Timezone in Application : $(cat /etc/timezone) ${NC}"
echo "---------------------------------------------------------------------------------------"
# ============================================

# Retrieve current host OS UUID and save to UUID_VERSION
running_ver=$(/sbin/blkid | grep /dev/mmcblk0p2 | awk -F " " '{printf $3}' | cut -d'=' -f2 | sed s/\"//g)
echo $running_ver > /UUID_VERSION

# Retrieve current deployment environment
echo $DEPLOY_ENV > /DEPLOYMENT

# Check environment variable and set up menu
user_defined_menu="/menu/menu.xml"

# menu from base image
default_menu="/etc/xdg/openbox/menu.xml"
flag_file="/already_run_flag.txt"

echo "[${log_status[0]}] Starting X in 2 seconds"

# Check if Monitor is connect for Pi4. Xorg required monitor to be connected on Pi4.
device_family=$(echo "$device_model" | awk -F "Model" '{ print $1 }' | sed 's/[[:blank:]]*$//')
attached_device=$(tvservice -l | awk -F " " 'NR==1{print $1}')
echo "[${log_status[3]}] Number of attached monitor detected: $attached_device"

if [[ "${device_family}" == "Raspberry Pi 4" ]]; then
  [[ "$attached_device" == "0" ]] && has_monitor=false || has_monitor=true
else
  has_monitor=true
fi

if [[ "$has_monitor" = true ]]; then
  touchscreen_prdname=$(_get_touchscreen_name)

  # Captured touchscreen name
  if [[ -n "$touchscreen_prdname" ]]; then
    cat <<EOF > /usr/share/X11/xorg.conf.d/90-touchinput.conf
Section "InputClass"
          Identifier "calibration"
          Driver "libinput"
          MatchProduct "$touchscreen_prdname"
          MatchDevicePath "/dev/input/event*"

          Option  "SwapXY"        "0" # unless it was already set to 1
          Option  "InvertX"       "0"  # unless it was already set
          Option  "InvertY"       "0"  # unless it was already set
          Option "Emulate3Buttons" "True"
          Option "EmulateThirdButton" "1"
          Option "EmulateThirdButtonTimeout" "750"
          Option "EmulateThirdButtonMoveThreshold" "30"
EndSection
EOF
  fi

  sleep 1.5
  #/usr/bin/X -s 0 dpms r -ardelay 660 -arinterval 28 -nolisten tcp &
  /usr/bin/X -s 0 dpms -nolisten tcp &

  # Check if VNC is set to on or off before initiate x11VNC instance
  if [[ "$VNC" == "TRUE" ]]; then
    _enable_vnc
    echo -e "${CYAN_COLOR}[${log_status[0]}] VNC enabled ${NC}"
  
    if [[ ! -f "$STORAGE_HOME/appconfig/.vnc" ]]; then
      echo -e "${YLW_COLOR}[${log_status[1]}] Couldn't find .vnc file. Please make sure you have .vnc file in appconfig directory. ${NC}"
    else
      sed -i 's/\r//g' $STORAGE_HOME/appconfig/.vnc
      sed -i '$a\' $STORAGE_HOME/appconfig/.vnc
    fi

    _check_flag_file
  
  elif [[ "$VNC" == "FALSE" ]]; then
    echo -e "${CYAN_COLOR}[${log_status[0]}] VNC disabled ${NC}"
    _check_flag_file

  # User entered wrong value
  else
    echo -e "${RED_COLOR}[${log_status[2]}] Invalid value. ${NC} Please check the environments in your compose.yml."
  fi

  # Copy system-wide configuration to ~/.config/openbox
  openbox_path="/home/pi/.config/openbox"
  if [[ ! -d "$openbox_path" ]]; then
    mkdir -p $openbox_path
    cp /etc/xdg/openbox/{rc.xml,menu.xml,autostart,environment} $openbox_path
    chown -R pi:pi /home/pi/.config
  fi

  # Execute openbox. Openbox required non-root user
  su - pi -c "DISPLAY=:0 /usr/bin/openbox" &

  #if [ $UDEV == "off" ]; then
  udevadm trigger
  #fi

  while true; do
    if [[ ! -z "$START_UP" ]]; then
      # Extract file extension
      start_up_ext=${START_UP#*.}

      if [[ "${start_up_ext}" == "sh" ]]; then
        if [[ -f $START_UP ]]; then
          source "$START_UP"
        else
          xmessage -title "Invalid Argument" -center -geometry "400x80" "$START_UP: No such file or directory." -fg blue 2>/dev/null
        fi
      else
        eval $START_UP
        xmessage -title "Invalid Argument" -center -geometry "400x80" "$START_UP: Not a script file." -fg blue 2>/dev/null
      fi
    else
      #echo $START_UP | aosd_cat -p 4 -n 80 -R red -o 9999999
      xmessage -title "Invalid Argument" -center -geometry "400x80" "Dockerfile missing 'START_UP'. No environment variable." -fg blue 2>/dev/null
    fi
  done
else
  echo -e "${RED_COLOR}[${log_status[2]}] Xorg required a monitor to be attached. ${NC} Please make sure your device is connected to a monitor."
  sleep 30
  exit 1
fi
