#!/bin/bash
#version=2.0.0

INTERACTIVE=True
ASK_TO_REBOOT=0
BLACKLIST=/etc/modprobe.d/raspi-blacklist.conf
CONFIG=/boot/config.txt
WPASUPPLICANT_CONF=/boot/wpa_supplicant.conf
USER_CONF=/boot/jpiadmapi/user.conf
GROUP_CONF=/boot/jpiadmapi/group.conf

USER=${SUDO_USER:-$(who -m | awk '{ print $1 }')}

is_pi () {
  ARCH=$(dpkg --print-architecture)
  if [ "$ARCH" = "armhf" ] || [ "$ARCH" = "arm64" ] ; then
    return 0
  else
    return 1
  fi
}

if is_pi ; then
  CMDLINE=/boot/cmdline.txt
else
  CMDLINE=/proc/cmdline
fi

welcome_screen() {
  whiptail --msgbox "\
Welcome to Jabil Pi Configuration (jabilpi-config).

This tool provides menu setup for configuring wireless, hostname,
keyboard layout, timezone, system container access, and compose
application. Please contact Jabil Pi team if you have trouble in
configuring via this menu tool.\
" 20 70 1
}

calc_wt_size() {
  # NOTE: it's tempting to redirect stderr to /dev/null, so supress error
  # output from tput. However in this case, tput detects neither stdout or
  # stderr is a tty and so only gives default 80, 24 values
  WT_HEIGHT=18
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}

