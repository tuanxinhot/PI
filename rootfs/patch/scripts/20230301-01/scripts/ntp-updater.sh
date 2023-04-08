#!/bin/bash
#version=1.1.0

DNS_SERVERS=`resolvconf -l | grep "nameserver" | awk '{print $2 }' | tr '\n' '|' | sed 's/|/ /g'`
DEFAULT_SERVERS="0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org"

echo "[Time]" > /etc/systemd/timesyncd.conf

if [ "$DNS_SERVERS" == "" ]; then
  echo "NTP=$DEFAULT_SERVERS" >> /etc/systemd/timesyncd.conf
else
  echo "NTP=${DNS_SERVERS::-1} $DEFAULT_SERVERS" >> /etc/systemd/timesyncd.conf
fi

systemctl restart systemd-timesyncd


#!/bin/bash
# SERVERS=`resolvconf -l | grep "nameserver" | awk '{print $2 }' | tr '\n' '|' | sed 's/|/ /g'`

# if [ "$SERVERS" != "" ]; then
#   SERVERSARR=($SERVERS)
#   NTPSERVERS=""

#   for SERVER in "${SERVERSARR[@]}"; do
#     if nc -zuv $SERVER 123; then
#       if [ "$NTPSERVERS" == "" ]; then
#         NTPSERVERS="$SERVER"
#       else
#         NTPSERVERS="$NTPSERVERS $SERVER"
#       fi
#     fi
#   done

#   echo "[Time]" > /etc/systemd/timesyncd.conf
#   if [ "$NTPSERVERS" != "" ]; then
#     echo "NTP=${SERVERS::-1}" >> /etc/systemd/timesyncd.conf
#   fi

#   systemctl daemon-reload
#   systemctl restart systemd-timesyncd
# fi