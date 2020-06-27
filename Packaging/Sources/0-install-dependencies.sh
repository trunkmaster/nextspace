#!/bin/bash

if [ -z "$1" ];then
	echo "specify list of dependencies: "
	ls -1 *dependencies*.txt
	exit 1
fi

for DD in `cat $1` ;do
  echo $DD
  apt-get install -y $DD || exit 1
done
