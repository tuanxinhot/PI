#!/bin/bash
#version=1.1.0

case "$1" in
  "full")
    echo "Stopping Docker services and repairing Docker..." > /dev/tty7
    systemctl stop jpi-admin-api
    systemctl stop docker-compose
    docker-compose -f /boot/compose.yml down
    docker-compose -f /root/jpiadmapi/docker-compose.yml down
    docker system prune --volumes --all --force
    systemctl stop docker
    ;;
  "docker_down")
    echo "Docker service is failed/unavailable, repairing Docker..." > /dev/tty7
    systemctl stop jpi-admin-api
    systemctl stop docker-compose
    ;;
  *)
    ;;
esac

rm -rf /storage/var/lib/docker/overlay2/*
rm -rf /storage/var/lib/docker/image/overlay2/distribution/diffid-by-digest/sha256/*
rm -rf /storage/var/lib/docker/image/overlay2/distribution/v2metadata-by-diffid/sha256/*
rm -rf /storage/var/lib/docker/image/overlay2/imagedb/content/sha256/*
rm -rf /storage/var/lib/docker/image/overlay2/layerdb/sha256/*
rm -rf /storage/var/lib/docker/image/overlay2/layerdb/tmp/*
rm -rf /storage/var/lib/docker/image/overlay2/layerdb/mounts/*
rm -rf /storage/var/lib/docker/containers/*
echo "{\"Repositories\":{}}" > /storage/var/lib/docker/image/overlay2/repositories.json

systemctl restart docker
systemctl restart jpi-admin-api
systemctl restart docker-compose