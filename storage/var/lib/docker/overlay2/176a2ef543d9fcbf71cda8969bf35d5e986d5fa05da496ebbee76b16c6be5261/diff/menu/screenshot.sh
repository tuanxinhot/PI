#!/bin/bash

# === CONSTANTS VARIABLES ====
log_status=("INFO" "WARNING" "ERROR" "DEBUG")

readonly PROCESS_NAME="screenshot"

# === color codes =====
readonly RED_COLOR='\033[1;31m'   # red
readonly CYAN_COLOR='\033[1;36m'  # cyan
readonly YLW_COLOR='\033[1;33m'   # yellow
readonly GRN_COLOR='\033[1;32m'   # green
readonly NC='\033[0m'
# == END of CONSTANT VARIABLES ===

export DISPLAY=:0 

# Check for xwindow compatibility
. /usr/share/jabil/compatibility_checking.sh
is_compatible=$(_check_compatibility)
echo "[${log_status[3]}] $PROCESS_NAME - $is_compatible"

# is_compatible value: status OK: 200
status_msg=`echo "$is_compatible" | cut -d':' -f1 | sed 's/status//' | sed 's/^ *//;s/ *$//;s/  */ /;'`

case "$status_msg" in
  "OK")
    if [[ -d $STORAGE_HOME ]]; then
      SCRNSHOT=xwin_$(date +%Y%m%d_%H%M%S).png
      scrnshot_path="$STORAGE_HOME/screenshot"
      scrot $scrnshot_path/$SCRNSHOT -d $1 2>/dev/null

      yad --info --center --fixed --height=130 --width=250 --borders=25 --wrap \
          --title="Screenshot" \
          --text="<big><b> Screenshot capture!  </b>\n\n<b> Saved to: </b>$scrnshot_path/$SCRNSHOT  \n You can use JPCLI to download captured screenshot.</big>\n" \
          --button="OK" --buttons-layout=end 2>/dev/null &

      echo -e "${CYAN_COLOR}[${log_status[0]}] Screenshot saved to $scrnshot_path/$SCRNSHOT. Please use JPCLI to download captured screenshot.${NC}"
    else
      yad --info --center --fixed --height=130 --width=300 --borders=25 --wrap \
          --title="[ERR] Path not found" \
          --text="<big><b> Invalid path! \n Couldn't find /storage/pi/ directory. </b>\n\n Please make sure you have volume map /storage/pi/ folder \n in compose.yml. </big>\n" \
          --button="OK" --buttons-layout=end 2>/dev/null &
      
      echo -e "${RED_COLOR}[${log_status[2]}] Screenshot capture FAILED. Couldn't find /storage/pi/ directory.${NC}"
      exit 1
    fi
  ;;
  "NOT OK")
    yad --info --center --fixed --height=130 --width=250 --borders=25 --wrap \
        --title="Incompatible version" \
        --text="<big><b> This feature is not compatible to current OS version.  \n Please check and download for newer OS version.</b></big>\n"  \
        --button=OK --buttons-layout=end 2>/dev/null &

    echo -e "${YLW_COLOR}[${log_status[1]}] $PROCESS_NAME: This feature is not compatible to current OS version. ${NC} Please download newer OS version to use this feature."
  ;;
  "invalid")
    status_code=`echo "$is_compatible" | cut -d':' -f2 | sed 's/^ *//;s/ *$//;s/  */ /;'`

    yad --info --center --fixed --height=130 --width=250 --wrap --borders=25 \
        --title="[ERR] Screenshot Failed" \
        --text="<big> Whoops! Something went wrong.\n Please contact Jabil Pi Support (pi_support@jabil.com) for investigation. </big>\n\n<span><b> Error Code: $status_code </b></span>\n"  \
        --button=OK:0 --buttons-layout=end 2>/dev/null &
    
    echo -e "${RED_COLOR}[${log_status[2]}] $PROCESS_NAME: (Err Code: $status_code) Whoops! Something went wrong. ${NC} Please contact Jabil Pi Support (pi_support@jabil.com) for investigation." 
    exit 1
  ;;
esac