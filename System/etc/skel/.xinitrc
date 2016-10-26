#!/bin/sh

##############################################################################
### Environment variables
##############################################################################
. /etc/profile.d/nextspace.sh

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
### $LOGFILE, $NS_SYSTEM is defined in /etc/profile.d/nextspace.sh
##############################################################################
# Should be systemd --user controlled services
printf "Starting GNUstep services:" >> $LOGFILE  2>&1
$NS_SYSTEM/bin/gnustep-services start >> $LOGFILE  2>&1
printf ".\n" >> $LOGFILE  2>&1

export GNUSTEP_USER_ROOT=$HOME/Library
$NS_SYSTEM/Apps/Workspace.app/Workspace >> $LOGFILE  2>&1

printf "Stopping GNUstep services:"
$NS_SYSTEM/bin/gnustep-services stop >> $LOGFILE  2>&1
printf ".\n" >> $LOGFILE  2>&1

#exit 0
