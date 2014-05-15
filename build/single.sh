#!/bin/bash
WINON=https://github.com/DeDiS/WiNoN.git

apt-get update

apt-get install -y --force-yes --no-install-recommends \
  alsa-utils \
  chromium-browser \
  flashplugin-installer \
  iptables \
  jwm \
  python3 \
  qemu-kvm \
  tor \
  wget \
  wicd-gtk \
  wmctrl \
  xinit \
  xfe \
  xserver-xorg \
  xterm

apt-get install -y --force-yes --no-install-recommends \
  tightvncserver \
  xfonts-base

apt-get install -y --force-yes --no-install-recommends \
  autoconf \
  automake \
  binutils \
  g++ \
  gcc \
  git \
  grub \
  libevent-dev \
  linux-headers-generic \
  make \
  mawk

service tor stop
update-rc.d tor disable
echo 'manual' > /etc/init/tor.override

# Create user account
git clone $WINON /tmp/winon
cp -axf /tmp/winon/* /.
useradd -b /home/ -G sudo,audio,video,users,kvm,netdev -m -s /bin/bash -U winon
echo "winon:password" | chpasswd

# Setup new software
mkdir /home/src
git clone git://github.com/darkk/redsocks.git /home/src/redsocks
git clone http://git.kiszka.org/kvm-kmod.git /home/src/kvm-kmod

cd /home/src/kvm-kmod
# Support for Linux 3.2
git checkout 051222fd914cadadcdefe108f1ef30a84e720c84
git submodule init
cd -

bash internal.sh build_packages
kernel=/lib/modules/$(uname -r)
if [[ ! -d $kernel ]]; then
  kernel=/lib/modules/$(echo $(ls /lib/modules) | awk '{print $1}')
fi
cp /home/src/kvm-kmod/x86/*ko /$kernel/kernel/arch/x86/kvm/.
cp /home/src/redsocks/redsocks /home/winon/.winon/redsocks

# should remove binutils but cannot
apt-get remove -y --force-yes \
  autoconf \
  automake \
  g++ \
  gcc \
  git \
  grub \
  libevent-dev \
  linux-headers-generic \
  make \
  mawk

apt-get clean -y --force-yes
apt-get autoremove -y --force-yes
rm -rf /home/src
e2label /dev/sda1 winon
chown winon:winon -R /home/winon
