#!/bin/sh
#version=1.0.0

# Check if Azure load balancer for DTR is online
nc -w 5 -z 10.175.238.7 443
EXITCODE=$?
if [ $EXITCODE -eq 0 ]; then
  # Pull latest image if able to contact DTR server
  /usr/local/bin/docker-compose -f /root/rss/docker-compose.yml pull --no-parallel
else
  echo "Not able to contact DTR server. Check if local image exists..."
  RES=$(docker image ls --format '{{ json . }}' docker.corp.jabil.org/raspberry-pi/rss:latest)
  if [ -z "$RES" ]; then
    echo "RSS local image not found, please connect to Jabil network"
    exit 1
  else
    echo "RSS local image found. Proceed to run as usual."
    exit 0
  fi
fi
