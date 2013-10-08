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

function reset_network
{
  iptables -t nat -F &> /dev/null
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
    get_addr
    if [[ $? -ne 0 ]]; then
      IF=wlan0
      get_addr
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

  get_mask
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

function remove_nat
{
  iptables -t nat -D POSTROUTING -o $IF -j MASQUERADE
  echo 1 > /proc/sys/net/ipv4/ip_forward
  iptables -D INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  iptables -D INPUT -m state --state NEW ! -i $IF -j ACCEPT
  iptables -D INPUT DROP
  iptables -D FORWARD -i $IF -o $IF -j REJECT

#  brctl delbr comm-br
}

function setup_nat
{
  # http://www.ibiblio.org/pub/linux/docs/howto/other-formats/html_single/Masquerading-Simple-HOWTO.html
  iptables -t nat -A POSTROUTING -o $IF -j MASQUERADE
  echo 1 > /proc/sys/net/ipv4/ip_forward
  iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  iptables -A INPUT -m state --state NEW ! -i $IF -j ACCEPT
  iptables -P INPUT DROP
  iptables -A FORWARD -i $IF -o $IF -j REJECT

#  brctl addbr comm-br
#  ifconfig comm-br 5.0.0.1 netmask 255.255.255.0
#  iptables -t nat -A OUTPUT -j DNAT -m mark ! --mark 0 --to-destination 5.0.0.2
}

function start_sanitization_vm
{
  mem=$(( $(free -m | grep Mem | awk '{print $2}') / 5 ))
  if [[ $mem -le 128 ]]; then
    echo "Insufficient RAM for SaniVM"
    exit 1
  elif [[ $mem -gt 2047 ]]; then
    # For 32-bit hosts, which is our current target
    mem=2047
  fi
  mem=128

  drives=
  winonlink=$(readlink /dev/disk/by-label/winon)
  for drive in $(ls /dev/disk/by-uuid); do
    link=$(readlink /dev/disk/by-uuid/$drive)
    if [[ $link == $winonlink ]]; then
      continue;
    fi
    drives=$drives"-drive file=/dev/disk/by-uuid/$drive,if=virtio,readonly "
  done

  if [[ ! "$drives" ]]; then
    echo "No drives to mount, not loading SaniVM"
    return 0
  fi

  DRIVE=/dev/$(ls -al /dev/disk/by-label/winon | grep -oE "../../.+" | grep -oE [a-zA-Z]+)

  kvm \
    -m $mem \
    -vga std \
    -drive file=$DRIVE,if=virtio \
    -boot order=c \
    -net nic -net none \
    -virtfs local,path=$SANITIZATION_PATH,security_model=passthrough,writeout=immediate,mount_tag=opt \
    -virtfs local,path=$SANITIZATION_INPUT,security_model=passthrough,writeout=immediate,mount_tag=sani \
    $drives >> /tmp/sanivm 2>&1 &
  echo $! > $PIDS/sanivm

  python2 $WHOME/.winon/sani_monitor.py &
  echo $! > $PIDS/sanimon

  echo "SaniVM started"
}

function start
{
  if [[ -e $WPATH/started ]]; then
    echo "WiNon already started: $WPATH/started exists"
    exit 1
  fi

  set_root $0 start
  if [[ $? -ne 0 ]]; then
    exit 1
  fi

  echo "Host configuration: Starting"
  reset_network
  set_ip
  echo "Network configured, using: $ADDR"
  setup_nat
  start_sanitization_vm
  echo "Host configuration: Done"

  echo $IF > $WPATH/started
}

function stop
{
  if [[ ! -e $WPATH/started ]]; then
    echo "WiNon hasn't been started: $WPATH/started does not exist"
    exit 1
  fi

  set_root $0 stop
  if [[ $? ]]; then
    exit 1
  fi

  IF=$(cat $WPATH/started)
  remove_nat

  rm $WPATH/started
}

case "$1" in
  start) start
    ;;
  stop) stop
    ;;
  *) echo "No such command: " $1
    ;;
esac
