#!/bin/sh
# It is a helper script for automated install of NEXTSPACE which has been built
# with scripts. Should be placed next to binary build hierarchy.

. ./install_environment.sh
. ./debian-12.deps.sh
clear

#===============================================================================
# Main sequence
#===============================================================================
$ECHO -e -n "\e[33m"
$ECHO "========================================================================="
$ECHO "This script will install NEXTSPACE release $RELEASE and configure system."
$ECHO "========================================================================="
$ECHO -e -n "\e[1m"
$ECHO -n "Do you want to continue? [y/N]: "
$ECHO -e -n "\e[0m"
read YN
if [ $YN != "y" ]; then
    $ECHO "OK, maybe next time. Exiting..."
    exit
fi

#===============================================================================
# Install dependency packages
#===============================================================================
$ECHO -e "\e[1m"
$ECHO "========================================================================="
$ECHO "Installing system packages needed for NextSpace..."
$ECHO "========================================================================="
$ECHO -e -n "\e[0m"
sudo apt-get install ${RUNTIME_RUN_DEPS} ${WRASTER_RUN_DEPS} ${GNUSTEP_BASE_RUN_DEPS} \
                 ${GNUSTEP_GUI_RUN_DEPS} ${BACK_ART_RUN_DEPS} ${FRAMEWORKS_RUN_DEPS} \
                 ${APPS_RUN_DEPS} 2>&1 > /dev/null
$ECHO -e "\e[32m Done! \e[0m"

