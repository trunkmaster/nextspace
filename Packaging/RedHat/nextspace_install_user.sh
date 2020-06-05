#!/bin/sh
RELEASE=0.90
REPO_URL="https://trunkmaster.github.io/0.90/el7"

echo -e -n "\e[1m"
echo "This script will install NEXTSPACE release $RELEASE and configure system."
echo -n "Do you want to continue? [yn]: "
echo -e -n "\e[0m"
read YN
if [ $YN != "y" ]; then
    echo "OK, maybe next time. Exiting..."
    exit
fi

# Add EPEL package repository
echo -n "Checking for EPEL repository installed..."
yum repolist | grep "epel/" 2>&1 > /dev/null
if [ $? -eq 1 ];then
    echo "Adding EPEL repository..."
    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm 2>&1 > /dev/null
    echo "Updating system..."
    yum -y update  2>&1 > /dev/null
else
    echo -e -n "\e[32m"
    echo "yes"
    echo -e -n "\e[0m"
fi

# Hostname in /etc/hosts
echo -n "Checking /etc/hosts..."
HOSTNAME="`hostname -s`"
HOSTNAME="$HOSTNAME `hostname`"
grep "$HOSTNAME" /etc/hosts 2>&1 > /dev/null
if [ $? -eq 1 ];then
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
grep "SELINUX=enforcing" /etc/sysconfig/selinux 2>&1 > /dev/null
if [ $? -eq 0 ];then
    echo -e -n "\e[33m"
    echo "configuring needed"
    echo -e -n "\e[0m"
    echo "Configuring SELinux (SELINUX=disabled)..."
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
else
    echo -e -n "\e[32m"
    echo "good"
    echo -e -n "\e[0m"
fi

# Install packages
echo -n "Installing NEXTSPACE packages..."
yum -y -q install --enablerepo=epel \
    ${REPO_URL}/libdispatch-5.1.5-0.el7.x86_64.rpm \
    ${REPO_URL}/libobjc2-2.0-4.el7.x86_64.rpm \
    ${REPO_URL}/libwraster-5.0.0-0.el7.x86_64.rpm \
    ${REPO_URL}/nextspace-core-0.95-10.el7.x86_64.rpm \
    ${REPO_URL}/nextspace-gnustep-1_27_0_nextspace-1.el7.x86_64.rpm \
    ${REPO_URL}/nextspace-frameworks-0.90-2.el7.x86_64.rpm \
    ${REPO_URL}/nextspace-applications-0.90-0.el7.x86_64.rpm 2>&1 > /dev/null;
ldconfig;
echo -e -n "\e[32m"
echo "done"
echo -e -n "\e[0m"

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
