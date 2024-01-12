libdispatch_version=5.4.2
libcorefoundation_version=5.4.2
libobjc2_version=2.1
gnustep_make_version=2_9_1
gnustep_base_version=1_29_0
gnustep_gui_version=0_30_0
#gnustep_back_version=0_30_0

gorm_version=1_3_1
projectcenter_version=0_7_0

roboto_mono_version=0.2020.05.08
roboto_mono_checkout=master

MAKE_CMD=make
if type "gmake" 2>/dev/null >/dev/null ;then
  MAKE_CMD=gmake
fi

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
    if [ "$branch" != "master" ];then
      git checkout $branch
    fi
  fi
}