#===============================================================================
# Extract distribution
#===============================================================================
$ECHO -e "\e[1m"
$ECHO "========================================================================="
$ECHO "Installing NextSpace..."
$ECHO "========================================================================="
$ECHO -e -n "\e[0m"
$ECHO "Populating /etc..."
CORE_SOURCES="."
DEST_DIR=""
{
    # Preferences
    $MKDIR_CMD $DEST_DIR/Library/Preferences
    $CP_CMD ${CORE_SOURCES}/Library/Preferences/* $DEST_DIR/Library/Preferences/

    # Linker cache
    if ! [ -d $DEST_DIR/etc/ld.so.conf.d ];then
        $MKDIR_CMD -v $DEST_DIR/etc/ld.so.conf.d
    fi
    $CP_CMD ${CORE_SOURCES}/etc/ld.so.conf.d/nextspace.conf $DEST_DIR/etc/ld.so.conf.d/
    sudo ldconfig

    # X11
    if ! [ -d $DEST_DIR/etc/X11/xorg.conf.d ];then
        $MKDIR_CMD -v $DEST_DIR/etc/X11/xorg.conf.d
    fi
    $CP_CMD ${CORE_SOURCES}/etc/X11/Xresources.nextspace $DEST_DIR/etc/X11
    $CP_CMD ${CORE_SOURCES}/etc/X11/xorg.conf.d/*.conf $DEST_DIR/etc/X11/xorg.conf.d/

    # PolKit & udev
    if ! [ -d $DEST_DIR/etc/polkit-1/rules.d ];then
        $MKDIR_CMD -v $DEST_DIR/etc/polkit-1/rules.d
    fi
    $CP_CMD ${CORE_SOURCES}/etc/polkit-1/rules.d/*.rules $DEST_DIR/etc/polkit-1/rules.d/
    if ! [ -d $DEST_DIR/etc/udev/rules.d ];then
        $MKDIR_CMD -v $DEST_DIR/etc/udev/rules.d
    fi
    $CP_CMD ${CORE_SOURCES}/etc/udev/rules.d/*.rules $DEST_DIR/etc/udev/rules.d/

    # User environment
    if ! [ -d $DEST_DIR/etc/profile.d ];then
        $MKDIR_CMD -v $DEST_DIR/etc/profile.d
    fi
    $CP_CMD ${CORE_SOURCES}/etc/profile.d/nextspace.sh $DEST_DIR/etc/profile.d/

    if ! [ -d $DEST_DIR/etc/skel ];then
        $MKDIR_CMD -v $DEST_DIR/etc/skel
    fi
    $CP_CMD ${CORE_SOURCES}/etc/skel/Library $DEST_DIR/etc/skel/
    $CP_CMD ${CORE_SOURCES}/etc/skel/.config $DEST_DIR/etc/skel/
    $CP_CMD ${CORE_SOURCES}/etc/skel/.emacs.d $DEST_DIR/etc/skel/
    $CP_CMD ${CORE_SOURCES}/etc/skel/.gtkrc-2.0 $DEST_DIR/etc/skel/
    $CP_CMD ${CORE_SOURCES}/etc/skel/.*.nextspace $DEST_DIR/etc/skel/

    # Scripts
    if ! [ -d $DEST_DIR/usr/NextSpace/bin ];then
        $MKDIR_CMD -v $DEST_DIR/usr/NextSpace/bin
    fi
    $CP_CMD ${CORE_SOURCES}/usr/NextSpace/bin/* $DEST_DIR/usr/NextSpace/bin/

    # Icons and Plymouth resources
    if ! [ -d $DEST_DIR/usr/share ];then
        $MKDIR_CMD -v $DEST_DIR/usr/share
    fi
    $CP_CMD ${CORE_SOURCES}/usr/share/* $DEST_DIR/usr/share/

    $ECHO "Copying /Applications..."
    $CP_CMD Applications /
    $ECHO "Copying /Developer..."
    $CP_CMD Developer /
    $ECHO "Copying /Library..."
    $CP_CMD Library /
    $ECHO "Copying /usr/NextSpace..."
    $CP_CMD usr/NextSpace /usr
}
sudo ldconfig

#===============================================================================
# More X drivers. Workaround until NextSpace RPMs include them as dependencies
#===============================================================================
$ECHO -e "\e[1m"
$ECHO "========================================================================="
$ECHO "Installing X11 drivers and utilities..."
$ECHO "========================================================================="
$ECHO -e -n "\e[0m"
sudo apt-get install xserver-xorg-input-all xserver-xorg-video-all 2>&1 > /dev/null
$ECHO -e "\e[32m Done! \e[0m"

$ECHO -e "\e[1m"
$ECHO "========================================================================="
$ECHO "Performing system check and configuration..."
$ECHO "========================================================================="
$ECHO -e -n "\e[0m"
#===============================================================================
# Hostname in /etc/hosts
#===============================================================================
setup_hosts

#===============================================================================
# Enable services
#===============================================================================
sudo systemctl daemon-reload
$ECHO -n "Checking for Distributed Objects Mapper: "
systemctl is-enabled gdomap
if [ $? -ne 0 ];then
    $ECHO "Enabling Distributed Objects Mapper service..."
    sudo systemctl enable /usr/NextSpace/lib/systemd/gdomap.service
    sudo systemctl start gdomap
fi
$ECHO -n "Checking for Distributed Notification Center: "
systemctl is-enabled gdnc
if [ $? -ne 0 ];then
    $ECHO "Enabling Distributed Notification Center service..."
    sudo systemctl enable /usr/NextSpace/lib/systemd/gdnc.service
    sudo systemctl enable /usr/NextSpace/lib/systemd/gdnc-local.service
    sudo systemctl start gdnc gdnc-local
fi
$ECHO -n "Checking for Pasteboard: "
systemctl is-enabled gpbs
if [ $? -ne 0 ];then
    $ECHO "Enabling Pasteboard service..."
    sudo systemctl enable /usr/NextSpace/lib/systemd/gpbs.service
    sudo systemctl start gpbs
fi
$ECHO -n "Checking for Login panel: "
systemctl is-enabled loginwindow
if [ $? -ne 0 ];then
    $ECHO "Enabling Login panel service..."
    sudo systemctl enable /usr/NextSpace/Apps/Login.app/Resources/loginwindow.service
fi
$ECHO

#===============================================================================
# SELinux configuration
#===============================================================================
#setup_selinux

$ECHO -e -n "\e[1m"
$ECHO "========================================================================="
$ECHO "Post-install optional configuration"
$ECHO "========================================================================="
$ECHO -e -n "\e[0m"

# Adding user
add_user

# Setting up Login Panel
setup_loginwindow


$ECHO -e "\e[32m"
$ECHO "========================================================================="
$ECHO "    NEXTSPACE $RELEASE successfuly installed! Wolcome to the NeXT world! "
$ECHO "========================================================================="
$ECHO -e "\e[0m"