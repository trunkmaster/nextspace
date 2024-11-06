#!/bin/sh

ECHO="/bin/echo -e"
MKDIR_CMD="sudo mkdir -p"
RM_CMD="sudo rm"
LN_CMD="sudo ln -sf"
MV_CMD="sudo mv -v"
CP_CMD="sudo cp -R"

RELEASE=0.95

#===============================================================================
# SELinux setup
#===============================================================================
setup_selinux()
{
    $ECHO -e -n "\e[1m"
    $ECHO "==============================================================================="
    $ECHO "SELinux configuration"
    $ECHO "==============================================================================="
    $ECHO -e -n "\e[0m"
    SELINUX_MODE=$(getenforce)

    $ECHO -e -n "\e[1m"
    $ECHO "Current SELinux mode is ${SELINUX_MODE}"
    $ECHO -e -n "\e[0m"
    $ECHO -e -n "\e[33m"
    $ECHO -n "Do you want to change your SELinux configuration? [y/N]: "
    $ECHO -e -n "\e[0m"
    read YN

    if [ "$YN" = "y" ]; then
        $ECHO
        $ECHO "Please choose the default SELinux mode"
        $ECHO
        $ECHO " 1) Permissive: SELinux will be active but will only log policy violations"
        $ECHO "                instead of enforcing them (default for NEXTSPACE)."
        $ECHO " 2) Enforcing: SELinux will enforce the loaded policies and actively block"
        $ECHO "               access attempts which are not allowed (distro default)."
        $ECHO " 3) Disabled: the SELinux subsystem will be disabled (choose this one if you" 
        $ECHO "              have a strong reason for it)."
        $ECHO
        $ECHO "The recommended (and default) option is \"Permissive\", which will prevent "
        $ECHO "'SELinux from blocking accesses while logging them."
        $ECHO "Choose \"Enforcing\" if you want or need to keep SELinux active, this will "
        $ECHO "use the NEXTSPACE policies; keep in mind that they are a work in progress."
        $ECHO "You can also choose to completely disable the SELinux subsystem; this should "
        $ECHO "functionally be similar to \"Permissive\" but will not log anything."
        $ECHO
        $ECHO "Filesystem with undergo automatic relabelling upon reboot for \"Permissive\" "
        $ECHO "and \"Enforcing\" policies".
        $ECHO
        $ECHO -e -n "\e[1m"
        $ECHO -n "SELinux mode [default: 1]: "
        $ECHO -e -n "\e[0m"
        read SEL
        $ECHO -n "Setting SELinux default mode to "
        if [ "$SEL" = 2 ]; then
            $ECHO Enforcing...
            sudo sed -i -e ' s/SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
            sudo touch /.autorelabel
        elif [ "$SEL" = 3 ]; then
            $ECHO Disabled...
            sudo sed -i -e ' s/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        else
            $ECHO Permissive...
            sudo sed -i -e ' s/SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
            sudo touch /.autorelabel
        fi
        $ECHO "Done!"
        # TODO: $ECHO -n "Installing NEXTSPACE SELinux policies..."
    fi
}

setup_hosts()
{
    $ECHO -n "Checking /etc/hosts..."
    HOSTNAME="`hostname -s`"
    grep "$HOSTNAME" /etc/hosts 2>&1 > /dev/null
    if [ $? -eq 1 ];then
        if [ $HOSTNAME != `hostname` ];then
            HOSTNAME="$HOSTNAME `hostname`"
        fi
        $ECHO -e -n "\e[33m"
        $ECHO "configuring needed"
        $ECHO -e -n "\e[0m"
        $ECHO "Configuring hostname ($HOSTNAME)..."
        sed -i 's/localhost4.localdomain4/localhost4.localdomain4 '"$HOSTNAME"'/g' /etc/hosts
    else
        $ECHO -e -n "\e[32m"
        $ECHO "good"
        $ECHO -e -n "\e[0m"
    fi
}

