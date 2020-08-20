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

SELINUX_MODE=$(getenforce)
echo ...done.
echo
echo -e -n "\e[1m"
echo "Current SELinux mode is ${SELINUX_MODE}"
echo
echo -e -n "\e[0m"
echo "Please choose the default SELinux mode"
echo
echo " 1) Permissive: SELinux will be active but will only log policy violations instead of enforcing them (default for NEXTSPACE)."
echo " 2) Enforcing: SELinux will enforce the loaded policies and actively block access attempts which are not allowed (distro default)."
echo " 3) Disabled: the SELinux subsystem will be disabled (choose this one if you have a strong reason for it)."
echo
echo "The recommended (and default) option is \"Permissive\", which will prevent SELinux from blocking accesses while logging them."
echo "Choose \"Enforcing\" if you want or need to keep SELinux active, this will use the NEXTSPACE policies; keep in mind that they are a work in progress."
echo "You can also choose to completely disable the SELinux subsystem; this should functionally be similar to \"Permissive\" but will not log anything."
echo
echo -e -n "\e[1m"
echo -n "SELinux mode [default: 1]?"
echo -e -n "\e[0m"
read SEL
echo -n "Setting SELinux default mode to "
if [ 1$SEL -eq  12 ]; then
    echo -n enforcing
    sed -i -e ' s/SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
    touch /.autorelabel
elif [ 1$SEL -eq 13 ]; then
    echo -n disabled
    sed -i -e ' s/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
else
    echo -n permissive
    sed -i -e ' s/SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
    touch /.autorelabel
fi
echo "... done."
echo "Filesystem with undergo automatic relabelling upon reboot for \"Permissive\" and \"Enforcing\" policies".
echo
# TODO: echo -n "Installing NEXTSPACE SELinux policies..."


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
    ENABLE_REPO="--enable-repo=epel"
    if [ $OS_NAME == "centos" ] && [ $OS_VERSION == "7" ]; then
        yum -y -q install centos-release-scl 2>&1 > /dev/null
        ENABLE_REPO+=" --enable-repo=centos-sclo-sclo --enable-repo=centos-sclo-rh"
    fi
    yum -y -q install ${ENABLE_REPO} NSDeveloper/*.rpm 2>&1 > /dev/null
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
    echo "Updating SELinux file contexts..."
    ## Needed to update the filesystem contexts that depend on HOME_DIR, and wrongly assume /home
    semodule -e ns-core  2>&1 > /dev/null
    restorecon -R /Users 2>&1 > /dev/null
fi

# Setting up Login Panel
echo -e -n "\e[1m"
echo -n "Start graphical login panel on system boot? [yn]: "
echo -e -n "\e[0m"
read YN
if [ $YN = "y" ]; then
    systemctl set-default graphical.target
fi

# Check if Login Panel works
echo -e -n "\e[1m"
echo -n "Do you want to start graphical login panel now? [yn]: "
echo -e -n "\e[0m"
read YN
if [ $YN = "y" ]; then
    systemctl start loginwindow
fi
