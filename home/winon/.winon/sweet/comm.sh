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

# Start SWEET 
python2 $WHOME/.winon/sweet/ip2email.py -s -p 18080 &> /tmp/sweet_fwd &
# Wait for it to start
netstat -tln | grep 18080
while [[ $? -ne 0 ]]; do
  sleep 1
  netstat -tln | grep 18080
done

$WHOME/.winon/sweet/entry_tunnel --tunnel=tcp://127.0.0.1:8081 \
  --forwarder=tcp://127.0.0.1:18080 &> /tmp/sweet_tun &

# Prepare routing
iptables -t nat -F &> /dev/null
iptables -t mangle -F &> /dev/null

iptables -t mangle -X DIVERT &> /dev/null

iptables -t nat -A PREROUTING -i eth1 ! -d 5.1.0.0/24 -p tcp -j DNAT --to-destination 5.2.0.1:8082
iptables -t mangle -N DIVERT
iptables -t mangle -A PREROUTING -i eth1 ! -d 5.1.0.0/24 -p udp -j DIVERT
iptables -t mangle -A DIVERT -j MARK --set-mark 1
iptables -t mangle -A DIVERT -p udp -j TPROXY --on-port 8082 --on-ip 127.0.0.1 --tproxy-mark 0x1/0x1
ip rule add fwmark 1 lookup 100
ip route add local 0.0.0.0/0 dev lo table 100

$WHOME/.winon/redsocks -c $WHOME/.winon/redsocks.conf &> /dev/null &