add_user()
{
    $ECHO -e -n "\e[33m"
    $ECHO -n "Do you want to add user? [y/N]: "
    $ECHO -e -n "\e[0m"
    read YN
    if [ "$YN" = "y" ]; then
        $ECHO -n "Please enter username: "
        read USERNAME
        $ECHO "Adding username $USERNAME"
        sudo adduser -b /Users -s /bin/zsh -G audio,wheel $USERNAME
        $ECHO "Setting up password..."
        sudo passwd $USERNAME
        $ECHO "Updating SELinux file contexts..."
        ## Needed to update the filesystem contexts that depend on HOME_DIR, and wrongly assume /home
        sudo semodule -e ns-core  2>&1 > /dev/null
        sudo restorecon -R /Users 2>&1 > /dev/null
    else
        HAS_AUDIO=`groups | grep audio`
        if [ "$HAS_AUDIO" = "" ]; then
            $ECHO "WARNING: User you're running this script as is not member of 'audio' group - sound will not work."
            $ECHO "         Consider adding user to group with command:"
            $ECHO "         $ sudo usermod $USER -a -G audio"
        fi
    fi
}

setup_loginwindow()
{
    IS_CONFIGURED=0

    if [ -f /etc/systemd/system/display-manager.service ]; then
        DESC=`cat /etc/systemd/system/display-manager.service | grep Description | awk -F= '{print $2}'`
        DM_UNIT=`readlink -f /etc/systemd/system/display-manager.service`
        DM_UNIT_FILE=`basename $DM_UNIT`
        if [ "$DM_UNIT_FILE" = "loginwindow.service" ]; then
            IS_CONFIGURED=1
        fi
    fi
    if [ $IS_CONFIGURED = 1 ]; then
        return
    fi

    $ECHO "==============================================================================="
    $ECHO "Configuring graphical login panel..."
    $ECHO "==============================================================================="
    $ECHO "You already have configured graphical login manager:"
    $ECHO "    $DESC - $DM_UNIT"

    $ECHO -n "Replace it with NEXTSPACE login panel? [y/N]: "
    read YN
    if [ "$YN" = "y" ]; then
        sudo systemctl disable $DM_UNIT_FILE
        sudo systemctl enable /usr/NextSpace/Apps/Login.app/Resources/loginwindow.service
        IS_CONFIGURED=1
    else
        $ECHO "Your answer is 'No'. Got it."
        $ECHO "You may later enable NEXTSPACE login panel with commands:"
        $ECHO "    $ sudo systemctl disable $DM_UNIT_FILE"
        $ECHO "    $ sudo systemctl enable /usr/NextSpace/Apps/Login.app/Resources/loginwindow.service"
        $ECHO "To return to your current setup after that use the following commands:"
        $ECHO "    $ sudo systemctl disable loginwindow.service"
        $ECHO "    $ sudo systemctl enable $DM_UNIT"
    fi

    if [ $IS_CONFIGURED = 1 ]; then
        # Default boot target
        $ECHO -e -n "\e[33m"
        $ECHO -n "Start graphical login panel on system boot? [y/N]: "
        $ECHO -e -n "\e[0m"
        read YN
        if [ "$YN" = "y" ]; then
            sudo systemctl set-default graphical.target
        else
            $ECHO "Got it. You may change it later with command:"
            $ECHO "$ sudo systemctl set-default graphical.target"
        fi
    fi

    if [ $IS_CONFIGURED = 1 ]; then
        # Start it now
        $ECHO -e -n "\e[33m"
        $ECHO -n "Do you want to start graphical login panel now? [y/N]: "
        $ECHO -e -n "\e[0m"
        read YN
        if [ "$YN" = "y" ]; then
            sudo systemctl start loginwindow
        else
            $ECHO "Got it. You may start login panel with command:"
            $ECHO "    $ sudo systemctl start loginwindow"
        fi
    fi
}
