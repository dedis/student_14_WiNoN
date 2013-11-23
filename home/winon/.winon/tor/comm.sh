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

set_root $0
if [[ $? -ne 0 ]]; then
  exit 1
fi

# Setup fake loopback address to enable "martian packets"
ifconfig lo:1 $IPBASE.3.1 netmask 255.255.255.255

# Start Tor
mkdir /var/run/tor
chown debian-tor: /var/run/tor
chmod 700 /var/run/tor
tor -f $WHOME/.winon/tor/torrc

# Prepare routing
iptables -t nat -F &> /dev/null
iptables -t filter -F &> /dev/null

iptables -t nat -A PREROUTING -i eth1 ! -d $IPBASE.1.0/24 -p tcp -j DNAT --to-destination $IPBASE.3.1:8082
iptables -t nat -A PREROUTING -i eth1 -p udp --dport 53 -j DNAT --to-destination $IPBASE.3.1
#iptables -t filter -i eth1 -j DROP

$WHOME/.winon/redsocks -c $WHOME/.winon/redsocks.conf &> /dev/null &
