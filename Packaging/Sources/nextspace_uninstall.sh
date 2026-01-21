#!/bin/sh

clear
/bin/echo -e -n "\e[1m"
/bin/echo "==============================================================================="
/bin/echo "This script will REMOVE NextSpace"
/bin/echo "==============================================================================="
/bin/echo -e -n "\e[33m"
/bin/echo -n "Do you want to continue? [y/N]: "
/bin/echo -e -n "\e[0m"
read YN
if [ "$YN" != "y" ]; then
    /bin/echo "Great! I hope you enjoyed using NextSpace."
    exit
fi

sudo systemctl stop loginwindow gpbs gdnc-local gdnc  gdomap 
sudo systemctl disable loginwindow gdomap gdnc gpbs gdnc-local

sudo rm -rf /etc/X11/Xresources.nextspace
sudo rm -rf /etc/polkit-1/rules.d/10-udisks2.rules
sudo rm -rf /etc/ld.so.conf.d/nextspace.conf
sudo rm -rf /etc/skel/Library/.zsh.nextspace
sudo rm -rf /etc/skel/Library/.gtkrc-2.0
sudo rm -rf /etc/skel/.config/gtk-3.0
sudo rm -rf /etc/skel/.config/pulse
sudo rm -rf /etc/udev/rules.d/99-udisks2.rules
sudo rm -rf /etc/profile.d/nextspace.sh

sudo rm -rf /usr/share/icons/NextSpace
sudo rm -rf /usr/share/plymouth/themes/nextspace
sudo rm -rf /usr/share/plymouth/themes/plymouth-preview

sudo rm -rf /usr/NextSpace
sudo rm -rf /Applications
sudo rm -rf /Developer
sudo rm -rf /Library
sudo rm -rf /.hidden