list_wlan_interfaces() {
  for dir in /sys/class/net/*/wireless; do
    if [ -d "$dir" ]; then
      basename "$(dirname "$dir")"
    fi
  done
}

get_wifi_country() {
  CODE=${1:-0}
  IFACE="$(list_wlan_interfaces | head -n 1)"
  if [ -z "$IFACE" ]; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "No wireless interface found" 20 60
    fi
    return 1
  fi
  if ! wpa_cli -i "$IFACE" status > /dev/null 2>&1; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "Could not communicate with wpa_supplicant" 20 60
    fi
    return 1
  fi
  wpa_cli -i "$IFACE" save_config > /dev/null 2>&1
  COUNTRY="$(wpa_cli -i "$IFACE" get country)"
  if [ "$COUNTRY" = "FAIL" ]; then
    return 1
  fi
  if [ $CODE = 0 ]; then
    echo "$COUNTRY"
  fi
  return 0
}

do_wifi_country_selection() {
  oIFS="$IFS"

  if [ "$COUNTRY" != "" ]; then
    unset COUNTRY
  fi

  while [ -z "$COUNTRY" ] && [ "$INTERACTIVE" = True ]; do
    VALUE=$(cat /usr/share/zoneinfo/iso3166.tab | tail -n +26 | tr '\t' '/' | tr '\n' '/')
    IFS="/"
    COUNTRY=$(whiptail --title "Country Selection (jabilpi-config)" --menu "Select the country in which the Pi is to be used" 20 60 10 ${VALUE} 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then
      if [ -z "$COUNTRY" ] || [ "$COUNTRY" == "" ]; then
        unset COUNTRY
        whiptail --msgbox "COUNTRY cannot be empty. Please try again." 20 60
      else
        IFS=$oIFS
        ((WIFI_MENU++))
        return 0
      fi
    elif [ $? -ne 0 ]; then
      IFS=$oIFS
      ((WIFI_MENU--))
      return 0
    fi
  done
}

do_wifi_ssid_input() {
  if [ "$SSID" != "" ]; then
    unset SSID
  fi

  while [ -z "$SSID" ] && [ "$INTERACTIVE" = True ]; do
    SSID=$(whiptail --inputbox "Please enter SSID" 20 60 "$OLD_SSID" 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then
      OLD_SSID=$SSID
      if [ -z "$SSID" ] || [ "$SSID" == "" ]; then
        unset SSID
        whiptail --msgbox "SSID cannot be empty. Please try again." 20 60
      else
        ((WIFI_MENU++))
        return 0
      fi
    else
      ((WIFI_MENU--))
      return 0
    fi
  done
}

do_wifi_identity_input() {
  if [ "$IDENTITY" != "" ]; then
    unset IDENTITY
  fi

  while [ -z "$IDENTITY" ] && [ "$INTERACTIVE" = True ]; do
    IDENTITY=$(whiptail --inputbox "Please enter IDENTITY (NTID)" 20 60 "$OLD_IDENTITY" 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then
      OLD_IDENTITY=$IDENTITY
      if [ -z "$IDENTITY" ] || [ "$IDENTITY" == "" ]; then
        unset IDENTITY
        whiptail --msgbox "IDENTITY (NTID) cannot be empty. Please try again." 20 60
      else
        ((WIFI_MENU++))
        return 0
      fi
    else
      ((WIFI_MENU--))
      return 0
    fi
  done
}

do_wifi_password_input() {
  if [ "$PASSWORD" != "" ]; then
    unset PASSWORD
  fi

  while [ -z "$PASSWORD" ] && [ "$INTERACTIVE" = True ]; do
    PASSWORD=$(whiptail --passwordbox "Please enter password." 20 60 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then
      if [ -z "$PASSWORD" ] || [ "$PASSWORD" == "" ]; then
        unset PASSWORD
        whiptail --msgbox "PASSWORD cannot be empty. Please try again." 20 60
      else
        ((WIFI_MENU++))
        return 0
      fi
    elif [ $? -ne 0 ]; then
      ((WIFI_MENU--))
      return 0
    fi
  done
}

do_wifi_wpaeap_confirmation() {
  while [ "$INTERACTIVE" = True ]; do
    whiptail --yesno "KEY MGMT : WPA-EAP\n\nCOUNTRY  : $COUNTRY\nSSID     : $SSID\nIDENTITY : $IDENTITY\nPASSWORD : ********" 13 40 3>&1 1>&2 2>&3
    if [ $? -eq 0 ]; then
      ((WIFI_MENU++))
      return 0
    else
      ((WIFI_MENU--))
      return 0
    fi
  done
}

do_wifi_wpapsk_confirmation() {
  while [ "$INTERACTIVE" = True ]; do
    whiptail --yesno "KEY MGMT : WPA-PSK\n\nCOUNTRY  : $COUNTRY\nSSID     : $SSID\nPASSWORD : ********" 13 40 3>&1 1>&2 2>&3
    if [ $? -eq 0 ]; then
      ((WIFI_MENU++))
      return 0
    else
      ((WIFI_MENU--))
      return 0
    fi
  done
}

do_password_encrypt_wpaeap() {
  ENCRYPTED_PASSWORD=`echo -n $PASSWORD | iconv -t utf16le | openssl md4 | awk '{print $2}' | tr -d '\r\n'`
  {
    echo 'country='$COUNTRY
    echo 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev'
    echo 'update_config=1'
    echo ''
    echo 'network={'
    echo 'ssid="'$SSID'"'
    echo 'key_mgmt=WPA-EAP'
    echo 'eap=PEAP'
    echo 'identity="'$IDENTITY'"'
    echo 'password=hash:'$ENCRYPTED_PASSWORD
    echo '}'
  } > "$WPASUPPLICANT_CONF"
  sync
  ((WIFI_MENU++))
}

do_password_encrypt_wpapsk() {
  ENCRYPTED_PASSWORD=`wpa_passphrase $SSID $PASSWORD | grep psk | grep -v "#psk" | awk -F'=' '{print $2}' | tr -d '\r\n'`
  {
    echo 'country='$COUNTRY
    echo 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev'
    echo 'update_config=1'
    echo ''
    echo 'network={'
    echo 'scan_ssid=1'
    echo 'ssid="'$SSID'"'
    echo 'psk='$ENCRYPTED_PASSWORD
    echo '}'
  } > "$WPASUPPLICANT_CONF"
  sync
  ((WIFI_MENU++))
}

do_wifi_test() {
  whiptail --infobox "Please wait patiently while connecting the wireless network..." 10 60
  systemctl restart wpa_supplicant
  systemctl restart dhcpcd
  sleep 5
  IWGETID="`iwgetid`"

  if [ "$IWGETID" == "" ]; then
    whiptail --msgbox "Failed to connect wireless SSID. Please configure again!" 10 60
  else
    whiptail --msgbox "Successfully connected wireless SSID." 10 60
    rm -f /root/jabilpi-config > /dev/null
    ASK_TO_REBOOT=1
  fi
  ((WIFI_MENU++))
}

do_wifi_ntid_password() {
  WIFI_MENU=1
  while [ $WIFI_MENU -gt 0 ] && [ $WIFI_MENU -lt 8 ]; do
    case "$WIFI_MENU" in
      1)
        do_wifi_country_selection
        ;;
      2)
        do_wifi_ssid_input
        ;;
      3)
        do_wifi_identity_input
        ;;
      4)
        do_wifi_password_input
        ;;
      5)
        do_wifi_wpaeap_confirmation
        ;;
      6)
        do_password_encrypt_wpaeap
        ;;
      7)
        do_wifi_test
        ;;
      *)
        WIFI_MENU=0
        ;;
    esac
  done
}

do_wifi_preshared_key() {
  WIFI_MENU=1
  while [ $WIFI_MENU -gt 0 ] && [ $WIFI_MENU -lt 7 ]; do
    case "$WIFI_MENU" in
      1)
        do_wifi_country_selection
        ;;
      2)
        do_wifi_ssid_input
        ;;
      3)
        do_wifi_password_input
        ;;
      4)
        do_wifi_wpapsk_confirmation
        ;;
      5)
        do_password_encrypt_wpaeap
        ;;
      6)
        do_wifi_test
        ;;
      *)
        WIFI_MENU=0
        ;;
    esac
  done
}

do_wifi_ssid_passphrase() {
  RET=0
  IFACE_LIST="$(list_wlan_interfaces)"
  IFACE="$(echo "$IFACE_LIST" | head -n 1)"

  if [ -z "$IFACE" ]; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "No wireless interface found" 20 60
    fi
    return 1
  fi

  if ! wpa_cli -i "$IFACE" status > /dev/null 2>&1; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "Could not communicate with wpa_supplicant" 20 60
    fi
    return 1
  fi

  case "$1" in
    "ntidpwd")
      do_wifi_ntid_password
      return 0
      ;;
   "sharedpwd")
      do_wifi_preshared_key
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

do_wifi_wext_driver() {
  sed -i -e 's/^env wpa_supplicant_driver/#&/' /boot/dhcpcd.conf
  sed -i 's/nl80211,wext/wext,nl80211/' /lib/dhcpcd/dhcpcd-hooks/10-wpa_supplicant
  whiptail --msgbox "Successfully set 'wext' driver as primary wireless driver." 20 60
  ASK_TO_REBOOT=1
  whiptail --msgbox "Require OS reboot for taking the effects" 20 60
  return 0
}

do_wifi_nl80211_driver() {
  sed -i -e 's/^env wpa_supplicant_driver/#&/' /boot/dhcpcd.conf
  sed -i 's/wext,nl80211/nl80211,wext/' /lib/dhcpcd/dhcpcd-hooks/10-wpa_supplicant
  whiptail --msgbox "Successfully set 'nl80211' driver as primary wireless driver." 20 60
  whiptail --infobox "Restarting wireless connection..." 10 60
  systemctl restart wpa_supplicant
  systemctl restart dhcpcd
  return 0
}

do_wifi_5ghz_band_freq_list() {
  IWGETID="`iwgetid`"

  if [ "$IWGETID" == "" ]; then
    whiptail --msgbox "Please connect wireless network first" 10 60
  else
    SCAN_5GHZ_SSID=$(iwgetid | cut -d\" -f2 | tr -d '"')
    whiptail --infobox "Scanning 5Ghz band of SSID '$SCAN_5GHZ_SSID'..." 10 60

    SCAN_5GHZ_BAND_RESULT=$(/usr/local/bin/wifiscan $SCAN_5GHZ_SSID 5ghz -)
    CURRENT_FREQ_1=$(iw $(iwgetid | awk '{print $1}') info | grep channel | cut -d "(" -f2 | cut -c1)

    if [ "$SCAN_5GHZ_BAND_RESULT" != "" ]; then
      if [ -f /boot/wpa_supplicant.conf ]; then
        whiptail --infobox "Updating 5Ghz band frequency list into /boot/wpa_supplicant.conf..." 10 60
        FILE_EXT=$(echo $RANDOM | md5sum | head -c 8; echo)

        while IFS= read -r line; do
          filtered_line=$(echo "$line" | sed 's/^ *//g')
          if [[ "$filtered_line" != freq_list* ]]; then
            if [ "$filtered_line" == "}" ]; then
              echo "freq_list=5035 5040 5045 5055 5060 5080 5160 5170 5180 5190 5200 5210 5220 5230 5240 5250 5260 5270 5280 5290 5300 5310 5320 5340 5480 5500 5510 5520 5530 5540 5550 5560 5570 5580 5590 5600 5610 5620 5630 5640 5660 5670 5680 5690 5700 5710 5720 5745 5755 5765 5775 5785 5795 5805 5815 5825 5835 5845 5855 5865 5875 5885 5910 5915 5920 5935 5940 5945 5960 5980"
            fi
            echo "$filtered_line"
          fi
        done < /boot/wpa_supplicant.conf >> /boot/wpa_supplicant.$FILE_EXT

        whiptail --msgbox "Successfully Updated /boot/wpa_supplicant.conf!" 20 60

        mv /boot/wpa_supplicant.$FILE_EXT /boot/wpa_supplicant.conf

        whiptail --infobox "Restarting wireless connection..." 10 60
        systemctl restart wpa_supplicant
        systemctl restart dhcpcd

        return 0
      else
        whiptail --msgbox "/boot/wpa_supplicant.conf file not found." 20 60
      fi
    else
      whiptail --msgbox "No 5Ghz band of SSID '$SCAN_5GHZ_SSID' found." 20 60
    fi
  fi

  return 1
}

