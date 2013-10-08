#!/bin/bash
if [[ ! "$1" || ! "$2" || ! -d "$1" || -e "$2" ]]; then
  echo "Usage: /path/to/disk_builder.sh /path/to/files /path/to/image"
  if [[ ! -d "$1" ]]; then
    echo "No such directory"
  elif [[ -e "$2" ]]; then
    echo "Image must not already exist, delete first"
  fi
  exit 1
fi

if [[ $(id -u) -ne 0 ]]; then
  echo "Must be root to use"
  exit 1
fi

FILES=$1
DST_IMG=$2

# Get an upper bound on expected image size
SIZE=$(du -cs -BM $FILES | grep total | grep -oE [0-9]+)

dd if=/dev/null of=$DST_IMG bs=$((SIZE + 2))M count=1 seek=1
parted $DST_IMG mklabel msdos
parted -- $DST_IMG mkpart primary 1 -0

LOOP=$(losetup -f)
losetup -o1048576 $LOOP $DST_IMG
mkfs.ext2 -m0 $LOOP
e2label $LOOP opt
losetup -d $LOOP

mount -oloop,offset=1048576 $DST_IMG /mnt
cp -axf $FILES/* /mnt/.
umount /mnt
