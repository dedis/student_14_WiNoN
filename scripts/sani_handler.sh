#!/bin/bash
input=$1
filename=$(basename $input)

tmpdir=$(mktemp --dir)
path=$tmpdir/$filename
mv $input $path
filetype=$(file $path)

output_dir=/home/winon/.winon/output

case $filetype in
  *)
    mv $path $output_dir/.
esac

rm -rf $tmpdir
