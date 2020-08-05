libdispatch_version=5.1.5
libobjc2_version=2.0
gnustep_make_version=2.7.0
gnustep_base_version=1.27.0
gnustep_gui_version=0.28.0+nextspace
gnustep_back_version=0.28.0+nextspace

gorm_version=1.2.26
projectcenter_version=0.6.2

roboto_mono_version=0.2020.05.08
roboto_mono_checkout=master

MAKE_CMD=make
if type "gmake" 2>/dev/null >/dev/null ;then
  MAKE_CMD=gmake
fi
