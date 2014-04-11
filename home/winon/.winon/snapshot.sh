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

(cd /rw && find . | cpio --create --format='newc' > /rw_prst/persist.cpio)
echo "Snapshot created successfully"
