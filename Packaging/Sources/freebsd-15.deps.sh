BUILD_TOOLS="
    zig015
    git
    cmake
    gmake
    bash
"

# CoreFoundation
CORE_SYSTEM_DEPS="
    libdispatch
    libxml2
    icu
    curl
    libuuid
    pkgconf
"

# libwraster
WRASTER_DEPS="
  giflib
  jpeg-turbo
  png
  tiff
  webp
  libXpm
  libXmu
"

# GNUstep Base
GNUSTEP_BASE_DEPS="
    libffi
    libxml2
    libxslt
    avahi-libdns
    cups
    gnutls
"

GNUSTEP_GUI_DEPS="libsndfile"

# ART and Cairo backends
BACK_ART_DEPS="
  libart_lgpl
  cairo
  libXfixes
  libXcursor
  libXrandr
  freetype2
  libXft
"

FRAMEWORKS_DEPS="
  dbus
  upower
  libudisks
  libxkbfile
  pulseaudio
"


APPLICATIONS_DEPS="
  libinotify
  libiconv
  libXcomposite
  libXdamage
  xorg-server
  xf86-input-keyboard
  xf86-input-evdev
"

# Terminal Unicode fallback font coverage.
APPLICATIONS_DEPS="${APPLICATIONS_DEPS} fontconfig freetype2 harfbuzz noto-emoji noto-sans-jp noto-sans-kr noto-sans-sc"
