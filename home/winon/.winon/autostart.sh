#!/bin/bash
source /etc/default/winon
if [[ $? -ne 0 ]]; then
  echo "Error reading /etc/default/winon"
  exit 1
fi

xterm -e bash -c "$WPATH/host.sh start" &
exit 0
