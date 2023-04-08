#!/bin/sh
#version=2.0.0

if [ ! -f /boot/jpiadmapi/disableautorestart ]; then
  echo "Checking number of session..."
  RES=$(curl -si -m 3 http://127.0.0.1:3000/api/v1.0/auth/session)
  STATUS_CODE=$(echo "$RES" | grep -oE 'HTTP.{1,}[[:digit:]]{3}' | grep -oE '[[:digit:]]{3}')
  SESSION_COUNT=$(echo "$RES" | grep session_count | grep -oE '[[:digit:]]{1,}')

  if [ ! -z "$STATUS_CODE" ] && [ $STATUS_CODE -eq 200 ]; then
    if [ $SESSION_COUNT -eq 0 ]; then
      echo "Number of session is $SESSION_COUNT. Proceed to restart system container after 10 seconds."
      sleep 10s
    else
      echo "Number of session is $SESSION_COUNT. Waiting for session empty."
      exit 1
    fi
  else
    echo "Failed to get number of session. Status code is $STATUS_CODE."
    exit 1
  fi

  echo "Restarting system container service..."
  systemctl restart jpi-admin-api.service

  JPIADMAPI_SERVICE=$(systemctl -l -a --no-pager | grep jpi-admin-api.service)
  if [ -z "$JPIADMAPI_SERVICE" ]; then
    echo "System container service not found. Exiting..."
    exit 1
  fi

  JPIADMAPI_STATUS=$(echo "$JPIADMAPI_SERVICE" | awk '{ print $4 }')
  echo "System container service status is $JPIADMAPI_STATUS."
else
  echo "System container auto restart service is disabled."
fi
