#!/bin/bash

if [[ $(id -u) -ne 0 ]]; then
  sudo bash $0
  if [[ $? -ne 0 ]]; then
    echo "Unable to start service, need root privileges"
    exit 1
  fi
  exit 0
fi

WHOME=/home/winon
USER_PATH=$WHOME/.winon/default/user
NET_PATH=$WHOME/.winon/default/comm
COMM_CHECK=$WHOME/.winon/check.sh

# DeterLab hack
# DETERLAB=TRUE

function reset_network
{
  iptables -t nat -F &> /dev/null
  iptables -t raw -F &> /dev/null

  tunctl -d user-net &> /dev/null
  tunctl -d comm-net &> /dev/null
}

function gen_mac_addr
{
  MACADDR=$(printf 'DE:AD:BE:EF:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)))
}

function set_ip
{
  if [[ "$DETERLAB" ]]; then
    ifconfig eth0 10.0.0.7 netmask 255.255.255.0
    route add -net 0.0.0.0 gw 10.0.0.254
  fi

  # Wait for IP Address
  ADDR=
  while [[ ! "$ADDR" ]]; do
    IF=eth0
    ADDR=$(ip -f inet addr show dev eth0 2> /dev/null | \
      grep -oE "inet [0-9]+.[0-9]+.[0-9]+.[0-9]+" | \
      grep -oE "[0-9]+.[0-9]+.[0-9]+.[0-9]+" 2> /dev/null)
    if [[ $? -ne 0 ]]; then
      IF=wlan0
      ADDR=$(ip -f inet addr show dev wlan0 2> /dev/null | \
        grep -oE "inet [0-9]+.[0-9]+.[0-9]+.[0-9]+" | \
        grep -oE "[0-9]+.[0-9]+.[0-9]+.[0-9]+" 2> /dev/null)
      if [[ $? -ne 0 ]]; then
        if [[ ! "$once" ]]; then
          echo "Starting WICD, connect to a network, "\
            "and progress will continue automatically"
          su winon -c /usr/bin/wicd-gtk &> /dev/null &
          once=1
        fi
        sleep 1
      fi
    fi
  done

  MASK=$(ip -f inet addr show dev $IF | \
    grep -oE "inet [0-9\./]*" | \
    grep -oE "[0-9]+$")
}

function set_time
{
  if [[ ! "$DETERLAB" ]]; then
    ntpdate pool.ntp.org &> /dev/null
    while [[ $? -eq 1 ]]; do
      sleep 1
      result=$(ntpdate pool.ntp.org 2>&1)
      if [[ $? -eq 1 ]]; then
        echo $result | grep "no server suitable" &> /dev/null
      fi
    done
  fi
}

function find_drive
{
  DRIVE=/dev/$(ls -al /dev/disk/by-label/winon | grep -oE "../../.+" | grep -oE [a-zA-Z]+)
}

function setup_user_network
{
  tunctl -t user-net -u winon &> /dev/null
  tunctl -t comm-user-net -u winon &> /dev/null

  brctl addbr user-br
  brctl addif user-br user-net
  brctl addif user-br comm-user-net

  ifconfig user-net 0.0.0.0
  ifconfig comm-user-net 0.0.0.0
  ifconfig user-br 5.1.0.3

  # Block all packets that are not destined for the communication tool
  iptables -t filter -A INPUT -i user-net -s 5.1.0.2 -d 5.1.0.1 -j ACCEPT
  iptables -t filter -A INPUT -i user-net -s 5.1.0.2 -d 5.0.0.0/8 -j DROP
  # Block all packets to and from the communication VM to the local network
  iptables -t filter -A INPUT -i comm-net -d $ADDR/$MASK -j DROP
  iptables -t filter -A INPUT -i comm-net -s $ADDR/$MASK -j DROP
}

function setup_comm_network
{
  tunctl -t comm-net -u winon &> /dev/null
  ifconfig comm-net 5.0.0.1 netmask 255.255.255.0

  # http://www.ibiblio.org/pub/linux/docs/howto/other-formats/html_single/Masquerading-Simple-HOWTO.html
  iptables -t nat -A POSTROUTING -o $IF -j MASQUERADE
  echo 1 > /proc/sys/net/ipv4/ip_forward
  iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  iptables -A INPUT -m state --state NEW ! -i $IF -j ACCEPT
  iptables -P INPUT DROP
  iptables -A FORWARD -i $IF -o $IF -j REJECT
}

function start_comm_vm
{
  mem=$(( $(free -m | grep Mem | awk '{print $2}') / 4 ))
  if [[ $mem -le 128 ]]; then
    echo "Insufficient RAM for CommVM"
    exit 1
  elif [[ $mem -gt 2047 ]]; then
    # For 32-bit hosts, which is our current target
    mem=2047
  fi

  $WHOME/.winon/disk_builder.sh $NET_PATH $WHOME/.winon/comm.img >> /tmp/commvm 2>&1 
  gen_mac_addr
  mac_addr1=$MACADDR
  gen_mac_addr
  mac_addr2=$MACADDR

  kvm \
    -net nic,model=virtio,macaddr=$mac_addr1 -net tap,ifname=comm-net,script=,downscript= \
    -net nic,model=virtio,macaddr=$mac_addr2 -net tap,ifname=comm-user-net,script=,downscript= \
    -m $mem \
    -vga std \
    -drive file=$DRIVE,if=virtio \
    -drive file=$WHOME/.winon/comm.img,if=virtio \
    -boot order=c >> /tmp/commvm 2>&1 &
}

function start_user_vm
{
  mem=$(( $(free -m | grep Mem | awk '{print $2}') / 2 ))
  if [[ $mem -le 256 ]]; then
    echo "Insufficient RAM for UserVM"
    exit 1
  elif [[ $mem -gt 2047 ]]; then
    # For 32-bit hosts, which is our current target
    mem=2047
  fi

  $WHOME/.winon/disk_builder.sh $USER_PATH $WHOME/.winon/user.img >> /tmp/uservm 2>&1
  gen_mac_addr
  mac_addr=$MACADDR

  QEMU_AUDIO_DRV=alsa kvm \
    -net nic,model=virtio,macaddr=$mac_addr -net tap,ifname=user-net,script=,downscript= \
    -m $mem \
    -vga std \
    -drive file=$DRIVE,if=virtio \
    -drive file=$WHOME/.winon/user.img,if=virtio \
    -soundhw ac97 \
    -boot order=c >> /tmp/uservm 2>&1
}

function stop_vms
{
  pkill -KILL kvm
}

reset_network
set_ip
echo "Network configured, using: $ADDR"
echo "Starting communication network VM..."
setup_comm_network
setup_user_network
find_drive
start_comm_vm
echo "Done"
if [[ "$COMM_CHECK" ]]; then
  bash $COMM_CHECK
fi
echo "Starting the browser VM..."
start_user_vm
echo "Browsing VM shutdown, turning off services"

stop_vms
reset_network
