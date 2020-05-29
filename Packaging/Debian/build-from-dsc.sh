#!/bin/bash
set -e

. versions.inc.sh

use_pbuilder() {
	local dsc="$1"

	sudo pbuilder build "$1"
}

build() {
	local package="$1"
	local version="$2"

	use_$method ${package}_${version}-*.dsc
}

method=${1-pbuilder}

build "libdispatch" "${libdispatch_version}"
build "libobjc2" "${libobjc2_version}"
build "nextspace-make" "${gnustep_make_version}"
build "nextspace-base" "${gnustep_base_version}"
build "nextspace-gui" "${gnustep_gui_version}"
build "nextspace-back" "${gnustep_back_version}"

build "nextspace-gorm.app" "${gorm_version}"
build "nextspace-projectcenter.app" "${projectcenter_version}"

build "nextspace-frameworks" "$(map_version_from_commit ${nextspace_version})"
build "nextspace-applications" "$(map_version_from_commit ${nextspace_version})"
