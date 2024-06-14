#!/bin/sh

. ./versions.inc.sh

if [ ${OS_NAME} = "debian" ] || [ ${OS_NAME} = "ubuntu" ]; then
    sudo systemctl stop loginwindow gpbs gdnc-local gdnc  gdomap 
    sudo systemctl disable loginwindow gdomap gdnc gpbs gdnc-local
else
    sudo yum remove nextspace* -y
    sudo yum remove libwraster* -y
    sudo yum remove libobjc2* -y
    sudo yum remove libcorefoundation* -y
    sudo yum remove libdispatch* -y
fi

sudo rm -rf /etc/profile.d/nextspace.sh
sudo rm -rf /usr/share/icons/NextSpace
sudo rm -rf /usr/share/plymouth/themes/nextspace
sudo rm -rf /usr/share/plymouth/themes/plymouth-preview
sudo rm -rf /usr/NextSpace
sudo rm -rf /Applications
sudo rm -rf /Developer
sudo rm -rf /Library

