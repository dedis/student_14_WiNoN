#!/bin/bash
ARCH=amd64
#ARCH=i386
VERSION=trusty
VERSION=trusty
TVERSION=saucy
BASE=trusty-64
BASEDIR=$PWD
INSTPATH=$BASEDIR/$BASE
BUILDERPATH=$BASEDIR//"$BASE"-build
URL=http://mirror.anl.gov/pub/ubuntu/
IMAGE=$BASEDIR/"$BASE".img
SIZE=2048
WINON=$(readlink -f ../../../..)
MOUNT=mount
#URL=http://archive.ubuntu.com/ubuntu

if [[ $(id -u) -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

function chroot_do
{
  mount --bind /dev $1/dev
  mount -t proc none $1/proc
  mount -t sysfs none $1/sys

  cp internal.sh $1/.
  chroot $1 /bin/bash internal.sh $2

  umount $1/proc
  umount -l $1/dev
  umount $1/sys

  rm $1/internal.sh
  rm $1/var/lib/apt/lists/*$VERSION* $1/var/lib/apt/lists/*$TVERSION* 2> /dev/null
  rm $1/var/lib/dpkg/*old 2> /dev/null
}

function base_setup
{
  debootstrap --arch $ARCH $VERSION $INSTPATH $URL
  echo "deb $URL $VERSION universe multiverse" >> $INSTPATH/etc/apt/sources.list
  echo "deb $URL $VERSION-updates main universe multiverse" >> $INSTPATH/etc/apt/sources.list
  echo "deb http://deb.torproject.org/torproject.org $TVERSION main" >> $INSTPATH/etc/apt/sources.list

  echo "nameserver 8.8.8.8" > $INSTPATH/etc/resolv.conf
  echo "auto lo" > $INSTPATH/etc/network/interfaces.d/lo.cfg
  echo "iface lo inet loopback" >> $INSTPATH/etc/network/interfaces.d/lo.cfg
  echo "auto eth0" > $INSTPATH/etc/network/interfaces.d/eth0.cfg
  echo "iface eth0 inet dhcp" >> $INSTPATH/etc/network/interfaces.d/eth0.cfg

  grep -v "^exit 0" $INSTPATH/etc/rc.local > $INSTPATH/etc/rc.local.new
  echo "sudo -i -b -u winon 'startx' &> /var/log/startx.log" >> $INSTPATH/etc/rc.local.new
  echo "exit 0" >> $INSTPATH/etc/rc.local.new
  mv $INSTPATH/etc/rc.local.new $INSTPATH/etc/rc.local
  chmod 755 $INSTPATH/etc/rc.local

  grep -v "%sudo" $INSTPATH/etc/sudoers > $INSTPATH/etc/sudoers.new
  echo "%sudo ALL=(ALL) NOPASSWD: ALL" >> $INSTPATH/etc/sudoers.new
  mv $INSTPATH/etc/sudoers.new $INSTPATH/etc/sudoers
  chmod 440 $INSTPATH/etc/sudoers

  echo "winon" > $INSTPATH/etc/hostname
  echo "127.0.0.1 winon" >> $INSTPATH/etc/hosts
  echo "::1 winon" >> $INSTPATH/etc/hosts

  tmpdir=/tmp/$RANDOM
  git clone $WINON $tmpdir
  cp -axf $tmpdir/* $INSTPATH/.
  rm -rf $tmpdir
  mkdir -p $INSTPATH/home/winon/.winon/pids

  chroot_do $INSTPATH base_setup

  sed 's/allowed_users=console/allowed_users=anybody/' -i $INSTPATH/etc/X11/Xwrapper.config

  rm $INSTPATH/var/lib/tor/* 2> /dev/null
}

function builder_setup
{
  cp -axf $INSTPATH $BUILDERPATH
  mkdir $BUILDERPATH/home/src
  git clone git://github.com/darkk/redsocks.git $BUILDERPATH/home/src/redsocks
  git clone http://git.kiszka.org/kvm-kmod.git $BUILDERPATH/home/src/kvm-kmod
  cd $BUILDERPATH/home/src/kvm-kmod
  git submodule init
  cd -

  chroot_do $BUILDERPATH builder_setup
}

function image
{
  dd if=/dev/zero of=$IMAGE bs=1 count=1 seek="$SIZE"M
  parted $IMAGE mklabel msdos
  parted $IMAGE mkpart primary 2048s 100%

  loop=$(losetup --find)
  losetup -o1048576 $loop $IMAGE
  mkfs.ext2 -L winon -m0 $loop
  losetup -d $loop

  delete=
  if [[ ! -e mount ]]; then
    delete=y
    mkdir mount
  fi

  mount -oloop,offset=1048576 $IMAGE $MOUNT
  cp -axf $INSTPATH/* $MOUNT/.
  umount $MOUNT

  mv $IMAGE $BUILDERPATH/image.img
  chroot_do $BUILDERPATH image_build
  mv $BUILDERPATH/image.img $IMAGE

  if [[ "$delete" ]]; then
    rmdir mount
  fi
}

function update
{

  tmpdir=/tmp/$RANDOM
  git clone $WINON $tmpdir
  cp -axf $tmpdir/* $INSTPATH/.
  cp -axf $tmpdir/* $BUILDERPATH/.
  rm -rf $tmpdir

  chroot_do $INSTPATH update
  chroot_do $BUILDERPATH update
}

base_setup
builder_setup
update
image
