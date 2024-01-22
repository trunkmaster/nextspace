#!/bin/sh

echo "Copying initial settings from $PWD/home"
if [ -d "$HOME/Library" ];then
	echo "$HOME/Library exists already, please make sure it is up to date"
else
	cp -R /etc/skel/Library $HOME/
fi

cp -Rn /etc/skel/.config $HOME/

if [ -f "$HOME/.xinitrc" ];then
	echo "$HOME/.xinitrc exists already, will not overwrite!"
else
	cp ./extra/xinitrc $HOME/.xinitrc
fi
