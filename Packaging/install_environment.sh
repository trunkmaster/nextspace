#!/bin/sh

ECHO="/bin/echo"
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
    fi
}

setup_loginwindow()
{
    # Default boot target
    $ECHO -e -n "\e[33m"
    $ECHO -n "Start graphical login panel on system boot? [y/N]: "
    $ECHO -e -n "\e[0m"
    read YN
    if [ "$YN" = "y" ]; then
        sudo systemctl set-default graphical.target
    fi

    # Start it now
    $ECHO -e -n "\e[33m"
    $ECHO -n "Do you want to start graphical login panel now? [y/N]: "
    $ECHO -e -n "\e[0m"
    read YN
    if [ "$YN" = "y" ]; then
        sudo systemctl start loginwindow
    fi
}