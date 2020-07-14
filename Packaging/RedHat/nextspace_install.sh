#!/bin/sh
# It is a helper script for automated install of NEXTSPACE.
# This script should be placed along with NSUser and NSDeveloper
# directories.

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
echo "This script will install NEXTSPACE release $RELEASE and configure system."
echo -n "Do you want to continue? [yn]: "
echo -e -n "\e[0m"
read YN
if [ $YN != "y" ]; then
    echo "OK, maybe next time. Exiting..."
    exit
fi

# Add EPEL package repository if needed
if [ $EPEL_REPO != "" ]; then
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

# More X drivers. Workaround until NextSpace RPMs include them as dependencies
echo -n "Installing X11 drivers and utilities..."
yum -y -q install xorg-x11-drivers xorg-x11-xinit xorg-x11-utils 2>&1 > /dev/null
echo -e -n "\e[32m"
echo "done"
echo -e -n "\e[0m"

# Hostname in /etc/hosts
echo -n "Checking /etc/hosts..."
HOSTNAME="`hostname -s`"
grep "$HOSTNAME" /etc/hosts 2>&1 > /dev/null
if [ $? -eq 1 ];then
    if [ $HOSTNAME != `hostname` ];then
        HOSTNAME="$HOSTNAME `hostname`"
    fi
    echo -e -n "\e[33m"
    echo "configuring needed"
    echo -e -n "\e[0m"
    echo "Configuring hostname ($HOSTNAME)..."
    sed -i 's/localhost4.localdomain4/localhost4.localdomain4 '"$HOSTNAME"'/g' /etc/hosts
else
    echo -e -n "\e[32m"
    echo "good"
    echo -e -n "\e[0m"
fi

# Disable SELinux
echo -n "Checking SELinux configuration..."
grep "SELINUX=enforcing" /etc/selinux/config 2>&1 > /dev/null
if [ $? -eq 0 ];then
    echo -e -n "\e[33m"
    echo "configuring needed"
    echo -e -n "\e[0m"
    echo "Configuring SELinux (SELINUX=disabled)..."
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    echo "+------------------------------------------------------------------------------+"
    echo "| SELinux configuration has been changed. Linux needs reboot to apply changes. |"
    echo "| Run this script after reboot to continue installation of NEXTSPACE.          |"
    echo "+------------------------------------------------------------------------------+"
    echo "  Press Enter to reboot or Crtl-C to cancel reboot and quit..."
    read YN
    shutdown -r now
else
    echo -e -n "\e[32m"
    echo "good"
    echo -e -n "\e[0m"
fi

# Install User packages
echo -n "Installing NEXTSPACE User packages..."
yum -y -q install --enablerepo=epel NSUser/*.rpm 2>&1 > /dev/null
ldconfig
echo -e -n "\e[32m"
echo "done"
echo -e -n "\e[0m"

# Install Developer packages
echo -e -n "\e[1m"
echo -n "Do you want to install packages for NEXTSPACE development? [yn]: "
echo -e -n "\e[0m"
read YN
if [ $YN = "y" ]; then
    echo -n "Installing NEXTSPACE Developer packages..."
    yum -y -q install --enablerepo=epel NSDeveloper/*.rpm 2>&1 > /dev/null
    echo -e -n "\e[32m"
    echo "done"
    echo -e -n "\e[0m"
fi

# Adding user
echo -e -n "\e[1m"
echo -n "Do you want to add user? [yn]: "
echo -e -n "\e[0m"
read YN
if [ $YN = "y" ]; then
    echo -n "Please enter username: "
    read USERNAME
    echo "Adding username $USERNAME"
    adduser -b /Users -s /bin/zsh -G audio,wheel $USERNAME
    echo "Setting up password..."
    passwd $USERNAME
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
