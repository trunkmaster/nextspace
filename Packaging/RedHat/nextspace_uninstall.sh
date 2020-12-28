#!/bin/sh
# It is a helper script for automated install of NEXTSPACE.
# This script should be placed along with NSUser and NSDeveloper
# directories.

RELEASE=0.90

if [ -f /etc/os-release ]; then 
    source /etc/os-release
    export OS_NAME=$ID
    export OS_VERSION=$VERSION_ID
    if [ $ID == "centos" ]; then
        if [ $VERSION_ID == "7" ]; then
            EPEL_REPO=https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
        else
            EPEL_REPO=epel-release
        fi
    fi
fi

#===============================================================================
# Main sequence
#===============================================================================
echo -e -n "\e[1m"
echo "This script will UNINSTALL your NEXTSPACE release $RELEASE and back the system for default."
echo -n "Do you want to continue? [yn]: "
echo -e -n "\e[0m"
read YN
if [ $YN != "y" ]; then
    echo "OK, maybe next time. Exiting..."
    exit
fi


# Uninstall User packages
echo -n "Uninstall NEXTSPACE User packages..."
npm -e NSUser/* 2>&1 > /dev/null
ldconfig
echo -e -n "\e[32m"
echo "done"
echo -e -n "\e[0m"

# Remove user
echo -e -n "\e[1m"
echo -n "Do you want remove user? [yn]: "
echo -e -n "\e[0m"
read YN
if [ $YN = "y" ]; then
    echo -n "Please enter username of user for remove: "
    read USERNAME
    echo "Rmoving $USERNAME"
    userdel -r $USERNAME
    echo "User deleted."

fi

# Set up SELinux for Default
echo -n "Setting up SELinux configuration for default..."
grep "SELINUX=disabled" /etc/selinux/config 2>&1 > /dev/null
if [ $? -eq 0 ];then
    echo -e -n "\e[33m"
    echo "configuring needed"
    echo -e -n "\e[0m"
    echo "Configuring SELinux (SELINUX=Enforcing)..."
    sed -i 's/SELINUX=disabled/SELINUX=enforcing/g' /etc/selinux/config
else
    echo -e -n "\e[32m"
    echo "good"
    echo -e -n "\e[0m"
fi

# Setting up Login Panel
#echo -e -n "\e[1m"
#echo -n "Start graphical login panel on system boot? [yn]: "
#echo -e -n "\e[0m"
#read YN
#if [ $YN = "y" ]; then
#    systemctl set-default graphical.target
#fi

# Check if Login Panel works
#echo -e -n "\e[1m"
#echo -n "Do you want to start graphical login panel now? [yn]: "
#echo -e -n "\e[0m"
#read YN
#if [ $YN = "y" ]; then
#    systemctl start loginwindow
#fi
