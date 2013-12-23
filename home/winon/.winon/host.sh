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

function set_ip
{
  # Wait for IP Address
  ADDR=
  once=
  while [[ ! "$ADDR" ]]; do
    IF=eth0
    get_addr
    if [[ ! "$ADDR" ]]; then
      IF=wlan0
      get_addr
      if [[ ! "$ADDR" ]]; then
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
  if [[ "$DETERLAB" ]]; then
    return
  fi

  ntpdate pool.ntp.org &> /dev/null
  while [[ $? -eq 1 ]]; do
    sleep 1
    result=$(ntpdate pool.ntp.org 2>&1)
    if [[ $? -eq 1 ]]; then
      echo $result | grep "no server suitable" &> /dev/null
    fi
  done
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
    -daemonize \
    --name ScrubberVM \
    -m $mem \
    -vga std \
    -drive file=$DRIVE,if=virtio \
    -boot order=c \
    -net nic -net none \
    -virtfs local,path=$SANITIZATION_PATH,security_model=passthrough,writeout=immediate,mount_tag=opt \
    -virtfs local,path=$SANITIZATION_INPUT,security_model=passthrough,writeout=immediate,mount_tag=sani \
    $drives >> /tmp/sanivm 2>&1
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
  set_ip
  echo "Network configured, using: $ADDR"
  start_sanitization_vm
  echo "Host configuration: Done"
  sleep 5

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
