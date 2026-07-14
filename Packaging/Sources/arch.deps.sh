# Package dependencies for building ArchSTEP on Arch Linux.
# All names are official-repo pacman packages. Arch makes no dev/runtime
# package split, so *_DEPS covers both build and run for each component.

BUILD_TOOLS="
    clang
    cmake
    make
    patch
    git
    curl
"
#--- libdispatch, libcorefoundation, libobjc2
RUNTIME_DEPS="
    libbsd
    util-linux-libs
    avahi
    icu
    libxml2
"
#--- gnustep-make
GNUSTEP_MAKE_DEPS="
    zsh
    which
"
#--- libwraster
WRASTER_DEPS="
    giflib
    libjpeg-turbo
    libpng
    libtiff
    libwebp
    libxpm
    libxmu
    libxext
    libx11
"
#--- gnustep-base
GNUSTEP_BASE_DEPS="
    libffi
    libxml2
    libxslt
    avahi
    libcups
    gnutls
    icu
"
#--- gnustep-gui
GNUSTEP_GUI_DEPS="
    libao
    libsndfile
"
#--- gnustep-back (art backend)
BACK_ART_DEPS="
    libart-lgpl
    freetype2
    libxcursor
    libxfixes
    libxt
    libxrandr
"
#--- Frameworks (SystemKit, SoundKit, DesktopKit)
FRAMEWORKS_BUILD_DEPS="
    file
    glib2
    dbus
    udisks2
    upower
    libxkbfile
    libxcursor
    libxrandr
    libpulse
"
FRAMEWORKS_RUN_DEPS="
    pipewire-pulse
"
#--- Applications
APPS_BUILD_DEPS="
    fontconfig
    libxft
    libxinerama
    libxcomposite
    libxrender
    libxdamage
    libexif
    pam
"
APPS_RUN_DEPS="
    xorg-server
    xorg-xrdb
    xorg-xset
    xorg-xrandr
    xorg-setxkbmap
    xorg-xmodmap
    xorg-fonts-100dpi
"
