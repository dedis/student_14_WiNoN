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

set_root $0 $1
if [[ $? -ne 0 ]]; then
  exit 1
fi

nym_id=$1

# Download nym
python2.7 $WPATH/download.py $PERSIST_PATH/$nym_id.enc
#if [ $? -ne 0 ]; then
#  echo "Failed downloading nym from cloud."
#  exit 1
#fi

# Decrypt and extract
set -e
set -o pipefail
cd $PERSIST_PATH/$nym_id 
openssl aes-256-cbc -d -in $PERSIST_PATH/$nym_id.enc | tar -xjp

if [ $? -ne 0 ]; then
  echo "Failed extracting encrypted archive."
  exit 1
fi
