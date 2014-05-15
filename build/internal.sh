#!/bin/bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin

function base_setup
{
  mv /sbin/initctl /sbin/initctl.bak
  ln -s /bin/true /sbin/initctl
  # Update, upgrade, and install base packages
  apt-get update
  apt-get dist-upgrade -y --force-yes --no-install-recommends
  apt-get install -y --force-yes --no-install-recommends \
    alsa-utils \
    chromium-browser \
    flashplugin-installer \
    iptables \
    jwm \
    linux-image-generic \
    parted \
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
  ln -s /usr/bin/vi /usr/bin/vim
  # Create user account
  useradd -b /home/ -G sudo,audio,video,users,kvm,netdev -m -s /bin/bash -U winon
  echo "winon:password" | chpasswd
  # Setup locale and timezone
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
  echo "export LANG=C" >> /root/.bashrc
  echo "export LANG=C" >> /home/winon/.bashrc
  # Cleanup
  service tor stop
  update-rc.d tor disable
  echo 'manual' > /etc/init/tor.override

  if [[ -e /winon.deb ]]; then
    dpkg --install winon.deb
  fi

  apt-get clean -y --force-yes
  apt-get autoremove -y --force-yes

  mv /sbin/initctl.bak /sbin/initctl
  chown -R winon:winon /home/winon
}

function builder_setup
{
  mv /sbin/initctl /sbin/initctl.bak
  ln -s /bin/true /sbin/initctl
  # Update, upgrade, and install base packages
  apt-get update
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

  # Install buildable packages
  mkdir $BUILDERPATH/home/src
  git clone git://github.com/darkk/redsocks.git $BUILDERPATH/home/src/redsocks
  git clone http://git.kiszka.org/kvm-kmod.git $BUILDERPATH/home/src/kvm-kmod
  cd $BUILDERPATH/home/src/kvm-kmod
  git submodule init
  cd -

  # Cleanup
  service tor stop
  update-rc.d tor disable
  echo 'manual' > /etc/init/tor.override
  apt-get clean -y --force-yes
  apt-get autoremove -y --force-yes
}

function build_packages
{
  if [[ -d /home/src/kvm-kmod ]]; then
    cd /home/src/kvm-kmod
    git pull
    git submodule update

    kernel=/lib/modules/$(uname -r)
    if [[ ! -d $kernel ]]; then
      kernel=/lib/modules/$(echo $(ls /lib/modules) | awk '{print $1}')
    fi
    arch=i386
    grep "# CONFIG_64BIT is not set" $kernel/build/.config &> /dev/null
    if [[ $? -ne 0 ]]; then
      arch=x86_64
    fi

    ./configure --arch=$arch --kerneldir=$kernel/build
    make sync
    make
  fi

  if [[ -d /home/src/redsocks ]]; then
    cd /home/src/redsocks
    git pull
    make
  fi
}

function image_build
{
  mount -oloop,offset=1048576 image.img /mnt
  mkdir -p /mnt/boot/grub
  cp /usr/lib/grub/*/stage1 /mnt/boot/grub/.
  cp /usr/lib/grub/*/e2fs_stage1_5 /mnt/boot/grub/.
  cp /usr/lib/grub/*/stage2 /mnt/boot/grub/.

  build_packages
  cp /home/src/kvm-kmod/x86/*ko /mnt/$kernel/kernel/arch/x86/kvm/.
  cp /home/src/redsocks/redsocks /mnt/opt/winon/bin/.
  chown winon:winon /mnt/opt/winon/bin/redsocks

  umount /mnt

  cd /
  echo "device (hd0) image.img
    root (hd0,0)
    setup (hd0)
    quit" | grub --batch --device-map=/dev/null
}

function update
{
  mv /sbin/initctl /sbin/initctl.bak
  ln -s /bin/true /sbin/initctl
  # Update, upgrade, and install base packages
  apt-get update
  apt-get dist-upgrade -y --force-yes --no-install-recommends
  update-initramfs -u
  # Cleanup
  service tor stop
  update-rc.d tor disable
  echo 'manual' > /etc/init/tor.override

  if [[ -e /winon.deb ]]; then
    dpkg --install winon.deb
  fi

  apt-get clean -y --force-yes
  apt-get autoremove -y --force-yes

  mv /sbin/initctl.bak /sbin/initctl
  chown -R winon:winon /home/winon
}

$1
