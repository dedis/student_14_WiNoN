#!/bin/bash

source /etc/default/winon 2> /dev/null
if [[ $? -ne 0 ]]; then
  echo "Error reading /etc/default/winon"
  exit 1
fi

source $WPATH/common.sh 2> /dev/null
if [[ $? -ne 0 ]]; then
  echo "Error reading $WPATH/common.sh"
  exit 1
fi

if [[ ! -e $WPATH/started ]]; then
  echo "No interface file"
  exit 1
fi

IF=$(cat $WPATH/started)
if [[ ! "$IF" ]]; then
  echo "No interface defined"
  exit 1
fi

get_addr
if [[ ! "$ADDR" ]]; then
  echo "No IP Address for if: $IF"
  exit 1
fi

get_mask
if [[ ! "$MASK" ]]; then
  echo "No Netmask for if: $IF"
  exit 1
fi

function create_network
{
  # Build User to Comm
  tunctl -t user-net-$nym_id -u winon
  tunctl -t comm-user-net-$nym_id -u winon

  brctl addbr user-br-$nym_id
  brctl addif user-br-$nym_id user-net-$nym_id
  brctl addif user-br-$nym_id comm-user-net-$nym_id

  ifconfig user-net-$nym_id 0.0.0.0
  ifconfig comm-user-net-$nym_id 0.0.0.0
  ifconfig user-br-$nym_id 0.0.0.0

  tunctl -t comm-net-$nym_id -u winon
  ifconfig comm-net-$nym_id 5.0."$nym_id".1 netmask 255.255.255.0
#  iptables -t mangle -A PREROUTING -j CONNMARK -i comm-net-$nym_id -s 5.0.0.2 -d 5.0.0.$(($nym_id + 2)) --set-mark $(($nym_id + 1))
#  iptables -t nat -A PREROUTING -j DNAT -m connmark --mark $(($nym_id + 1)) --to-destination 5.0.0.1
#  iptables -t mangle -A OUTPUT -j CONNMARK -d 5.0.0.$(($nym_id + 2)) --set-mark $(($nym_id + 1))
#  iptables -t mangle -A POSTROUTING -j ROUTE -m mark --mark $(($nym_id + 1)) --oif comm-net-$nym_id
#  iptables -t nat -A POSTROUTING -j SNAT -m mark --mark $(($nym_id + 1))1 --to-source 5.0.0.$(($nym_id + 2))

#  brctl addif comm-br comm-net-$nym_id

  gen_mac_addr
  comm_net_mac_addr=$MACADDR
  gen_mac_addr
  comm_user_net_addr=$MACADDR
  gen_mac_addr
  user_net_addr=$MACADDR

  # Block all packets that are not destined for the communication tool
  ebtables -A PREROUTING -s $user_net_addr -d $comm_user_net_addr -i user-net-$nym_id -j ACCEPT 
  ebtables -A PREROUTING -s $comm_user_net_addr -d $user_net_addr -i comm-user-net-$nym_id -j ACCEPT 
  ebtables -A PREROUTING -s $user_net_addr -i user-net-$nym_id -p arp --arp-ip-dst 5.1.0.1 -j ACCEPT 
  ebtables -A PREROUTING -s $comm_user_net_addr -i comm-user-net-$nym_id -p arp --arp-ip-dst 5.1.0.2 -j ACCEPT 
  ebtables -A PREROUTING -i user-br-$nym_id -j DROP
  ebtables -A PREROUTING -i user-net-$nym_id -j DROP   
  ebtables -A PREROUTING -i comm-user-net-$nym_id -j DROP
#  ebtables -A FORWARD -s $user_net_addr -d $comm_user_net_addr -i user-net-$nym_id -j ACCEPT 
#  ebtables -A FORWARD -s $comm_user_net_addr -d $user_net_addr -i comm-user-net-$nym_id -j ACCEPT 
#  ebtables -A FORWARD -s $user_net_addr -i user-net-$nym_id -p arp --arp-ip-dst 5.1.0.1 -j ACCEPT 
#  ebtables -A FORWARD -s $comm_user_net_addr -i comm-user-net-$nym_id -p arp --arp-ip-dst 5.1.0.2 -j ACCEPT 
#  ebtables -A FORWARD -i user-br-$nym_id -j DROP
#  ebtables -A FORWARD -i user-net-$nym_id -j DROP   
#  ebtables -A FORWARD -i comm-user-net-$nym_id -j DROP
#  ebtables -A INPUT -i user-br-$nym_id -j DROP
#  ebtables -A INPUT -i user-net-$nym_id -j DROP   
#  ebtables -A INPUT -i comm-user-net-$nym_id -j DROP

#  iptables -t filter -A INPUT -i user-net-$nym_id -s 5.1."$nym_id".2 -d 5.1."$nym_id".1 -j ACCEPT
#  iptables -t filter -A INPUT -i user-net-$nym_id -j DROP
#  iptables -t filter -A OUTPUT -o user-net-$nym_id -s 5.1."$nym_id".1 -d 5.1."$nym_id".2 -j ACCEPT
#  iptables -t filter -A OUTPUT -o user-net-$nym_id -j DROP

#  iptables -t filter -A INPUT -i comm-user-net-$nym_id -s 5.1."$nym_id".1 -d 5.1."$nym_id".0 -j ACCEPT
#  iptables -t filter -A INPUT -i comm-user-net-$nym_id -j DROP
#  iptables -t filter -A OUTPUT -o comm-user-net-$nym_id -s 5.1."$nym_id".2 -d 5.1."$nym_id".1 -j ACCEPT
#  iptables -t filter -A OUTPUT -o comm-user-net-$nym_id -j DROP

  # Build Comm to Internet

#  ebtables -A FORWARD -i comm_net_$nym_id -j DROP

#  ifconfig comm-net-$nym_id 5.0."$nym_id".1 netmask 255.255.255.0
#  iptables -t filter -A INPUT -i user-net-$nym_id -d 5.0."$nym_id".0/24 -j DROP

  # Block all packets to and from the communication VM to the local network
#  iptables -t filter -A INPUT -i comm-net-$nym_id -s 5.0."$nym_id".1 -d 5.0."$nym_id".2 -j ACCEPT
#  iptables -t filter -A INPUT -i comm-net-$nym_id -d $ADDR/$MASK -j DROP
#  iptables -t filter -A INPUT -i comm-net-$nym_id -s $ADDR/$MASK -j DROP

#  iptables -t filter -A INPUT -o comm-net-$nym_id -s 5.0."$nym_id".2 -d 5.0."$nym_id".1 -j ACCEPT
#  iptables -t filter -O OUTPUT -o comm-net-$nym_id -d $ADDR/$MASK -j DROP
#  iptables -t filter -O OUTPUT -o comm-net-$nym_id -s $ADDR/$MASK -j DROP
}

