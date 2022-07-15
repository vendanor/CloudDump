#!/bin/sh

distro="${1}"
if [ "${distro}" = "" ]; then
  distro="ubuntu"
fi

sudo docker-compose up ${2} vnclouddump-${distro}
