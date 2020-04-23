#!/usr/bin/env bash
set -e

echo "### Performing final cleanup tasks ###"
sudo service docker stop
sudo chkconfig docker off
sudo rm -rf /var/log/docker /var/log/ecs/*

sudo rm -Rf /var/run/docker.sock
sudo rm -rf /var/lib/docker/network

sudo ip link del docker0 || true