function delete_network
{
  tunctl -d user-net-$nym_id
  tunctl -d comm-user-net-$nym_id
  brctl delbr user-br-$nym_id
  tunctl -d comm-net-$nym_id
}

function find_drive
{
  DRIVE=/dev/$(ls -al /dev/disk/by-label/winon | grep -oE "../../.+" | grep -oE [a-zA-Z]+)
}

function start_comm_vm
{
  mem=$(( $(free -m | grep Mem | awk '{print $2}') / 5 ))
  if [[ $mem -le 128 ]]; then
    echo "Insufficient RAM for CommVM"
    exit 1
  elif [[ $mem -gt 2047 ]]; then
    # For 32-bit hosts, which is our current target
    mem=2047
  fi
  mem=128

  cp -axf $NET_PATH $WPATH/$nym_id
  NET_PATH_TO_USE=$WPATH/$nym_id
  echo "  address 5.0."$nym_id".2" >> $NET_PATH_TO_USE/etc/network/interfaces
  echo "  network 5.0."$nym_id".2" >> $NET_PATH_TO_USE/etc/network/interfaces
  echo "  netmask 255.255.255.0" >> $NET_PATH_TO_USE/etc/network/interfaces
  echo "  broadcast 5.0."$nym_id".255" >> $NET_PATH_TO_USE/etc/network/interfaces
  echo "  gateway 5.0."$nym_id".1" >> $NET_PATH_TO_USE/etc/network/interfaces

  kvm \
    -net nic,model=virtio,macaddr=$comm_net_mac_addr -net tap,ifname=comm-net-$nym_id,script=,downscript= \
    -net nic,model=virtio,macaddr=$comm_user_net_addr -net tap,ifname=comm-user-net-$nym_id,script=,downscript= \
    -m $mem \
    -vga std \
    -drive file=$DRIVE,if=virtio \
    -virtfs local,path=$NET_PATH_TO_USE,security_model=passthrough,writeout=immediate,mount_tag=opt \
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
  mem=256

  QEMU_AUDIO_DRV=alsa kvm \
    -net nic,model=virtio,macaddr=$user_net_addr -net tap,ifname=user-net-$nym_id,script=,downscript= \
    -m $mem \
    -vga std \
    -drive file=$DRIVE,if=virtio \
    -virtfs local,path=$USER_PATH,security_model=passthrough,writeout=immediate,mount_tag=opt \
    -virtfs local,path=$SANITIZATION_OUTPUT,security_model=passthrough,writeout=immediate,mount_tag=sani \
    -soundhw ac97 \
    -boot order=c >> /tmp/uservm 2>&1
}

function start
{
  set_root $0 start
  if [[ $? -ne 0 ]]; then
    exit 1
  fi

  # Find unallocated nym
  for (( nym_id = 0 ; $nym_id <= 255 ; nym_id = $nym_id + 1 )); do
    if [[ ! -e $PIDS/vms/$nym_id ]]; then
      break
    fi
  done

  if [[ $nym_id -eq 256 ]]; then
    echo "Unable to allocate Nym, all nyms allocated"
    exit 1
  fi

  mkdir $PIDS/vms/$nym_id
  # So we can tell the VM which Nym it owns
  touch $PIDS/vms/$nym_id/$nym_id

  # Start nym
  echo "Starting communication network VM..."
  create_network
  find_drive
  start_comm_vm
  echo "Done"
  if [[ "$COMM_CHECK" ]]; then
    bash $COMM_CHECK
  fi
  echo "Starting the browser VM..."
  start_user_vm
  echo "Browsing VM shutdown, turning off services"
  stop $nym_id
}

function stop
{
  set_root $0 stop $1
  if [[ $? -ne 0 ]]; then
    exit 1
  fi

  if [[ "$1" ]]; then
    echo "No Nym Id specified"
    exit 1
  fi

  if [[ ! -e $PIDS/vms/$nym_id ]]; then
    echo "Nym does not exist"
    exit 1
  fi

  nym_id=$1
  for $PID in $(ls $PIDS/vms/$nym_id); do
    pkill -KILL $PID
  done

  delete_network
  rm -rf $PIDS/vms/$nym_id
}

case "$1" in
  start) start
    ;;
  stop) stop $2
    ;;
  *) echo "No such command: " $1
    ;;
esac