do_wifi_all_bands_freq_list() {
  FREQ_LIST_RESULT=$(cat /boot/wpa_supplicant.conf | grep freq_list=)
  if [ "$FREQ_LIST_RESULT" != "" ]; then
    sed -i -e '/freq_list=/d' /boot/wpa_supplicant.conf
    whiptail --msgbox "Successfully Updated /boot/wpa_supplicant.conf!" 20 60
    whiptail --infobox "Restarting wireless connection..." 10 60
    systemctl restart wpa_supplicant
    systemctl restart dhcpcd
  else
    whiptail --msgbox "Nothing changed because it has already enabled for all bands wireless connection!" 20 60
  fi
}

do_wireless_full_menu() {
  FUN=$(whiptail --title "Wireless Configuration (jabilpi-config)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --ok-button Select \
    "1 WPA-EAP" "     Set for Wi-Fi with Jabil NTID and password" \
    "2 WPA-PSK" "     Set for Wi-Fi with a shared password" \
    "3 WEP" "     Set for Wi-Fi with a shared password" \
    "4 wext" "     Set 'wext' as primary wireless driver" \
    "5 nl80211" "     Set 'nl80211' as primary wireless driver" \
    "6 5Ghz Band" "     Enable for 5Ghz band wireless connection only" \
    "7 All Bands" "     Enable for all bands wireless connection" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      1\ *) do_wifi_ssid_passphrase ntidpwd ;;
      2\ *) do_wifi_ssid_passphrase sharedpwd ;;
      3\ *) do_wifi_ssid_passphrase sharedpwd ;;
      4\ *) do_wifi_wext_driver ;;
      5\ *) do_wifi_nl80211_driver ;;
      6\ *) do_wifi_5ghz_band_freq_list ;;
      7\ *) do_wifi_all_bands_freq_list ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

