#!/bin/bash
# Used by the sani vm to automount drives

mkdir /home/winon/input

if [[ $(id -u) -ne 0 ]]; then
  sudo bash $0
  if [[ $? -ne 0 ]]; then
    echo "Unable to start service, need root privileges"
    exit 1
  fi
  exit 0
fi

# Add opt if we need to
winonlink=$(readlink /dev/disk/by-label/winon)
for drive in $(ls /dev/disk/by-uuid); do
  link=$(readlink /dev/disk/by-uuid/$drive)
  if [[ $link == $winonlink ]]; then
    continue;
  fi
  # Switch to label if possible
  drivename=$(echo $link | grep -oE "[a-zA-Z0-9]+")
  mkdir -p /media/$drivename
  mount -oro /dev/disk/by-uuid/$drive /media/$drivename
  if [[ $? -ne 0 ]]; then
    rmdir /media/$drivename
  fi
done

mount -t9p -o trans=virtio sani /home/winon/input
