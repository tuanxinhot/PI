#!/bin/bash
#version=2.0.0

BRANCH="`cat /boot/updater/risk.txt|egrep -v '^#'`"

if [ "$BRANCH" == "test" ]; then
  SLEEP_TIME="5m"
else
  SLEEP_TIME="24h"
fi

while [ 1 ]; do
  /usr/lib/pi-updater/daily_updater.sh
  sleep "$SLEEP_TIME"
done