do_wpasupplicant_menu() {
  unset COUNTRY
  unset SSID
  unset IDENTITY
  unset PASSWORD

  ETH_IP=`ip -br addr show | grep ^eth | awk '{print $3}'`
  WLAN_IP=`ip -br addr show | grep ^wlan | awk '{print $3}'`

  if [[ "$ETH_IP" =~ ^169* ]]; then
    unset $ETH_IP
  fi

  if [[ "$WLAN_IP" =~ ^169* ]]; then
    unset $WLAN_IP
  fi

  if [ "$ETH_IP" == "" ] && [ "$WLAN_IP" == "" ]; then
    do_wireless_full_menu
  elif [ -f /root/jabilpi-config ]; then
    do_wireless_full_menu
  else
    FUN=$(whiptail --title "Wireless Configuration (jabilpi-config)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --ok-button Select \
      "1 wext" "     Set 'wext' as primary wireless driver" \
      "2 nl80211" "     Set 'nl80211' as primary wireless driver" \
      "3 5Ghz Band" "     Enable for 5Ghz band wireless connection only" \
      "4 All Bands" "     Enable for all bands wireless connection" \
      3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
      return 0
    elif [ $RET -eq 0 ]; then
      case "$FUN" in
        1\ *) do_wifi_wext_driver ;;
        2\ *) do_wifi_nl80211_driver ;;
        3\ *) do_wifi_5ghz_band_freq_list ;;
        4\ *) do_wifi_all_bands_freq_list ;;
        *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
      esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
    fi
  fi
}

