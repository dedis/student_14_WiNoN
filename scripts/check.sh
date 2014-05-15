#!/bin/bash
source /etc/default/winon 2> /dev/null
if [[ $? -ne 0 ]]; then
  echo "Error reading /etc/default/winon"
  exit 1
fi

source $WPATH/scripts/common.sh 2> /dev/null
if [[ $? -ne 0 ]]; then
  echo "Error reading $WPATH/scripts/common.sh"
  exit 1
fi

nym=$1
set_root $0 $nym
if [[ $? -ne 0 ]]; then
  exit 1
fi

result=
while [[ ! "$result" ]]; do
  result=$(nc -w 1 -U $WPATH/nym/$nym)
done
