
map_version_from_commit() {
	local commitid=$1
	local tag="$(git describe --abbrev=0 --tags ${commitid})"
	local date="$(git show --pretty=%cd --date=format:%Y%m%d ${commitid} | head -1)"
	local short_commit="$(git rev-parse --short ${commitid})"
	printf "${tag}+${date}.git${short_commit}"
}

libdispatch_version=5.1.5
libobjc2_version=2.1
gnustep_make_version=2.7.0
gnustep_base_version=1.27.0
gnustep_gui_version=0.28.0+nextspace
gnustep_back_version=0.28.0+nextspace

gorm_version=1.2.26
projectcenter_version=0.6.2

nextspace_version=68055da986c9d4259dbf244e2f77933c9598dd5b
