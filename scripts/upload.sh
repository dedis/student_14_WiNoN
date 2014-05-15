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

set_root $0
if [[ $? -ne 0 ]]; then
  exit 1
fi

echo "Select a nym to save:"
select nym_path in $(ls -d $PERSIST_PATH/*)
do
  if [ -d "$nym_path" ]; then
    echo "Saving nym at $nym_path..."
    break
  fi
done

set -e
set -o pipefail
archive_path=$PERSIST_PATH/nym.enc
tar -cjp -C $nym_path . | openssl aes-256-cbc -out $archive_path
if [ $? -ne 0 ]; then
  echo "Failed creating encrypted archive at $archive_path."
  exit 1
fi
echo "Encypted archive saved to $archive_path."
python2.7 $WPATH/scripts/upload.py $archive_path
