#!/bin/sh

. ../environment.sh

#----------------------------------------
# Install system configuration files
#----------------------------------------
CORE_SOURCES=${PROJECT_DIR}/Core/os_files

# /.hidden
$CP_CMD ${CORE_SOURCES}/dot_hidden /.hidden

# Preferences
$MKDIR_CMD $DEST_DIR/Library/Preferences
$CP_CMD ${CORE_SOURCES}/Library/Preferences/* $DEST_DIR/Library/Preferences/

# Linker cache
if ! [ -d $DEST_DIR/etc/ld.so.conf.d ];then
	$MKDIR_CMD -v $DEST_DIR/etc/ld.so.conf.d
fi
$CP_CMD -v ${CORE_SOURCES}/etc/ld.so.conf.d/nextspace.conf $DEST_DIR/etc/ld.so.conf.d/
sudo ldconfig

# X11
#if ! [ -d $DEST_DIR/etc/X11/xorg.conf.d ];then
#	$MKDIR_CMD -v $DEST_DIR/etc/X11/xorg.conf.d
#fi
#$CP_CMD ${CORE_SOURCES}/etc/X11/xorg.conf.d/*.conf $DEST_DIR/etc/X11/xorg.conf.d/
$CP_CMD ${CORE_SOURCES}/etc/X11/Xresources.nextspace $DEST_DIR/etc/X11

# PolKit & udev
if ! [ -d $DEST_DIR/etc/polkit-1/rules.d ];then
	$MKDIR_CMD -v $DEST_DIR/etc/polkit-1/rules.d
fi
$CP_CMD ${CORE_SOURCES}/etc/polkit-1/rules.d/*.rules $DEST_DIR/etc/polkit-1/rules.d/
if ! [ -d $DEST_DIR/etc/udev/rules.d ];then
	$MKDIR_CMD -v $DEST_DIR/etc/udev/rules.d
fi
$CP_CMD ${CORE_SOURCES}/etc/udev/rules.d/*.rules $DEST_DIR/etc/udev/rules.d/

# User environment
if ! [ -d $DEST_DIR/etc/profile.d ];then
	$MKDIR_CMD -v $DEST_DIR/etc/profile.d
fi
$CP_CMD ${CORE_SOURCES}/etc/profile.d/nextspace.sh $DEST_DIR/etc/profile.d/

if ! [ -d $DEST_DIR/etc/skel ];then
	$MKDIR_CMD -v $DEST_DIR/etc/skel
fi
$CP_CMD ${CORE_SOURCES}/etc/skel/Library $DEST_DIR/etc/skel/
$CP_CMD ${CORE_SOURCES}/etc/skel/.config $DEST_DIR/etc/skel/
$CP_CMD ${CORE_SOURCES}/etc/skel/.emacs.d $DEST_DIR/etc/skel/
$CP_CMD ${CORE_SOURCES}/etc/skel/.gtkrc-2.0 $DEST_DIR/etc/skel/
$CP_CMD ${CORE_SOURCES}/etc/skel/.*.nextspace $DEST_DIR/etc/skel/

# /root
$CP_CMD ${CORE_SOURCES}/etc/skel/.config /root
$CP_CMD ${CORE_SOURCES}/etc/skel/Library /root

# Scripts
if ! [ -d $DEST_DIR/usr/NextSpace/bin ];then
	$MKDIR_CMD -v $DEST_DIR/usr/NextSpace/bin
fi
$CP_CMD ${CORE_SOURCES}/usr/NextSpace/bin/* $DEST_DIR/usr/NextSpace/bin/

# Icons, Plymouth resources and fontconfig configuration
if ! [ -d $DEST_DIR/usr/share ];then
	$MKDIR_CMD -v $DEST_DIR/usr/share
fi
$CP_CMD ${CORE_SOURCES}/usr/share/* $DEST_DIR/usr/share/
