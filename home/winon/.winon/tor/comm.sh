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

# Setup fake loopback address to enable "martian packets"
ifconfig lo:1 5.2.0.1 netmask 255.255.255.255

# Start Tor
mkdir /var/run/tor
chown debian-tor: /var/run/tor
chmod 700 /var/run/tor
tor -f $WHOME/.winon/tor/torrc

# Prepare routing
iptables -t nat -F &> /dev/null
iptables -t filter -F &> /dev/null

iptables -t nat -A PREROUTING -i eth1 ! -d 5.1.0.0/24 -p tcp -j DNAT --to-destination 5.2.0.1:8082
iptables -t nat -A PREROUTING -i eth1 -p udp --dport 53 -j DNAT --to-destination 5.2.0.1
#iptables -t filter -i eth1 -j DROP

$WHOME/.winon/redsocks -c $WHOME/.winon/redsocks.conf &> /dev/null &
