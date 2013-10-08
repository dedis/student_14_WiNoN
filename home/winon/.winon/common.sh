#!/bin/bash
function set_root
{
  if [[ $(id -u) -ne 0 ]]; then
    sudo bash -c "exit" 2> /dev/null
    if [[ $? -ne 0 ]]; then
      echo "Unable to start service, need root privileges"
      return 1
    fi
    sudo bash ${@:1}
    exit $?
  fi
  return 0
}

function gen_mac_addr
{
  MACADDR=$(printf 'DE:AD:BE:EF:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)))
  if [[ "$called" ]]; then
    echo -n $MACADDR
  fi
}

function get_addr
{
  if [[ ! "$IF" ]]; then
    if [[ ! "$1" ]]; then
      echo "No interface defined"
    fi
    IF=$1
  fi

  ADDR=$(ip -f inet addr show dev $IF 2> /dev/null | \
    grep -oE "inet [0-9]+.[0-9]+.[0-9]+.[0-9]+" | \
    grep -oE "[0-9]+.[0-9]+.[0-9]+.[0-9]+" 2> /dev/null)

  if [[ "$called" ]]; then
    echo -n $ADDR
  fi
}

function get_mask
{
  if [[ ! "$IF" ]]; then
    if [[ ! "$1" ]]; then
      echo "No interface defined"
    fi
    IF=$1
  fi

  MASK=$(ip -f inet addr show dev $IF | \
    grep -oE "inet [0-9\./]*" | \
    grep -oE "[0-9]+$")

  if [[ "$called" ]]; then
    echo -n $MASK
  fi
}

if [[ "$(basename $0)" == "common.sh" ]]; then
  called=TRUE
  funct=$1
  $funct ${@:2}
fi
