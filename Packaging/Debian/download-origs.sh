#!/bin/bash
set -e

. versions.inc.sh

git_remote_archive() {
	local url="$1"
	local tarfile="$2_$3.orig.tar.gz"
	local prefix="$2-$3/"
	local branch="$4"

	if [ -f "$tarfile" ]; then
		return
	fi
	rm -rf tmp
	git clone --recurse-submodules "$url" tmp
	git archive --prefix="$prefix" --remote=file://$PWD/tmp/ -o "$tarfile" "$branch"
	rm -rf tmp
}

git_local_archive() {
	local pwd=$PWD
	local commitid="$1"
	local path="$2"
	local version=$(map_version_from_commit $commitid)
	local tarfile="$3_${version}.orig.tar.gz"
	local treeish="$(git ls-tree -d $commitid ../../$path |awk '{print $3;}')"
	cd ../..
	git archive -o "$pwd/$tarfile" --prefix="$3-${version}/" $treeish
	cd $pwd
}

git_remote_archive https://github.com/apple/swift-corelibs-libdispatch libdispatch ${libdispatch_version} swift-${libdispatch_version}-RELEASE

git_remote_archive https://github.com/gnustep/libobjc2 libobjc2 ${libobjc2_version} v${libobjc2_version}
git_remote_archive https://github.com/gnustep/tools-make nextspace-make ${gnustep_make_version} make-${gnustep_make_version//./_}
git_remote_archive https://github.com/gnustep/libs-base nextspace-base ${gnustep_base_version} base-${gnustep_base_version//./_}
git_remote_archive https://github.com/gnustep/libs-gui nextspace-gui ${gnustep_gui_version} origin/gnustep-gui-nextspace
git_remote_archive https://github.com/gnustep/libs-back nextspace-back ${gnustep_back_version} origin/gnustep-back-nextspace

git_remote_archive https://github.com/gnustep/apps-gorm nextspace-gorm.app ${gorm_version} gorm-${gorm_version//./_}
git_remote_archive https://github.com/gnustep/apps-projectcenter nextspace-projectcenter.app ${projectcenter_version} projectcenter-${projectcenter_version//./_}

git_local_archive ${nextspace_version} Frameworks nextspace-frameworks
git_local_archive ${nextspace_version} Applications nextspace-applications