do_hostname() {
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "\
Please note: RFCs mandate that a hostname's labels \
may contain only the ASCII letters 'a' through 'z' (case-insensitive),
the digits '0' through '9', and the hyphen.
Hostname labels cannot begin or end with a hyphen.
No other symbols, punctuation characters, or blank spaces are permitted.\
" 20 70 1
  fi
  CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
  if [ "$INTERACTIVE" = True ]; then
    NEW_HOSTNAME=$(whiptail --inputbox "Please enter a hostname" 20 60 "$CURRENT_HOSTNAME" 3>&1 1>&2 2>&3)
  else
    NEW_HOSTNAME=$1
    true
  fi
  if [ $? -eq 0 ]; then
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
    ASK_TO_REBOOT=1
  fi
}

do_configure_keyboard() {
  printf "Reloading keymap. This may take a short while\n"
  if [ "$INTERACTIVE" = True ]; then
    dpkg-reconfigure keyboard-configuration
  else
    local KEYMAP="$1"
    sed -i /etc/default/keyboard -e "s/^XKBLAYOUT.*/XKBLAYOUT=\"$KEYMAP\"/"
    dpkg-reconfigure -f noninteractive keyboard-configuration
  fi
  invoke-rc.d keyboard-setup start
  setsid sh -c 'exec setupcon -k --force <> /dev/tty1 >&0 2>&1'
  udevadm trigger --subsystem-match=input --action=change
  return 0
}

do_setup_keyboard() {
  rm -f /etc/default/keyboard
  cp /boot/keyboard /etc/default/keyboard
  do_configure_keyboard
  cp /etc/default/keyboard /boot/keyboard
  rm -f /etc/default/keyboard
  ln -s /boot/keyboard /etc/default/keyboard
}

do_change_timezone() {
  if [ "$INTERACTIVE" = True ]; then
    dpkg-reconfigure tzdata
  else
    local TIMEZONE="$1"
    if [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
      return 1;
    fi
    rm /etc/localtime
    echo "$TIMEZONE" > /etc/timezone
    dpkg-reconfigure -f noninteractive tzdata
  fi

  cp /etc/timezone /boot/timezone
}

do_check_user_conf() {
  if [ -z "$NTID" ] || [ "$NTID" == "" ]; then
    unset NTID
    whiptail --msgbox "NT ID cannot be empty." 20 60
  fi

  if [ ! -z "$NTID" ] || [ "$NTID" != "" ]; then
    if [[ "$NTID" =~ \ |\' ]]; then
      unset NTID
      whiptail --msgbox "NT ID cannot contains white space." 20 60
    fi
  fi

  if [ ! -z "$NTID" ] || [ "$NTID" != "" ]; then
    if [[ "$NTID" =~ [^a-zA-Z0-9_] ]]; then
      unset NTID
      whiptail --msgbox "NT ID accepts only alphanumeric and underscore." 20 60
    fi
  fi

  if [ ! -z "$NTID" ] || [ "$NTID" != "" ]; then
    if [ -f $USER_CONF ]; then
      while read LINE; do
        if [ "$LINE" == "$NTID" ]; then
          whiptail --msgbox "NT ID '$NTID' existed at $USER_CONF." 20 60
          unset NTID
        fi
      done < $USER_CONF
    fi
  fi
}

do_user_input() {
  unset NTID
  CANCEL="0"
  while [ -z "$NTID" ] && [ "$CANCEL" == "0" ] && [ "$INTERACTIVE" = True ]; do
    NTID=$(whiptail --inputbox "Please enter NT ID for user access" 20 60 3>&1 1>&2 2>&3)
    RET="$?"
    if [ "$RET" == "1" ]; then
      CANCEL="1"
    else
      do_check_user_conf
    fi
  done
}

do_check_group_conf() {
  if [ -z "$NTGROUP" ] || [ "$NTGROUP" == "" ]; then
    unset NTGROUP
    whiptail --msgbox "NT GROUP cannot be empty." 20 60
  else
    NTGROUP=`echo $NTGROUP | xargs`
  fi

  if [ ! -z "$NTGROUP" ] || [ "$NTGROUP" != "" ]; then
    if [[ "$NTGROUP" =~ [^a-zA-Z0-9_\ ] ]]; then
      unset NTGROUP
      whiptail --msgbox "NT GROUP accepts only alphanumeric, space and underscore." 20 60
    fi
  fi

  if [ ! -z "$NTGROUP" ] || [ "$NTGROUP" != "" ]; then
    if [ -f $GROUP_CONF ]; then
      while read LINE; do
        if [ "$LINE" == "$NTGROUP" ]; then
          whiptail --msgbox "NT GROUP '$NTGROUP' existed at $GROUP_CONF." 20 60
          unset NTGROUP
        fi
      done < $GROUP_CONF
    fi
  fi
}

do_group_input() {
  unset NTGROUP
  CANCEL="0"
  while [ -z "$NTGROUP" ] && [ "$CANCEL" == "0" ] && [ "$INTERACTIVE" = True ]; do
    NTGROUP=$(whiptail --inputbox "Please enter NT GROUP for group access" 20 60 3>&1 1>&2 2>&3)
    RET="$?"
    if [ "$RET" == "1" ]; then
      CANCEL="1"
    else
      do_check_group_conf
    fi
  done
}

do_access_adding() {
  case "$1" in
    "user")
      do_user_input
      if [ "$CANCEL" == "0" ]; then
        echo "$NTID" >> $USER_CONF
        sync
      fi
      return 0 ;;
   "group")
      do_group_input
      if [ "$CANCEL" == "0" ]; then
        echo "$NTGROUP" >> $GROUP_CONF
        sync
      fi
      return 0 ;;
    *)
      return 1 ;;
  esac
}

