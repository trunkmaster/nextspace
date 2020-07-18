#!/bin/bash

. ../Debian/versions.inc.sh

rootdir="$(pwd)"
patchdir=`readlink -f ../Debian`

create_dsc() {
	local dir="$1"

  cd $rootdir
  if [ -d $dir ];then
    cd $dir
    if [ -f $patchdir/$dir/debian/patches/series ];then
      cat $patchdir/$dir/debian/patches/series | while read filename; do
        patch -p1 -i $patchdir/$dir/debian/patches/$filename
       done
    fi
  fi
}

create_dsc libdispatch-${libdispatch_version}
create_dsc libobjc2-${libobjc2_version}
create_dsc nextspace-make-${gnustep_make_version}
create_dsc nextspace-base-${gnustep_base_version}
create_dsc nextspace-gui-${gnustep_gui_version}
create_dsc nextspace-back-${gnustep_gui_version}

create_dsc nextspace-gorm.app-${gorm_version}
create_dsc nextspace-projectcenter.app-${projectcenter_version}
create_dsc roboto-mono-${roboto_mono_version}
