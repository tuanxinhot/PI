#!/bin/sh
#version=1.0.5

WORK_DIR='/root/jpiadmapi/'
PACK_NAME1='libsqlite3.deb'
PACK_NAME2='sqlite3.deb'
BIN_NAME1='sqlite3_armv6.gz'
clearDownloadedPackages() {
  if [ -f $WORK_DIR$PACK_NAME1 ]; then
    rm -f $WORK_DIR$PACK_NAME1
  fi

  if [ -f $WORK_DIR$PACK_NAME2 ]; then
    rm -f $WORK_DIR$PACK_NAME2
  fi

  if [ -f $WORK_DIR$BIN_NAME1 ]; then
    rm -f $WORK_DIR$BIN_NAME1
  fi
}
# Clear any existing packages
clearDownloadedPackages

sqlite3Armv6BinPatching() {
  # Special handling for armv6 (Pi Zero)
  if [ "$(uname -m)" = "armv6l" ]; then
    echo "Detected armv6l architecture."

    # Download sqlite3_armv6.gz
    wget -q --no-check-certificate $PACK_ADD$BIN_NAME1 -O $WORK_DIR$BIN_NAME1
    if [ ! $? -eq 0 ]; then echo "Failed to download file from $PACK_ADD$BIN_NAME1."; exit 1; fi

    # Create backup for default sqlite3 binary file
    if [ -f /usr/bin/sqlite3 ]; then
      yes | cp /usr/bin/sqlite3 /usr/bin/sqlite3_backup
      echo "Created backup for default /usr/bin/sqlite3 binary file."
    fi

    # Overwrite the sqlite3 binary file with armv6 binary file
    if [ -f /usr/bin/sqlite3 ]; then
      gunzip -c $WORK_DIR$BIN_NAME1 > /usr/bin/sqlite3
      if [ ! $? -eq 0 ]; then echo "Failed to overwrite sqlite3 binary file with armv6 binary file."; exit 1; fi
      echo "Successfully overwrite sqlite3 binary file with armv6 binary file."
    fi
  fi
}

setUrlPath() {
  if [ "$OS_VERSION" = "b28686c2-213e-11ea-b32c-0242ac110002" ] || \
     [ "$OS_VERSION" = "2457a1f0-5c8f-11eb-8c05-0242ac110002" ] || \
     [ "$OS_VERSION" = "b5f97c94-af0b-11ec-974d-0242ac110002" ]; then
    PACK_ADD='https://pi-update.docker.corp.jabil.org/jabil/sqlite3/buster/'
  fi

  if [ "$OS_VERSION" = "3cd4baaa-5e7b-11ea-abe8-0242ac110002" ]; then
    PACK_ADD='https://pi-update.docker.corp.jabil.org/jabil/sqlite3/stretch/'
  fi
}

OS_VERSION="`blkid | grep '/dev/mmcblk0p2' | awk '{ print $3 }' | tr -d '\"' | cut -c6-`"

if [ ! -z "$(dpkg-query -W | awk '{ print $1 }' | grep -oE '\<sqlite3')" ]; then
  echo "CLI package for sqlite already installed."
  setUrlPath
  sqlite3Armv6BinPatching
  clearDownloadedPackages
else
  if [ "$OS_VERSION" = "b28686c2-213e-11ea-b32c-0242ac110002" ] || \
     [ "$OS_VERSION" = "3cd4baaa-5e7b-11ea-abe8-0242ac110002" ] || \
     [ "$OS_VERSION" = "2457a1f0-5c8f-11eb-8c05-0242ac110002" ] || \
     [ "$OS_VERSION" = "b5f97c94-af0b-11ec-974d-0242ac110002" ]; then
    echo "OS version is $OS_VERSION."

    setUrlPath

    # Download libsqlite3.deb
    wget -q --no-check-certificate $PACK_ADD$PACK_NAME1 -O $WORK_DIR$PACK_NAME1
    if [ ! $? -eq 0 ]; then echo "Failed to download file from $PACK_ADD$PACK_NAME1."; exit 1; fi

    # Download sqlite3.deb
    wget -q --no-check-certificate $PACK_ADD$PACK_NAME2 -O $WORK_DIR$PACK_NAME2
    if [ ! $? -eq 0 ]; then echo "Failed to download file from $PACK_ADD$PACK_NAME2."; exit 1; fi

    # Install libsqlite3.deb
    dpkg -i $WORK_DIR$PACK_NAME1
    if [ ! $? -eq 0 ]; then echo "Failed to install $WORK_DIR$PACK_NAME1."; exit 1; fi

    # Install sqlite3.deb
    dpkg -i $WORK_DIR$PACK_NAME2
    if [ ! $? -eq 0 ]; then echo "Failed to install $WORK_DIR$PACK_NAME2."; exit 1; fi

    sqlite3Armv6BinPatching

    # Clear any existing packages after installation
    clearDownloadedPackages
  else
    echo "Unknown OS version $OS_VERSION. Skip installation."
    exit 1
  fi
fi

touch /storage/var/jpiadmapi/sqlite3-install-success
