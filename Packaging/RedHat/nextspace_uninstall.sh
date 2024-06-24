#!/bin/sh

clear
echo -e -n "\e[1m"
echo "==============================================================================="
echo "This script will REMOVE NextSpace"
echo "==============================================================================="
echo -e -n "\e[33m"
echo -n "Do you want to continue? [y/N]: "
echo -e -n "\e[0m"
read YN
if [ "$YN" != "y" ]; then
    echo "Great! I hope you enjoy using NextSpace."
    exit
fi

sudo yum -y remove nextspace\* libwraster\* libobjc2\* libcorefoundation\* libdispatch\*
