#!/bin/sh

ECHO="printf %b\n"
ECHO_N="printf %b"
MKDIR_CMD="sudo mkdir -p"
RM_CMD="sudo rm"
LN_CMD="sudo ln -sf"
MV_CMD="sudo mv -v"
CP_CMD="sudo cp -R"

RELEASE=0.95

#=========================================================================
# SELinux setup
#=========================================================================
setup_selinux()
{
    if ! command -v getenforce >/dev/null 2>&1; then
        $ECHO "SELinux tools were not found; skipping SELinux configuration."
        return
    fi

    $ECHO_N "\033[1m"
    $ECHO "========================================================================="
    $ECHO "SELinux configuration"
    $ECHO "========================================================================="
    $ECHO_N "\033[0m"
    SELINUX_MODE=$(getenforce)

    $ECHO_N "\033[1m"
    $ECHO "Current SELinux mode is ${SELINUX_MODE}"
    $ECHO_N "\033[0m"
    $ECHO_N "\033[33m"
        $ECHO_N "Do you want to change your SELinux configuration? [y/N]: "
    $ECHO_N "\033[0m"
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
        $ECHO_N "\033[1m"
        $ECHO_N "SELinux mode [default: 1]: "
        $ECHO_N "\033[0m"
        read SEL
        $ECHO_N "Setting SELinux default mode to "
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
        $ECHO_N "Checking /etc/hosts..."
    HOSTNAME="`hostname -s`"
    grep "$HOSTNAME" /etc/hosts 2>&1 > /dev/null
    if [ $? -eq 1 ];then
        if [ "$HOSTNAME" != "`hostname`" ];then
            HOSTNAME="$HOSTNAME `hostname`"
        fi
        $ECHO_N "\033[33m"
        $ECHO "configuring needed"
        $ECHO_N "\033[0m"
        $ECHO "Configuring hostname ($HOSTNAME)..."
        if grep "localhost4.localdomain4" /etc/hosts >/dev/null 2>&1; then
            sudo sed -i 's/localhost4.localdomain4/localhost4.localdomain4 '"$HOSTNAME"'/g' /etc/hosts
        else
            echo "127.0.1.1 $HOSTNAME" | sudo tee -a /etc/hosts >/dev/null
        fi
    else
        $ECHO_N "\033[32m"
        $ECHO "good"
        $ECHO_N "\033[0m"
    fi
}

add_user()
{
    $ECHO_N "\033[33m"
        $ECHO_N "Do you want to add user? [y/N]: "
    $ECHO_N "\033[0m"
    read YN
    if [ "$YN" = "y" ]; then
        $ECHO_N "Please enter username: "
        read USERNAME
        $ECHO "Adding username $USERNAME"
        EXTRA_GROUPS="audio"
        if getent group wheel >/dev/null 2>&1; then
            EXTRA_GROUPS="${EXTRA_GROUPS},wheel"
        elif getent group sudo >/dev/null 2>&1; then
            EXTRA_GROUPS="${EXTRA_GROUPS},sudo"
        fi
        sudo useradd -m -b /Users -s /bin/zsh -G "$EXTRA_GROUPS" "$USERNAME"
        $ECHO "Setting up password..."
        sudo passwd "$USERNAME"
        if command -v semodule >/dev/null 2>&1 && command -v restorecon >/dev/null 2>&1; then
            $ECHO "Updating SELinux file contexts..."
            ## Needed to update the filesystem contexts that depend on HOME_DIR, and wrongly assume /home
            sudo semodule -e ns-core  2>&1 > /dev/null
            sudo restorecon -R /Users 2>&1 > /dev/null
        fi
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

    $ECHO "========================================================================="
    $ECHO "Configuring graphical login panel..."
    $ECHO "========================================================================="
    if [ -n "$DM_UNIT_FILE" ]; then
        $ECHO "You already have configured graphical login manager:"
        $ECHO "    $DESC - $DM_UNIT"
        PROMPT="Replace it with NEXTSPACE login panel? [y/N]: "
    else
        $ECHO "No graphical login manager symlink was found."
        PROMPT="Enable NEXTSPACE login panel? [y/N]: "
    fi

        $ECHO_N "$PROMPT"
    read YN
    if [ "$YN" = "y" ]; then
        if [ -n "$DM_UNIT_FILE" ]; then
            sudo systemctl disable "$DM_UNIT_FILE"
        fi
        sudo systemctl enable /usr/NextSpace/lib/systemd/loginwindow.service
        IS_CONFIGURED=1
    else
        $ECHO "Your answer is 'No'. Got it."
        $ECHO "You may later enable NEXTSPACE login panel with commands:"
        if [ -n "$DM_UNIT_FILE" ]; then
            $ECHO "    $ sudo systemctl disable $DM_UNIT_FILE"
        fi
        $ECHO "    $ sudo systemctl enable /usr/NextSpace/lib/systemd/loginwindow.service"
    fi
    $ECHO "To return to your current setup after that use the following commands:"
    $ECHO "    $ sudo systemctl disable loginwindow.service"
    if [ -n "$DM_UNIT" ]; then
        $ECHO "    $ sudo systemctl enable $DM_UNIT"
    fi

    if [ $IS_CONFIGURED = 1 ]; then
        # Default boot target
        $ECHO_N "\033[33m"
        $ECHO_N "Start graphical login panel on system boot? [y/N]: "
        $ECHO_N "\033[0m"
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
        $ECHO_N "\033[33m"
        $ECHO_N "Do you want to start graphical login panel now? [y/N]: "
        $ECHO_N "\033[0m"
        read YN
        if [ "$YN" = "y" ]; then
            sudo systemctl start loginwindow
        else
            $ECHO "Got it. You may start login panel with command:"
            $ECHO "    $ sudo systemctl start loginwindow"
        fi
    fi
}
