#!/bin/bash
set -e

. ./versions.inc.sh
ROOT="$PWD"

git_remote_archive() {
  local url="$1"
  local dest="$2-$3"
  local branch="$4"

  cd "$ROOT"

  if [ -d "$dest" ];then
    echo "$dest exists, skipping"
  else
	  git clone --recurse-submodules "$url" "$dest"
    cd "$dest"
    git checkout $branch
  fi
}

[ ! -x Applications ] && ln -s ../../Applications Applications
[ ! -x Frameworks ] && ln -s ../../Frameworks Frameworks

git_remote_archive https://github.com/apple/swift-corelibs-libdispatch libdispatch ${libdispatch_version} swift-${libdispatch_version}-RELEASE

git_remote_archive https://github.com/gnustep/libobjc2 libobjc2 ${libobjc2_version} v${libobjc2_version}
git_remote_archive https://github.com/gnustep/tools-make nextspace-make ${gnustep_make_version} make-${gnustep_make_version//./_}
git_remote_archive https://github.com/gnustep/libs-base nextspace-base ${gnustep_base_version} base-${gnustep_base_version//./_}
git_remote_archive https://github.com/gnustep/libs-gui nextspace-gui ${gnustep_gui_version} origin/gnustep-gui-nextspace
git_remote_archive https://github.com/gnustep/libs-back nextspace-back ${gnustep_back_version} origin/gnustep-back-nextspace

git_remote_archive https://github.com/gnustep/apps-gorm nextspace-gorm.app ${gorm_version} gorm-${gorm_version//./_}
git_remote_archive https://github.com/gnustep/apps-projectcenter nextspace-projectcenter.app ${projectcenter_version} projectcenter-${projectcenter_version//./_}

git_remote_archive https://github.com/TypeNetwork/RobotoMono roboto-mono ${roboto_mono_version} ${roboto_mono_checkout}
