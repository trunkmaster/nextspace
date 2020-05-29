#!/bin/bash

. versions.inc.sh

rootdir="$(pwd)"

create_dsc() {
	local dir="$1"

	cd "$rootdir"
	tar xf ${dir//-/?}.orig.tar.gz
	cd "$dir"
	if [ -f debian/patches/series ]; then
		cat debian/patches/series | while read filename; do
			patch -p1 -i "debian/patches/$filename"
	       	done
	fi
	dpkg-source -b .
}

create_dsc libdispatch-${libdispatch_version}
create_dsc libobjc2-${libobjc2_version}
create_dsc nextspace-make-${gnustep_make_version}
create_dsc nextspace-base-${gnustep_base_version}
create_dsc nextspace-gui-${gnustep_gui_version}
create_dsc nextspace-back-${gnustep_gui_version}

create_dsc nextspace-gorm.app-${gorm_version}
create_dsc nextspace-projectcenter.app-${projectcenter_version}

create_dsc nextspace-frameworks-$(map_version_from_commit ${nextspace_version})
create_dsc nextspace-applications-$(map_version_from_commit ${nextspace_version})
