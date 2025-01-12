#!/bin/sh

. ../environment.sh


echo "Copying initial settings from $PWD/home"
if [ -d "$HOME/Library" ];then
	echo "$HOME/Library exists already, please make sure it is up to date"
else
	cp -R /etc/skel/Library $HOME/
fi

cp -Rn /etc/skel/.config $HOME/

if [ ${OS_ID} = "debian" ] || [ ${ID_OS} = "ubuntu" ];then
	${ECHO} "${OS_ID} specific 'xsessionrc' is needed."
	if [ -f "$HOME/.xsessionrc" ];then
		echo "$HOME/.xsessionrc exists already, will not overwrite!"
	else
		cp ./extra/xsessionrc $HOME/.xsessionrc
	fi
else
	if [ -f "$HOME/.xinitrc" ];then
		echo "$HOME/.xinitrc exists already, will not overwrite!"
	else
		cp ./extra/xinitrc $HOME/.xinitrc
	fi
fi
