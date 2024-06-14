#!/bin/sh
# It is a helper script for automated install of NEXTSPACE.
# This script should be placed along with NSUser and NSDeveloper
# directories.

RELEASE=0.95

. ./debian-12.deps.sh

#===============================================================================
# Main sequence
#===============================================================================
echo -e -n "\e[1m"
echo "This script will install NEXTSPACE release $RELEASE and configure system."
echo -n "Do you want to continue? [yN]: "
echo -e -n "\e[0m"
read YN
if [ $YN != "y" ]; then
    echo "OK, maybe next time. Exiting..."
    exit
fi

#===============================================================================
# Install dependency packages
#===============================================================================
sudo apt install ${RUNTIME_RUN_DEPS} ${WRASTER_RUN_DEPS} ${GNUSTEP_BASE_RUN_DEPS} \
                 ${GNUSTEP_GUI_RUN_DEPS} ${BACK_ART_RUN_DEPS} ${FRAMEWORKS_RUN_DEPS} \
                 ${APPS_RUN_DEPS}

#===============================================================================
# Extract distribution
#===============================================================================

#===============================================================================
# More X drivers. Workaround until NextSpace RPMs include them as dependencies
#===============================================================================
echo -n "Installing X11 drivers and utilities..."
sudo apt-get install xserver-xorg-input-all xserver-xorg-video-all xorg-x11-xinit xorg-x11-utils 2>&1 > /dev/null
echo -e -n "\e[32m"
echo "done"
echo -e -n "\e[0m"

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
    sed -i 's/localhost4.localdomain4/localhost4.localdomain4 '"$HOSTNAME"'/g' /etc/hosts
else
    echo -e -n "\e[32m"
    echo "good"
    echo -e -n "\e[0m"
fi

#===============================================================================
# Enable services
#===============================================================================
sudo systemctl daemon-reload
systemctl status gdomap || sudo systemctl enable /usr/NextSpace/lib/systemd/gdomap.service;
systemctl status gdnc || sudo systemctl enable /usr/NextSpace/lib/systemd/gdnc.service;
systemctl status gdnc-local || sudo systemctl enable /usr/NextSpace/lib/systemd/gdnc-local.service;
systemctl status gpbs || sudo systemctl enable /usr/NextSpace/lib/systemd/gpbs.service;
sudo systemctl start gdomap gdnc

${ECHO} "Setting up Login window service to run at system startup..."
sudo systemctl enable /usr/NextSpace/Apps/Login.app/Resources/loginwindow.service

#===============================================================================
# Disable SELinux
#===============================================================================
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


#===============================================================================
# Adding user
#===============================================================================
echo -e -n "\e[1m"
echo -n "Do you want to add user? [yN]: "
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

#===============================================================================
# Setting up Login Panel
#===============================================================================
echo -e -n "\e[1m"
echo -n "Start graphical login panel on system boot? [yN]: "
echo -e -n "\e[0m"
read YN
if [ $YN = "y" ]; then
    systemctl set-default graphical.target
fi

#===============================================================================
# Check if Login Panel works
#===============================================================================
echo -e -n "\e[1m"
echo -n "Do you want to start graphical login panel now? [yN]: "
echo -e -n "\e[0m"
read YN
if [ $YN = "y" ]; then
    systemctl start loginwindow
fi
