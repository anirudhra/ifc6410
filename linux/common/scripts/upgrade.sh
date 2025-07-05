#!/bin/bash

fullclean() {
  sudo apt clean
  sudo apt autoclean
  sudo apt autoremove
}

fullupdate() {
  sudo apt update -y
  sudo apt dist-upgrade -y

  #pve server only
  if [ -x "$(command -v pveversion)" ]; then
    if [ -x "$(command -v fwupdmgr)" ]; then
      sudo fwupdmgr refresh --force && sudo fwupdmgr get-updates && sudo fwupdmgr update
    fi
  fi
}

#intended to be run on PVE guests only
dockerupdateall() {
  if [ ! -x "$(command -v pveversion)" ]; then #ensure it's not the server
    if [ -x "$(command -v docker)" ]; then     #ensure docker is installed on the host
      cd /opt/dockerapps || exit
      #cd /mnt/pve-sata-ssd/ssd-data/dockerapps/${HOSTNAME} || exit
      find . -maxdepth 1 -type d \( ! -name . \) -not -path '*disabled*' -exec bash -c "cd '{}' && pwd && docker compose down && docker compose pull && docker compose up -d --remove-orphans" \;
      docker image prune -a -f
      docker system prune --volumes -f
    fi
  fi
}

#main
fullupdate
fullclean
dockerupdateall
