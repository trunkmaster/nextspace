#!/bin/bash

if [ "$EUID" -eq 0 ];then
	mkdir -p /Library/Preferences
	cp ../../System/Library/Preferences/* /Library/Preferences/

	cp ../../System/etc/ld.so.conf.d/nextspace.conf /etc/ld.so.conf.d/
	ldconfig

	cp ../../System/etc/X11/Xresources.nextspace /etc/X11

	cp ../../System/etc/profile.d/nextspace.sh /etc/profile.d

	cp -R ../../System/etc/skel/Library /etc/skel

	cp ../../System/usr/NextSpace/bin/* /usr/NextSpace/bin/

	cp -R ../../System/usr/share/* /usr/share/
fi

echo "copying initial settings from $PWD/home"
if [ -d "$HOME/Library" ];then
	echo "$HOME/Library exists already, please make sure it is up to date"
else
	cp -R /etc/skel/Library  $HOME/
fi
if [ -f "$HOME/.xinitrc" ];then
	echo "$HOME/.xinitrc exists already, will not overwrite"
else
	cp ./copy_to_users_home/.xinitrc $HOME/
fi
