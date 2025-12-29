#!/bin/sh
# It is a helper script for automated install of NEXTSPACE which has been built
# with scripts. Should be placed next to binary build hierarchy.

. `dirname $0`/../functions.sh
. `dirname $0`/../environment.sh
. `dirname $0`/../install_environment.sh

if [ ${OS_ID} = "debian" ]; then
. `dirname $0`/./debian-13.deps.sh
else
. `dirname $0`/./ubuntu-24.deps.sh
fi

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
if [ ${OS_ID} = "debian" ] || [ ${OS_ID} = "ubuntu" ]; then
   sudo apt-get -y install ${RUNTIME_DEPS} ${WRASTER_DEPS} ${RUNTIME_RUN_DEPS} ${WRASTER_RUN_DEPS} ${GNUSTEP_BASE_RUN_DEPS} \
                   ${GNUSTEP_GUI_DEPS} ${GNUSTEP_GUI_RUN_DEPS} ${BACK_ART_DEPS} ${BACK_ART_RUN_DEPS} ${FRAMEWORKS_RUN_DEPS} \
                   ${FRAMEWORKS_BUILD_DEPS} ${APPS_BUILD_DEPS} ${APPS_RUN_DEPS} 2>&1 > /dev/null
fi

$ECHO -e "\e[32m Done! \e[0m"

#===============================================================================
# Extract distribution
#===============================================================================
$ECHO -e "\e[1m"
$ECHO "========================================================================="
$ECHO "Installing NextSpace..."
$ECHO "========================================================================="
$ECHO -e -n "\e[0m"
DIR="$(cd "$(dirname "$0")" && pwd)"

"$DIR/0_build_libdispatch.sh" && \
"$DIR/1_build_libcorefoundation.sh" && \
"$DIR/2_build_libobjc2.sh" && \
"$DIR/3_build_core.sh" && \
"$DIR/3_build_tools-make.sh" && \
"$DIR/4_build_libwraster.sh" && \
"$DIR/5_build_libs-base.sh" && \
"$DIR/6_build_libs-gui.sh" && \
"$DIR/7_build_libs-back.sh" && \
"$DIR/8_build_Frameworks.sh" && \
"$DIR/9_build_Applications.sh"

$ECHO -e "\e[32m Done! \e[0m"

#===============================================================================
# More X drivers. Workaround until NextSpace RPMs include them as dependencies
#===============================================================================
$ECHO -e "\e[1m"
$ECHO "========================================================================="
$ECHO "Installing X11 drivers and utilities..."
$ECHO "========================================================================="
$ECHO -e -n "\e[0m"
if [ ${OS_ID} = "debian" ] || [ ${OS_ID} = "ubuntu" ]; then
   sudo apt-get -y install xserver-xorg-input-all xserver-xorg-video-all 2>&1 > /dev/null
fi
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
    sudo systemctl enable /usr/NextSpace/lib/systemd/loginwindow.service
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