do_access_menu() {
  LOOP=0
  while [ $LOOP == 0 ]; do
    FUN=$(whiptail --title "System Container Access Configuration (jabilpi-config)" --menu "Setup Options" 12 65 2 --ok-button Select \
      "1" "   Add User" \
      "2" "   Add Group" \
      3>&1 1>&2 2>&3)
    RET=$?
    LOOP=$RET
    if [ $RET -eq 1 ]; then
      return 0
    elif [ $RET -eq 0 ]; then
      case "$FUN" in  
        1) do_access_adding user ;;
        2) do_access_adding group ;;
        *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
      esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
    fi
  done
}

do_select_app() {
  oIFS="$IFS"

  if [ "$APP" != "" ]; then
    unset APP
  fi

  while [ -z "$APP" ] && [ "$INTERACTIVE" = True ]; do
    URL="http://pi-update.docker.corp.jabil.org/library/apps.list"
    CURL_RESULT="`timeout 5 curl -s -m 3 -o /dev/null -I -w "%{http_code}" $URL`"

    if [ "$CURL_RESULT" == "200" ]; then
      CURL_RET_DATA=$(curl -s "$URL")
      VALUE=$(echo "$CURL_RET_DATA" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' | awk -F'|' '{printf("%s/     %s/",$1,$2)}' | rev | cut -c2- | rev)
      MENU_WIDTH=$(($(echo "$CURL_RET_DATA" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' | awk -F'|' '{printf("%s     %s/\n",$1,$2)}' | rev | cut -c2- | rev | wc -L)+14))
      MENU_HEIGHT=0
      IFS="/"
      APP=$(whiptail --title "Compose Application Selection (jabilpi-config)" --menu "Select the compose application in which the Pi is to be used" $MENU_HEIGHT $MENU_WIDTH $WT_MENU_HEIGHT ${VALUE} 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        if [ -z "$APP" ] || [ "$APP" == "" ]; then
          unset APP
          whiptail --msgbox "APP cannot be empty. Please try again." 20 60
        else
          IFS=$oIFS
          COMPOSE_URL=$(echo "$CURL_RET_DATA" | grep $APP | awk -F'|' '{print $3}')
          if [ "$COMPOSE_URL" != "" ]; then
            whiptail --infobox "Downloading ${APP}'s compose.yml..." 10 60
            curl -s $COMPOSE_URL -o /boot/compose.yml
            whiptail --msgbox "Finished downloading ${APP}'s compose.yml..." 10 60
          else
            whiptail --msgbox "Cannot find ${APP}'s compose.yml from server side." 10 60
          fi
        fi
      else
        IFS=$oIFS
      fi
    else
      whiptail --msgbox "Server side cannot be reached. Please try again later." 20 60
    fi
    return 0
  done
}

do_edit_app_config() {
  nano /boot/compose.yml
}

do_compose_app() {
  LOOP=0
  while [ $LOOP == 0 ]; do
    FUN=$(whiptail --title "Compose Application (jabilpi-config)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --ok-button Select \
      "1 Select" "     Choose and download known compose application" \
      "2 Edit" "     Edit /boot/compose.yml configuration file" \
      3>&1 1>&2 2>&3)
    RET=$?
    LOOP=$RET
    if [ $RET -eq 1 ]; then
      return 0
    elif [ $RET -eq 0 ]; then
      case "$FUN" in
        1\ *) do_select_app ;;
        2\ *) do_edit_app_config ;;
        *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
      esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
    fi
  done
}

do_finish() {
  if [ $ASK_TO_REBOOT -eq 1 ]; then
    whiptail --yesno "Would you like to reboot now?" 10 60 2
    if [ $? -eq 0 ]; then # yes
      sync
      chvt 1
      reboot
    fi
  fi
}

do_reboot() {
  ASK_TO_REBOOT=1
  do_finish
}

do_poweroff() {
  whiptail --yesno "Would you like to shutdown now?" 10 60 2
  if [ $? -eq 0 ]; then # yes
    sync
    chvt 1
    poweroff
  fi
}

do_wavemon() {
  wavemon
}

#
# Interactive use loop
#
echo "Please wait while starting..."

FIRST="`awk '{ print $1 }' /proc/uptime | cut -d. -f1`"
while [ "$FIRST" -lt "60" ]; do
  sleep 1s
  FIRST="`awk '{ print $1 }' /proc/uptime | cut -d. -f1`"
done

if [ "$INTERACTIVE" = True ]; then
  [ -e $CONFIG ] || touch $CONFIG
  calc_wt_size
  USER="pi"
  if is_pi ; then
    while true; do
      if [ -f /root/jabilpi-config ]; then
        welcome_screen

        while true; do
          FUN=$(whiptail --title "Jabil Pi Configuration Tool (jabilpi-config)" --backtitle "$(tr -d '\0' </proc/device-tree/model)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
          "1 Wireless" "   Configure wireless settings" \
          "2 Hostname" "   Configure hostname" \
          "3 Keyboard" "   Configure keyboard layout" \
          "4 Timezone" "   Set timezone" \
          "5 System Container" "   Configure user/group for System Container access" \
          "6 Compose Application" "   Configure compose application" \
          "7 WaveMon" "   Wifi Monitor" \
          "8 Reboot" "   Restart Pi OS" \
          "9 Shutdown" "   Power Off Pi" \
          3>&1 1>&2 2>&3)
          RET=$?
          if [ $RET -eq 1 ]; then
            rm -f /root/jabilpi-config > /dev/null
            do_finish
            #chvt 10
            #exit 0
          elif [ $RET -eq 0 ]; then
            case "$FUN" in
              1\ *) do_wpasupplicant_menu ;;
              2\ *) do_hostname ;;
              3\ *) do_setup_keyboard ;;
              4\ *) do_change_timezone ;;
              5\ *) do_access_menu ;;
              6\ *) do_compose_app ;;
              7\ *) do_wavemon ;;
              8\ *) do_reboot ;;
              9\ *) do_poweroff ;;
              *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
            esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
          fi
        done
      else
        FUN=$(whiptail --title "Jabil Pi Configuration Tool (jabilpi-config)" --backtitle "$(tr -d '\0' </proc/device-tree/model)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
        "1 Wireless" "     Configure wireless settings" \
        "2 WaveMon" "     Wifi Monitor" \
        "3 Reboot" "     Restart Pi OS" \
        "4 Shutdown" "     Power Off Pi" \
        3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 0 ]; then
          case "$FUN" in
            1\ *) do_wpasupplicant_menu ;;
            2\ *) do_wavemon ;;
            3\ *) do_reboot ;;
            4\ *) do_poweroff ;;
            *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
          esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
        fi

        rm -f /root/jabilpi-config > /dev/null
      fi
    done
  else
    rm -f /root/jabilpi-config > /dev/null
    chvt 10
    exit 1
  fi
fi
