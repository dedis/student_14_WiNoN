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

  gen_mac_addr
  addr0=$MACADDR
  gen_mac_addr
  addr1=$MACADDR

  if [[ $nym_id -le 10 ]]; then
    port="6000"$nym_id
  elif [[ $nym_id -le 100 ]]; then
    port="600"$nym_id
  else
    port="60"$nym_id
  fi

  kvm \
    -daemonize \
    -net nic,model=virtio,macaddr=$addr0,name=comm \
    -net user,name=comm,net=$IPBASE.2.0/24 \
    -net nic,model=virtio,macaddr=$addr1,name=user \
    -net socket,name=user,mcast=230.0.0.1:$port,localaddr=127.0.0.1 \
    -m $mem \
    -vga std \
    -drive file=$DRIVE,if=virtio \
    -virtfs local,path=$NET_PATH,security_model=passthrough,writeout=immediate,mount_tag=opt \
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

  gen_mac_addr
  addr=$MACADDR

  if [[ $nym_id -le 10 ]]; then
    port="6000"$nym_id
  elif [[ $nym_id -le 100 ]]; then
    port="600"$nym_id
  else
    port="60"$nym_id
  fi

  QEMU_AUDIO_DRV=alsa kvm \
    -net nic,model=virtio,macaddr=$addr,name=user \
    -net socket,name=user,mcast=230.0.0.1:$port,localaddr=127.0.0.1 \
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
