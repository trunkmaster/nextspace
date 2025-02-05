#!/bin/sh

. ../environment.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Post install
#----------------------------------------

### Set at 11th stage because We need to have .xinitrc set before lauchning graphical.target...

if ! [ -f $HOME/.xinitrc ];then
	${ECHO} "Please, execute 10th stage before this:\n'./10_setup_user_home.sh'\nwith and then without sudo.\n"
	exit 1
fi

if [ "$DEST_DIR" = "" ] && [ "$GITHUB_ACTIONS" != "true" ];then
	# Login with a display manager
	if [ ${OS_ID} = "debian" ] && [ ${MACHINE} = "aarch64" ];then
		### Need to install xdm Login Manager to avoid Login.app issue
		sudo apt-get install -y xdm
		# XDM needs .xsessionrc
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
