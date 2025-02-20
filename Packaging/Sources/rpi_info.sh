#!/bin/sh

#---------------------------------------
# Inform about the RPI flickering issue
#---------------------------------------

if [ -z "${ECHO}" ];then
	ECHO="/usr/bin/echo -e"
fi

if [ -z "$_PWD" ];then
	${ECHO} "You should not run the script $0 by itself."
	exit 1
fi

${ECHO} "============================================="
${ECHO} "The current computer is a ${MODEL} with a VideoCore 3D unit GPU."
${ECHO} "It could happen that your HD display might flicker."
${ECHO} "Do NOT reboot until You tested the 'Workspace' load..."

if ! [ -f $HOME/.xinitrc ];then
	${ECHO} "---"
	${ECHO} "But You must set up the user home before:"
	${ECHO} "\t sudo ./setup_user.sh"
	${ECHO} "\t ./setup_user.sh"
	${ECHO} "---"
fi

${ECHO} "Then, let's run this test:"
${ECHO} "\t cd && startx"

${ECHO} "---"
${ECHO} "If it is NOT ok, open the 'Preferences' (clock icon) "
${ECHO} " and try a lower resolution for the display in the tab"
${ECHO} "'Display Preferences'. Note it, logout, "
${ECHO} "\t cd ${_PWD}/extra/RPI_RESOURCES"
${ECHO} "edit and adapt the 'screen-resolution.conf',"
${ECHO} "Then copy it into the '/etc/X11/xorg.conf.d' folder."
${ECHO} "---"
${ECHO} "Test again with 'startx'. If it is OK now,"
${ECHO} "============================================="

${ECHO} "You need to reboot to use the Login Panel."
