#!/bin/sh

##############################################################################
### Prepare log file location
##############################################################################
GS_SECURE="/tmp/GNUstepSecure`id -u`/"
LOG_FILE="$GS_SECURE/console.log"

if [ ! -d $GS_SECURE ];then
  mkdir $GS_SECURE
fi

##############################################################################
### Environment variables
##############################################################################
. /usr/NextSpace/etc/profile > $LOG_FILE  2>&1

##############################################################################
### Xorg settings
##############################################################################
# Layouts -> NXKeyboard
# On CentOS it's set at system level by command:
#    localectl --no-convert set-x11-keymap us,ru,ua pc104 pc104 grp:ctrl_shift_toggle,compose:rsuper
#setxkbmap -option "grp:ctrl_shift_toggle,compose:rsuper" -layout "us,ru,ua"
xrdb -merge /etc/X11/Xresources

# Mouse acceleration -> NXMouse
xset m 20/10 4
# Keyboard repeat rate -> NXKeyboard
xset r rate 200 40

##############################################################################
### Session
##############################################################################
# Should be systemd --user controlled services
printf "Starting GNUstep services:" >> $LOG_FILE  2>&1
/usr/NextSpace/etc/rc.d/GNUstep start >> $LOG_FILE  2>&1
printf ".\n" >> $LOG_FILE  2>&1

export GNUSTEP_USER_ROOT=$HOME/Library
/usr/NextSpace/Apps/Workspace.app/Workspace >> $LOG_FILE  2>&1

printf "Stopping GNUstep services:"
/usr/NextSpace/etc/rc.d/GNUstep stop >> $LOG_FILE  2>&1
printf ".\n" >> $LOG_FILE  2>&1

#exit 0
