#!/bin/sh

. ../environment.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Post install: display manager...
#----------------------------------------

### Set at 11th stage because We need to have .xinitrc set before launching graphical.target...

if ! [ -f $HOME/.xinitrc ];then
	${ECHO} "Please, execute 10th stage before this:\n'./setup_user_home.sh'\nwith and then without sudo.\n"
	exit 1
fi


### Hardware infos: about arm 64
if [ ${MACHINE} = "aarch64" ];then
	if [ -f /proc/device-tree/compatible ];then
		_MODEL=`awk -F, '{print $1}' /proc/device-tree/compatible`
		_GPU=$(tr -d '\0' < /proc/device-tree/compatible | awk -F, '{print $3}')
	else
		${ECHO} "This arm 64 (aarch64) computer has not yet been tested. Please, let us know..."
	fi
fi


if [ "$DEST_DIR" = "" ] && [ "$GITHUB_ACTIONS" != "true" ];then
	# Login with a display manager

	if [ "$_MODEL" = "raspberrypi" ] && [ "$_GPU" = "bcm2711" ];then
		${ECHO} "This hardware is a Raspberry Pi with a VideoCore VI 3D unit."
		${ECHO} "Until now, You cannot use Login.app as the default Display Manager."
		${ECHO} "So we install XDM..."

		if [ "${OS_ID}" = "debian" ];then
			sudo apt-get install -y xdm
		fi
		if [ "${OS_ID}" = "ultramarine" ];then
			sudo dnf install -y xorg-x11-xdm
		fi

		# XDM needs .xsessionrc and we have to set a compatible resolution to the Workspace
		sudo dnf install xrandr || exit 1
		#echo "xrandr --auto" > $HOME/.xsessionrc
		cp $HOME/.xinitrc $HOME/.xsessionrc

	else
		${ECHO} "Setting up Login window service to run at system startup..."
		sudo systemctl enable /usr/NextSpace/Apps/Login.app/Resources/loginwindow.service
	fi
	sudo systemctl set-default graphical.target

	# SELinux
	if [ -f /etc/selinux/config ]; then
		SELINUX_STATE=`grep "^SELINUX=.*" /etc/selinux/config | awk -F= '{print $2}'`
		if [ "${SELINUX_STATE}" != "disabled" ]; then
			${ECHO} -n "SELinux enabled - dissabling it..."
			sudo sed -i -e ' s/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
			${ECHO} "done"
			${ECHO} "Please reboot to apply changes."
		fi
	fi
fi
