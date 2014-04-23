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
DOWNLOAD_PATH=$WPATH/downloads
rm -rf $DOWNLOAD_PATH/*
python2.7 $WPATH/download.py $DOWNLOAD_PATH/nym.enc
#if [ $? -ne 0 ]; then
#  echo "Failed downloading nym from cloud."
#  exit 1
#fi

# Decrypt and extract
set -e
set -o pipefail
cd $DOWNLOAD_PATH
openssl aes-256-cbc -d -in $DOWNLOAD_PATH/nym.enc | tar -xjpS
if [ $? -ne 0 ]; then
  echo "Failed extracting encrypted archive."
  exit 1
fi

# Start the nym
$WPATH/start_nym.sh start $DOWNLOAD_PATH
