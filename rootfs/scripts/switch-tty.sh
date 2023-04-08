#!/bin/bash
#version=2.0.0

echo "[TTY7]" > /dev/tty7
echo "[TTY8]" > /dev/tty8
echo "[TTY9]" > /dev/tty9
echo "[TTY10]" > /dev/tty10
echo "[TTY11]" > /dev/tty11

if [ -f /root/first ]; then
  echo "Please wait while docker-compose is preparing for the first time..." > /dev/tty7
else
  echo "Please wait while docker-compose is preparing..." > /dev/tty7
fi

timedatectl set-timezone $(cat /boot/timezone)

if [ -d "/lib/modules/`uname -r`" ]; then
  if [ -f /boot/compose.yml ]; then
    /bin/chvt 7
  else
    /bin/chvt 10
  fi
fi