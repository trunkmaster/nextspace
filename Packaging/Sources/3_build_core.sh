#!/bin/sh

. ../environment.sh

#----------------------------------------
# Install system configuration files
#----------------------------------------
CORE_SOURCES=${PROJECT_DIR}/OS/Linux

# /.hidden
$CP_CMD ${CORE_SOURCES}/dot_hidden /.hidden

# Preferences
#$MKDIR_CMD $DEST_DIR/Library/Preferences
#$CP_CMD ${CORE_SOURCES}/Library/Preferences/* $DEST_DIR/Library/Preferences/

# Linker cache
if [ ${OS_ID} = "freebsd" ]; then
	sudo sed "s|/usr/NextSpace|${NEXTSPACE_PREFIX}|g" ${CORE_SOURCES}/etc/ld.so.conf.d/nextspace.conf >> /etc/ld-elf.so.conf
else
	if ! [ -d $DEST_DIR/etc/ld.so.conf.d ];then
		$MKDIR_CMD -v $DEST_DIR/etc/ld.so.conf.d
	fi
	$CP_CMD -v ${CORE_SOURCES}/etc/ld.so.conf.d/nextspace.conf $DEST_DIR/etc/ld.so.conf.d/

	# X11
	#if ! [ -d $DEST_DIR/etc/X11/xorg.conf.d ];then
	#	$MKDIR_CMD -v $DEST_DIR/etc/X11/xorg.conf.d
	#fi
	#$CP_CMD ${CORE_SOURCES}/etc/X11/xorg.conf.d/*.conf $DEST_DIR/etc/X11/xorg.conf.d/
	$CP_CMD ${CORE_SOURCES}/etc/X11/Xresources.nextspace $DEST_DIR/etc/X11

fi
sudo ldconfig


# User environment
if ! [ -d $DEST_DIR/etc/profile.d ];then
	$MKDIR_CMD -v $DEST_DIR/etc/profile.d
fi
if [ ${OS_ID} = "freebsd" ]; then
	# The profile script hardcodes /usr/NextSpace; rewrite it to the FreeBSD
	# prefix for the copy actually installed. The source file is left
	# untouched for other platforms.
	sed "s|/usr/NextSpace|${NEXTSPACE_PREFIX}|g" ${CORE_SOURCES}/etc/profile.d/nextspace.sh > /tmp/nextspace.sh.$$
	$CP_CMD /tmp/nextspace.sh.$$ $DEST_DIR/etc/profile.d/nextspace.sh
	rm -f /tmp/nextspace.sh.$$
else
	$CP_CMD ${CORE_SOURCES}/etc/profile.d/nextspace.sh $DEST_DIR/etc/profile.d/
fi

if ! [ -d $DEST_DIR/etc/skel ];then
	$MKDIR_CMD -v $DEST_DIR/etc/skel
fi
$CP_CMD ${CORE_SOURCES}/etc/skel/Library $DEST_DIR/etc/skel/
$CP_CMD ${CORE_SOURCES}/etc/skel/.config $DEST_DIR/etc/skel/
$CP_CMD ${CORE_SOURCES}/etc/skel/.gtkrc-2.0 $DEST_DIR/etc/skel/
$CP_CMD ${CORE_SOURCES}/etc/skel/.*.nextspace $DEST_DIR/etc/skel/

# /root
$CP_CMD ${CORE_SOURCES}/etc/skel/.config /root
$CP_CMD ${CORE_SOURCES}/etc/skel/Library /root

# Scripts
if ! [ -d $DEST_DIR${NEXTSPACE_PREFIX}/bin ];then
	$MKDIR_CMD -v $DEST_DIR${NEXTSPACE_PREFIX}/bin
fi
$CP_CMD ${CORE_SOURCES}/usr/NextSpace/bin/* $DEST_DIR${NEXTSPACE_PREFIX}/bin/

# Icons, Plymouth resources and fontconfig configuration
if ! [ -d $DEST_DIR/usr/share ];then
	$MKDIR_CMD -v $DEST_DIR/usr/share
fi
# Copy directory contents into an explicit directory destination. FreeBSD
# hosts may already symlink /usr/share/icons to /usr/local/share/icons;
# copying the directory itself with cp -R fails on that existing symlink.
for resource_dir in "${CORE_SOURCES}"/usr/share/*; do
    resource_name=$(basename "$resource_dir")
    $MKDIR_CMD "$DEST_DIR/usr/share/$resource_name"
    $CP_CMD "$resource_dir/." "$DEST_DIR/usr/share/$resource_name/" || exit 1
done
