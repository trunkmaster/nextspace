#!/bin/sh

#===============================================================================
# Defines
#===============================================================================
RELEASE=0.90

#===============================================================================
# Functions
#===============================================================================
setup_package_list()
{
if [ -f /etc/os-release ]; then
    source /etc/os-release;
    if [ $ID == "centos" ];then
        if [ $VERSION_ID == "7" ];then
            REPO_URL="https://trunkmaster.github.io/0.90/el7"
            USER_PACKAGES="${REPO_URL}/libdispatch-5.1.5-0.el7.x86_64.rpm \
               ${REPO_URL}/libobjc2-2.0-4.el7.x86_64.rpm \
               ${REPO_URL}/libwraster-5.0.0-0.el7.x86_64.rpm \
               ${REPO_URL}/nextspace-core-0.95-10.el7.x86_64.rpm \
               ${REPO_URL}/nextspace-gnustep-1_27_0_nextspace-1.el7.x86_64.rpm \
               ${REPO_URL}/nextspace-frameworks-0.90-2.el7.x86_64.rpm \
               ${REPO_URL}/nextspace-applications-0.90-0.el7.x86_64.rpm"
            DEVEL_PACKAGES="${REPO_URL}/libdispatch-devel-5.1.5-0.el7.x86_64.rpm \
               ${REPO_URL}/libdispatch-debuginfo-5.1.5-0.el7.x86_64.rpm \
               ${REPO_URL}/libobjc2-devel-2.0-4.el7.x86_64.rpm \
               ${REPO_URL}/libobjc2-debuginfo-2.0-4.el7.x86_64.rpm \
               ${REPO_URL}/libwraster-devel-5.0.0-0.el7.x86_64.rpm \
               ${REPO_URL}/libwraster-debuginfo-5.0.0-0.el7.x86_64.rpm \
               ${REPO_URL}/nextspace-core-devel-0.95-10.el7.x86_64.rpm \
               ${REPO_URL}/nextspace-gnustep-devel-1_27_0_nextspace-1.el7.x86_64.rpm \
               ${REPO_URL}/nextspace-gnustep-debuginfo-1_27_0_nextspace-1.el7.x86_64.rpm \
               ${REPO_URL}/nextspace-frameworks-devel-0.90-2.el7.x86_64.rpm \
               ${REPO_URL}/nextspace-frameworks-debuginfo-0.90-2.el7.x86_64.rpm \
               ${REPO_URL}/nextspace-applications-devel-0.90-0.el7.x86_64.rpm \
               ${REPO_URL}/nextspace-applications-debuginfo-0.90-0.el7.x86_64.rpm"
        fi
        if [ $VERSION_ID == "8" ];then
            REPO_URL="https://trunkmaster.github.io/0.90/el8"
            USER_PACKAGES="${REPO_URL}/libdispatch-5.1.5-0.el8.x86_64.rpm \
               ${REPO_URL}/libobjc2-2.0-4.el8.x86_64.rpm \
               ${REPO_URL}/libwraster-5.0.0-0.el8.x86_64.rpm \
               ${REPO_URL}/nextspace-core-0.95-10.el8.x86_64.rpm \
               ${REPO_URL}/nextspace-gnustep-1_27_0_nextspace-1.el8.x86_64.rpm \
               ${REPO_URL}/nextspace-frameworks-0.90-2.el8.x86_64.rpm \
               ${REPO_URL}/nextspace-applications-0.90-0.el8.x86_64.rpm"
            DEVEL_PACKAGES="${REPO_URL}/libdispatch-devel-5.1.5-0.el8.x86_64.rpm \
               ${REPO_URL}/libdispatch-debuginfo-5.1.5-0.el8.x86_64.rpm \
               ${REPO_URL}/libobjc2-devel-2.0-4.el8.x86_64.rpm \
               ${REPO_URL}/libobjc2-debuginfo-2.0-4.el8.x86_64.rpm \
               ${REPO_URL}/libwraster-devel-5.0.0-0.el8.x86_64.rpm \
               ${REPO_URL}/libwraster-debuginfo-5.0.0-0.el8.x86_64.rpm \
               ${REPO_URL}/nextspace-core-devel-0.95-10.el8.x86_64.rpm \
               ${REPO_URL}/nextspace-gnustep-devel-1_27_0_nextspace-1.el8.x86_64.rpm \
               ${REPO_URL}/nextspace-gnustep-debuginfo-1_27_0_nextspace-1.el8.x86_64.rpm \
               ${REPO_URL}/nextspace-frameworks-devel-0.90-2.el8.x86_64.rpm \
               ${REPO_URL}/nextspace-frameworks-debuginfo-0.90-2.el8.x86_64.rpm \
               ${REPO_URL}/nextspace-applications-devel-0.90-0.el8.x86_64.rpm \
               ${REPO_URL}/nextspace-applications-debuginfo-0.90-0.el8.x86_64.rpm"
        fi
    fi
fi
}
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
else
    echo -e -n "\e[32m"
    echo "good"
    echo -e -n "\e[0m"
fi

# Install User packages
echo -n "Installing NEXTSPACE User packages..."
setup_package_list
yum -y -q install --enablerepo=epel ${USER_PACKAGES} 2>&1 > /dev/null
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
    yum -y -q install --enablerepo=epel ${DEVEL_PACKAGES} 2>&1 > /dev/null
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
