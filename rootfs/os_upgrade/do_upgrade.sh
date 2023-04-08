#!/bin/bash
trap processHUP SIGHUP

processHUP() {
  echo "Received SIGHUP, Ignoring"
}

REBOOT_NEEDED="no"

DEVICE_PART_2=$(findmnt / -o source -n)
DEVICE_PART_2_NAME=$(echo "$DEVICE_PART_2" | cut -d "/" -f 3)
DEVICE_NAME=$(echo /sys/block/*/"${DEVICE_PART_2_NAME}" | cut -d "/" -f 4)
DEVICE_PART_3_NAME=$(ls /sys/block/"${DEVICE_NAME}" | grep ${DEVICE_PART_2_NAME::-1}3$)
DEVICE_PART_3="/dev/${DEVICE_PART_3_NAME}"

PART2_ID="`dumpe2fs -h "$DEVICE_PART_2" 2>&1 | grep 'Filesystem UUID' | cut -d: -f 2 | tr -d ' '`"
PART3_ID="`dumpe2fs -h "$DEVICE_PART_3" 2>&1 | grep 'Filesystem UUID' | cut -d: -f 2 | tr -d ' '`"
mkdir -p /os_backup/boot/overlays

if [ "$PART3_ID" != "" ]; then
  if [ -d /storage/$PART3_ID/os_backup/boot ]; then
    cp -R /storage/$PART3_ID/os_backup/boot /os_backup/
  else
    cp /boot/kernel*.img /os_backup/boot/
    cp /boot/*.elf /os_backup/boot/
    cp /boot/*.dat /os_backup/boot/
    cp /boot/*.dtb /os_backup/boot/
    cp /boot/bootcode.bin /os_backup/boot/
    cp /boot/overlays/* /os_backup/boot/overlays/
  fi
  sync
fi

if [ -d "/lib/modules/`uname -r`/" ]; then
  echo "Kernel modules are in sync.";
else
  echo "Modules for this kernel are not available, upgrading"
  cp -R /os_upgrade/boot/* /boot/
  #TODO: Check status, make sure it worked, or hang...
  sync
  REBOOT_NEEDED="yes"
fi

if [ "$PART3_ID" != "" ]; then
  PI_STORAGE="`ls -la /storage | awk NR==2'{print $1}'`"

  if [ "$PI_STORAGE" != "drwxrwsr-x+" ]; then
    #New files and new folder under /storage will inherit the root:pistorage ownership
    /bin/chmod g+s /storage
    /bin/chmod 775 /storage
    /bin/chown root:8888 /storage
  fi

  PI_STORAGE=$(getfacl /storage 2> /dev/null | grep "default:group:pi:rwx")

  if [ "$PI_STORAGE" == "" ]; then
    #Set base /storage ACL and subsequent ACL which created files and folders under /storage:
    #  - group ownership: 
    #     - pi group (gid: 1000) 
    #     - pistorage group (gid: 8888) 
    #  - group permission: 
    #     - rwx (gid: 1000, 8888)
    #Subsequent:
    /usr/bin/setfacl -d -m g::rwx,g:pi:rwx /storage
    #Base:
    /usr/bin/setfacl -m g::rwx,g:pi:rwx /storage
  fi

  if [ ! -f /boot/jpiadmapi/user.conf ]; then
    mkdir -p /boot/jpiadmapi
    touch /boot/jpiadmapi/user.conf
    touch /boot/jpiadmapi/group.conf
  fi

  if [ -f /boot/cmdline.txt ]; then
    CGROUP1=$(cat /boot/cmdline.txt | grep "systemd.unified_cgroup_hierarchy=")
    CGROUP2=$(cat /boot/cmdline.txt | grep "cgroup_enable=")
    CGROUP3=$(cat /boot/cmdline.txt | grep "cgroup_memory=")
    CMDLINE_TXT=$(cat /boot/cmdline.txt)

    if [ "$CGROUP1" == "" ]; then
      CMDLINE_TXT=$(echo $CMDLINE_TXT | sed 's|rootwait|systemd.unified_cgroup_hierarchy=0 rootwait|')
    else
      CMDLINE_TXT=$(echo $CMDLINE_TXT | sed 's| systemd.unified_cgroup_hierarchy=[^ ]* | systemd.unified_cgroup_hierarchy=0 |')
    fi

    if [ "$CGROUP2" == "" ]; then
      CMDLINE_TXT=$(echo $CMDLINE_TXT | sed 's|rootwait|cgroup_enable=memory rootwait|')
    else
      CMDLINE_TXT=$(echo $CMDLINE_TXT | sed 's| cgroup_enable=[^ ]* | cgroup_enable=memory |')
    fi

    if [ "$CGROUP3" == "" ]; then
      CMDLINE_TXT=$(echo $CMDLINE_TXT | sed 's|rootwait|cgroup_memory=1 rootwait|')
    else
      CMDLINE_TXT=$(echo $CMDLINE_TXT | sed 's| cgroup_memory=[^ ]* | cgroup_memory=1 |')
    fi

    echo "$CMDLINE_TXT" > /boot/cmdline.txt
  fi

  if [ -f /boot/compose.yml ]; then
    PICO=$(cat /boot/compose.yml | grep "image:" | grep "docker.corp.jabil.org/pico/pfc")

    if [ "$PICO" != "" ]; then
      if [ -f /os_upgrade/pico/overlays/sc16is762-spi.dtbo ]; then
        rm -f /boot/overlays/sc16is762-spi.dtbo
        cp /os_upgrade/pico/overlays/sc16is762-spi.dtbo /boot/overlays/
      fi
    fi
  fi

  #Fixups
  #For upgrade from old os
  #WPA Supplicant moved the file from /boot/wpa_supplicant.conf to replace the symlink in /etc/wpa_supplicant/.
  #Go check to see if it's there as a regular file, and if so, steal it back...
  mkdir /old_os/
  mount -o ro $DEVICE_PART_3 /old_os/

  if [ -f "/old_os/etc/wpa_supplicant/wpa_supplicant.conf" ]; then
    #file exists, is it still a symlink?
    if [ -h "/old_os/etc/wpa_supplicant/wpa_supplicant.conf" ]; then
      #yes, do nothing
      echo "No wpa_supplicant fix needed."
    else
      #Put the wpa_supplicant file where we expect it to be now.
      echo "Fixing misplaced wpa_supplicant.conf"
      mv /old_os/etc/wpa_supplicant/wpa_supplicant.conf /boot/wpa_supplicant.conf
      REBOOT_NEEDED="yes"
    fi
  fi

  if [ -f "/old_os/etc/default/keyboard" ]; then
    if [ -h "/old_os/etc/default/keyboard" ]; then
      echo "No keyboard fix needed."
    else
      echo "Fixing misplaced keyboard"
      mv /old_os/etc/default/keyboard /boot/keyboard
      REBOOT_NEEDED="yes"
    fi
  fi

  if [ -f "/old_os/etc/dhcpcd.conf" ]; then
    if [ -h "/old_os/etc/dhcpcd.conf" ]; then
      echo "No dhcpcd.conf fix needed."
    else
      echo "Fixing misplaced dhcpcd.conf"
      mv /old_os/etc/dhcpcd.conf /boot/dhcpcd.conf
      REBOOT_NEEDED="yes"
    fi
  fi

  if [ -f "/old_os/etc/network/interfaces" ]; then
    if [ -h "/old_os/etc/network/interfaces" ]; then
      echo "No interfaces fix needed."
    else
      echo "Fixing misplaced interfaces"
      mv /old_os/etc/network/interfaces /boot/interfaces
      REBOOT_NEEDED="yes"
    fi
  fi

  if [ -f "/old_os/etc/hostname" ]; then
    if [ -h "/old_os/etc/hostname" ]; then
      echo "No hostname fix needed."
    else
      echo "Fixing misplaced hostname"
      mv /old_os/etc/hostname /boot/hostname
      REBOOT_NEEDED="yes"
    fi
  fi

  if [ -f "/old_os/etc/timezone" ]; then
    if [ -h "/old_os/etc/timezone" ]; then
      echo "No timezone fix needed."
    else
      echo "Fixing misplaced timezone"
      mv /old_os/etc/timezone /boot/timezone
      REBOOT_NEEDED="yes"
    fi
  fi

  if [ -f "/old_os/etc/modules" ]; then
    if [ -h "/old_os/etc/modules" ]; then
      echo "No modules fix needed."
    else
      echo "Fixing misplaced modules"
      mv /old_os/etc/modules /boot/modules
      REBOOT_NEEDED="yes"
    fi
  fi

  if [ ! -d "/storage/$PART2_ID/var/log" ]; then
    echo "Create system log path at /storage partition."
    mkdir -p /storage/$PART2_ID/var/log
    REBOOT_NEEDED="yes"
  fi

  umount /old_os

  # disable full jabilpi-config menu if os upgrade
  rm -f /root/jabilpi-config

  # update the daemon.json for log rotate
  echo -e "{\n  \""bip"\": \""172.16.0.1/24"\",\n  \""log-driver"\": \""json-file"\",\n  \""log-opts"\": {\n      \""max-size"\": \""20m"\",\n      \""max-file"\": \""10"\"\n  }\n}" > /etc/docker/daemon.json

  # Remove the os-upgrade service after one-time migration.
  rm -f /lib/systemd/system/multi-user.target.wants/os-upgrade.service

  # drivers script installation
  /scripts/drivers_install.sh
else
  # Remove the os-upgrade service after one-time migration.
  rm -f /lib/systemd/system/multi-user.target.wants/os-upgrade.service
fi

if [ "$REBOOT_NEEDED" = "yes" ]; then
   echo "Rebooting..."
   init 6
fi