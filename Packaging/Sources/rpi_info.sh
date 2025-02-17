#!/bin/sh

#---------------------------------------
# Inform about the RPI flickering issue
#---------------------------------------

ECHO="echo -e"

MACHINE=`uname -m`
if [ -f /proc/device-tree/model ];then
	MODEL=`cat /proc/device-tree/model | awk '{print $1}'`
else
	MODEL="unkown"
fi
if [ -f /proc/device-tree/compatible ];then
	GPU=`tr -d '\0' < /proc/device-tree/compatible | awk -F, '{print $3}'`
else
	GPU="unknown"
fi

if [ "$MACHINE" = "aarch64" ] && [ "$MODEL" = "Raspberry" ] && [ "$GPU" = "bcm2711" ];then
	clear
	PWD=`pwd`
	${ECHO} "The current computer is a ${MODEL} with a VideoCore 3D unit GPU."
	${ECHO} "It could happen that your HD display might flicker."
	${ECHO} "Do NOT reboot until You tested the 'Workspace' load..."

	if ! [ -f $HOME/.xinitrc ];then
		${ECHO} "But You must set up the user home before:"
		${ECHO} "\t sudo ./setup_user.sh"
		${ECHO} "\t ./setup_user.sh"
	fi

	${ECHO} "And then the test:"
	${ECHO} "\t cd && startx"

	${ECHO}
	${ECHO} "If it is NOT ok, open the 'Preferences' (clock icon) "
	${ECHO} " and try a lower resolution for the display. Note it, logout, "
	${ECHO} "\t cd ${PWD}/extra/RPI_RESOURCES"
	${ECHO} "edit and adapt the 'screen-resolution.conf',"
	${ECHO} "Then copy it to '/etc/X11/xorg.conf.d' folder."
	${ECHO}
	${ECHO} "Test again with 'startx'. If it is OK now,"
fi

${ECHO} "You need to reboot to use the Login Panel."
