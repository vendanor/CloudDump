#!/bin/sh

distro="$1"
if [ "${distro}" = "" ]; then
  distro="ubuntu"
fi

sudo docker-compose build --no-cache vnclouddump-${distro}
