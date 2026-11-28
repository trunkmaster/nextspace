#!/bin/sh

. ../environment.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
if is_debian_like; then
	install_apt_packages ${RUNTIME_RUN_DEPS} ${GNUSTEP_MAKE_DEPS}
else
	SPEC_FILE=${PROJECT_DIR}/Packaging/RedHat/SPECS/nextspace-core.spec
	install_rpm_spec_requires "${SPEC_FILE}" "libobjc2" "libdispatch" "nextspace-core" "git" "clang"
fi

#----------------------------------------
# Install system configuration files
#----------------------------------------
CORE_SOURCES=${PROJECT_DIR}/OS/Linux

if [ ! -d "${CORE_SOURCES}" ]; then
	$ECHO "\033[31mERROR: Missing core resources directory: ${CORE_SOURCES}\033[0m"
	exit 1
fi

$ECHO "Populating /etc... /usr..."

# /.hidden
if [ -f "${CORE_SOURCES}/dot_hidden" ]; then
	$CP_CMD "${CORE_SOURCES}/dot_hidden" /.hidden
fi

# Preferences
# The source tree keeps user defaults under /etc/skel. Do not install global
# /Library/Preferences here; the clean project leaves this disabled.
#$MKDIR_CMD $DEST_DIR/Library/Preferences
#$CP_CMD "${CORE_SOURCES}"/Library/Preferences/* $DEST_DIR/Library/Preferences/

# Linker cache
if [ -f "${CORE_SOURCES}/etc/ld.so.conf.d/nextspace.conf" ]; then
	if ! [ -d $DEST_DIR/etc/ld.so.conf.d ]; then
		$MKDIR_CMD -v $DEST_DIR/etc/ld.so.conf.d
	fi
	$CP_CMD -v "${CORE_SOURCES}/etc/ld.so.conf.d/nextspace.conf" $DEST_DIR/etc/ld.so.conf.d/
	refresh_ldconfig
fi

# X11
if [ -f "${CORE_SOURCES}/etc/X11/Xresources.nextspace" ]; then
	if ! [ -d $DEST_DIR/etc/X11 ]; then
		$MKDIR_CMD -v $DEST_DIR/etc/X11
	fi
	$CP_CMD "${CORE_SOURCES}/etc/X11/Xresources.nextspace" $DEST_DIR/etc/X11
fi
if [ -d "${CORE_SOURCES}/etc/X11/xorg.conf.d" ]; then
	if ! [ -d $DEST_DIR/etc/X11/xorg.conf.d ]; then
		$MKDIR_CMD -v $DEST_DIR/etc/X11/xorg.conf.d
	fi
	$CP_CMD "${CORE_SOURCES}"/etc/X11/xorg.conf.d/*.conf $DEST_DIR/etc/X11/xorg.conf.d/
fi

# PolKit & udev
if [ -d "${CORE_SOURCES}/etc/polkit-1/rules.d" ]; then
	if ! [ -d $DEST_DIR/etc/polkit-1/rules.d ]; then
		$MKDIR_CMD -v $DEST_DIR/etc/polkit-1/rules.d
	fi
#	$CP_CMD "${CORE_SOURCES}"/etc/polkit-1/rules.d/*.rules $DEST_DIR/etc/polkit-1/rules.d/
fi
#if [ -d "${CORE_SOURCES}/etc/udev/rules.d" ]; then
#	if ! [ -d $DEST_DIR/etc/udev/rules.d ]; then
#		$MKDIR_CMD -v $DEST_DIR/etc/udev/rules.d
#	fi
#	$CP_CMD "${CORE_SOURCES}"/etc/udev/rules.d/*.rules $DEST_DIR/etc/udev/rules.d/
#fi

# User environment
if [ -f "${CORE_SOURCES}/etc/profile.d/nextspace.sh" ]; then
	if ! [ -d $DEST_DIR/etc/profile.d ]; then
		$MKDIR_CMD -v $DEST_DIR/etc/profile.d
	fi
	$CP_CMD "${CORE_SOURCES}/etc/profile.d/nextspace.sh" $DEST_DIR/etc/profile.d/
fi

if [ -d "${CORE_SOURCES}/etc/skel" ]; then
	if ! [ -d $DEST_DIR/etc/skel ]; then
		$MKDIR_CMD -v $DEST_DIR/etc/skel
	fi
	[ -d "${CORE_SOURCES}/etc/skel/Library" ] && $CP_CMD "${CORE_SOURCES}"/etc/skel/Library $DEST_DIR/etc/skel/
	[ -d "${CORE_SOURCES}/etc/skel/.config" ] && $CP_CMD "${CORE_SOURCES}"/etc/skel/.config $DEST_DIR/etc/skel/
	[ -f "${CORE_SOURCES}/etc/skel/.gtkrc-2.0" ] && $CP_CMD "${CORE_SOURCES}"/etc/skel/.gtkrc-2.0 $DEST_DIR/etc/skel/
	[ -f "${CORE_SOURCES}/etc/skel/.zshrc.nextspace" ] && $CP_CMD "${CORE_SOURCES}"/etc/skel/.zshrc.nextspace $DEST_DIR/etc/skel/
	for nextspace_file in "${CORE_SOURCES}"/etc/skel/.*.nextspace; do
		[ -f "$nextspace_file" ] && $CP_CMD "$nextspace_file" $DEST_DIR/etc/skel/
	done

	if [ "$DEST_DIR" = "" ] && [ -d /root ]; then
		[ -d "${CORE_SOURCES}/etc/skel/.config" ] && $CP_CMD "${CORE_SOURCES}"/etc/skel/.config /root
		[ -d "${CORE_SOURCES}/etc/skel/Library" ] && $CP_CMD "${CORE_SOURCES}"/etc/skel/Library /root
	fi
fi

# Scripts
if [ -d "${CORE_SOURCES}/usr/NextSpace/bin" ]; then
	if ! [ -d $DEST_DIR/usr/NextSpace/bin ]; then
		$MKDIR_CMD -v $DEST_DIR/usr/NextSpace/bin
	fi
	$CP_CMD "${CORE_SOURCES}"/usr/NextSpace/bin/* $DEST_DIR/usr/NextSpace/bin/
fi

# Icons, Plymouth resources and fontconfig configuration
if [ -d "${CORE_SOURCES}/usr/share" ]; then
	if ! [ -d $DEST_DIR/usr/share ]; then
		$MKDIR_CMD -v $DEST_DIR/usr/share
	fi
	$CP_CMD "${CORE_SOURCES}"/usr/share/* $DEST_DIR/usr/share/
fi

# Set the NEXTSPACE theme as the default for Plymouth on live systems.
configure_plymouth_theme nextspace || exit 1
