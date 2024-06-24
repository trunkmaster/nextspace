#!/bin/sh
# It is a helper script for automated install of NEXTSPACE.
# This script should be placed along with NSUser and NSDeveloper
# directories.

. ./install_environment.sh

ENABLE_EPEL=""
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
        ENABLE_EPEL="--enablerepo=epel"
    fi
fi

clear
#===============================================================================
# Main sequence
#===============================================================================
echo -e -n "\e[1m"
echo "==============================================================================="
echo "This script will install NEXTSPACE release $RELEASE and configure system."
echo "==============================================================================="
echo -e -n "\e[33m"
echo -n "Do you want to continue? [y/N]: "
echo -e -n "\e[0m"
read YN
if [ "$YN" != "y" ]; then
    echo "OK, maybe next time. Exiting..."
    exit
fi

#===============================================================================
# Add EPEL package repository if needed
#===============================================================================
if [ "$EPEL_REPO" != "" ]; then
    echo -n "Checking for EPEL repository installed..."
    yum repolist | grep "epel" 2>&1 > /dev/null
    if [ $? -eq 1 ];then
        echo "Adding EPEL repository..."
        yum -y install $EPEL_REPO 2>&1 > /dev/null
        echo "Updating system..."
        yum -y update  2>&1 > /dev/null
    else
        echo -e -n "\e[32m"
        echo "yes"
        echo -e -n "\e[0m"
    fi
fi

#===============================================================================
# Hostname in /etc/hosts
#===============================================================================
setup_hosts
echo

#===============================================================================
# Disable SELinux
#===============================================================================
setup_selinux
echo

#===============================================================================
# Install User packages
#===============================================================================
echo -e -n "\e[1m"
echo "==============================================================================="
echo "Installing NEXTSPACE User packages..."
echo "==============================================================================="
echo -e -n "\e[0m"
echo -n "..."
sudo yum -y -q install $ENABLE_EPEL NSUser/*.rpm 2>&1 > /dev/null || exit 1
sudo ldconfig
echo -e -n "\e[32m"
echo -e "\b\b\bDone. User packages were installed."
echo -e -n "\e[0m"
echo

#===============================================================================
# Install Developer packages
#===============================================================================
echo -e -n "\e[33m"
echo -n "Do you want to install packages for NEXTSPACE development? [y/N]: "
echo -e -n "\e[0m"
read YN
if [ "$YN" = "y" ]; then
    echo -e -n "\e[1m"
    echo "==============================================================================="
    echo "Installing NEXTSPACE Developer packages..."
    echo "==============================================================================="
    echo -e -n "\e[0m"
    echo -n "..."
    if [ $OS_NAME == "centos" ]; then
        if [ $VERSION_ID == "7" ]; then
            sudo yum -y -q install centos-release-scl 2>&1 > /dev/null || exit 1
            ENABLE_EPEL+=" --enable-repo=centos-sclo-sclo --enable-repo=centos-sclo-rh"
        fi
    fi
    sudo yum -y -q install $ENABLE_EPEL NSDeveloper/*.rpm 2>&1 > /dev/null || exit 1
    echo -e -n "\e[32m"
    echo -e "\b\b\bDone. Developer packages were installed."
    echo -e -n "\e[0m"
fi
echo

#===============================================================================
# More X drivers. Workaround until NextSpace RPMs include them as dependencies
#===============================================================================
echo -e -n "\e[1m"
echo "==============================================================================="
echo "Installing X11 drivers and utilities..."
echo "==============================================================================="
echo -e -n "\e[0m"
echo -n "..."
X11_DRIVERS="xorg-x11-drivers xorg-x11-xinit"
if [ $OS_NAME == "centos" ]; then
    X11_DRIVERS+=" xorg-x11-utils"
fi
sudo yum -y -q install $X11_DRIVERS 2>&1 > /dev/null || exit 1
echo -e -n "\e[32m"
echo -e "\b\b\bDone. X11 drivers and utilities were installed."
echo -e -n "\e[0m"
echo

#===============================================================================
# Post-install activities
#===============================================================================
echo -e -n "\e[1m"
echo "==============================================================================="
echo "Post-install optional configuration"
echo "==============================================================================="
echo -e -n "\e[0m"

# Adding user
add_user

# Setting up Login Panel
setup_loginwindow

echo -e "\e[32m"
echo " NEXTSPACE $RELEASE successfuly installed! Wolcome to the NeXT world!"
echo -e "\e[0m"
