#!/bin/sh
# It is a helper script for automated install of NEXTSPACE.
# This script should be placed along with NSUser and NSDeveloper
# directories.

RELEASE=0.95
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
    sudo sed -i 's/localhost4.localdomain4/localhost4.localdomain4 '"$HOSTNAME"'/g' /etc/hosts
else
    echo -e -n "\e[32m"
    echo -e "good"
    echo -e -n "\e[0m"
fi
echo

#===============================================================================
# Disable SELinux
#===============================================================================
#clear
echo -e -n "\e[1m"
echo "==============================================================================="
echo "SELinux configuration"
echo "==============================================================================="
echo -e -n "\e[0m"
#echo -n "Checking SELinux configuration..."
SELINUX_MODE=$(getenforce)
#echo -e -n "\e[32m"
#echo -e "\b\b\b   ${SELINUX_MODE}"
#echo -e -n "\e[0m"
echo -e -n "\e[1m"
echo "Current SELinux mode is ${SELINUX_MODE}"
echo -e -n "\e[0m"
echo -e -n "\e[33m"
echo -n "Do you want to change your SELinux configuration? [y/N]: "
echo -e -n "\e[0m"
read YN
if [ "$YN" = "y" ]; then
    echo
    echo "Please choose the default SELinux mode"
    echo
    echo " 1) Permissive: SELinux will be active but will only log policy violations"
    echo "                instead of enforcing them (default for NEXTSPACE)."
    echo " 2) Enforcing: SELinux will enforce the loaded policies and actively block"
    echo "               access attempts which are not allowed (distro default)."
    echo " 3) Disabled: the SELinux subsystem will be disabled (choose this one if you" 
    echo "              have a strong reason for it)."
    echo
    echo "The recommended (and default) option is \"Permissive\", which will prevent "
    echo "'SELinux from blocking accesses while logging them."
    echo "Choose \"Enforcing\" if you want or need to keep SELinux active, this will "
    echo "use the NEXTSPACE policies; keep in mind that they are a work in progress."
    echo "You can also choose to completely disable the SELinux subsystem; this should "
    echo "functionally be similar to \"Permissive\" but will not log anything."
    echo
    echo "Filesystem with undergo automatic relabelling upon reboot for \"Permissive\" "
    echo "and \"Enforcing\" policies".
    echo
    echo -e -n "\e[1m"
    echo -n "SELinux mode [default: 1]: "
    echo -e -n "\e[0m"
    read SEL
    echo -n "Setting SELinux default mode to "
    if [ "$SEL" = 2 ]; then
        echo Enforcing...
        sudo sed -i -e ' s/SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
        sudo touch /.autorelabel
    elif [ "$SEL" = 3 ]; then
        echo Disabled...
        sudo sed -i -e ' s/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    else
        echo Permissive...
        sudo sed -i -e ' s/SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
        sudo touch /.autorelabel
    fi
    echo "Done!"
    # TODO: echo -n "Installing NEXTSPACE SELinux policies..."
fi

#===============================================================================
# Install User packages
#===============================================================================
echo
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
echo -n "Do you want to install packages for NEXTSPACE development? [yN]: "
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

echo -e -n "\e[1m"
echo "==============================================================================="
echo "Post-install optional configuration"
echo "==============================================================================="
echo -e -n "\e[0m"
#===============================================================================
# Adding user
#===============================================================================
echo -e -n "\e[33m"
echo -n "Do you want to add user? [y/N]: "
echo -e -n "\e[0m"
read YN
if [ "$YN" = "y" ]; then
    echo -n "Please enter username: "
    read USERNAME
    echo "Adding username $USERNAME"
    sudo adduser -b /Users -s /bin/zsh -G audio,wheel $USERNAME
    echo "Setting up password..."
    sudo passwd $USERNAME
    echo "Updating SELinux file contexts..."
    ## Needed to update the filesystem contexts that depend on HOME_DIR, and wrongly assume /home
    sudo semodule -e ns-core  2>&1 > /dev/null
    sudo restorecon -R /Users 2>&1 > /dev/null
fi

#===============================================================================
# Setting up Login Panel
#===============================================================================
echo -e -n "\e[33m"
echo -n "Start graphical login panel on system boot? [y/N]: "
echo -e -n "\e[0m"
read YN
if [ "$YN" = "y" ]; then
    sudo systemctl set-default graphical.target
fi

#===============================================================================
# Check if Login Panel works
#===============================================================================
echo -e -n "\e[33m"
echo -n "Do you want to start graphical login panel now? [y/N]: "
echo -e -n "\e[0m"
read YN
if [ "$YN" = "y" ]; then
    sudo systemctl start loginwindow
fi

echo -e "\e[32m"
echo " NEXTSPACE $RELEASE successfuly installed! Wolcome to the NeXT world!"
echo -e "\e[0m"
