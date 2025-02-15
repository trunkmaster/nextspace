#!/bin/sh

. ../environment.sh
. /etc/profile.d/nextspace.sh
. ../install_environment.sh

clear

if [ -f /proc/device-tree/model ]; then
	MODEL=`cat /proc/device-tree/model | awk '{print $1}'`
else
	MODEL="unknown"
fi

#----------------------------------------
# Setup Display Manager
#----------------------------------------

### Set at 11th stage because We need to have .xinitrc set before lauchning graphical.target...

if ! [ -f $HOME/.xinitrc ]; then
	${ECHO} "Please, execute first:\n'./setup_user_home.sh'\nwith and then without sudo.\n"
	exit 1
fi

# Login with a display manager

if [ -z "$1" ]; then
	${ECHO} "You must select a Display Manager:"
	${ECHO} "${0} <option>"
	${ECHO} "\t--with-Login_dot_app : install Login.app, the NeXTspace Display Manager"
	${ECHO} "\t--with-WDM : install a workaround, Wings Display Manager"
	exit 1
else
	ARG="$1"
fi

PATH_X11_CONF_FILES="../../Core/os_files/etc/X11/xorg.conf.d"
TARGET_X11="/etc/X11/xorg.conf.d/"

if [ -f ${PATH_X11_CONF_FILES}/screen.resolution.conf ]; then
	if ! [ -f ${TARGET_X11}/screen.resolution.conf ]; then
		sudo cp ${PATH_X11_CONF_FILES}/screen.resolution.conf ${TARGET_X11}
	fi
fi

if [ "${MACHINE}" = "aarch64" ] && [ "${MODEL}" = "Raspberry" ]; then
	if [ -f ${TARGET_X11}/20-intel.conf ]; then
        	sudo rm ${TARGET_X11}/20-intel.conf
	fi
fi

if [ "${ARG}" = "--with-Login_dot_app" ]; then
	${ECHO} "'Login.app' will be setup as your default Display Manager..."

	$ECHO -n "Checking for Login panel: "
	systemctl is-enabled loginwindow
	if [ $? -ne 0 ];then
    		$ECHO "Enabling Login panel service..."
    		sudo systemctl enable /usr/NextSpace/Apps/Login.app/Resources/loginwindow.service
	fi

	# Setting up Login Panel
	setup_loginwindow
else
	if [ "${ARG}" = "--with-WDM" ]; then
		${ECHO} "Installing Wdm Display Manager to avoid Login.app issue..."
		sudo apt-get install -y wdm
	fi
fi

### We need .xsessionrc under debian or else .xession 
if [ ${OS_ID} = "debian" ] || [ ${OS_ID} = "ubuntu" ]; then
	cp $HOME/.xinitrc $HOME/.xsessionrc
else
	cp $HOME/.xinitrc $HOME/.xsession
fi

sudo systemctl set-default graphical.target
