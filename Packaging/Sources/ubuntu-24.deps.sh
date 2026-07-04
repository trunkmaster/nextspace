# Works for Ubuntu 24.04 LTS (noble).
#
# Keep the Debian 12 / Ubuntu 22.04 dependency groups as the baseline and
# override package names that changed ABI/package names in Ubuntu 24.04.

. ./debian-12.deps.sh

WRASTER_RUN_DEPS="
    libgif7
    libjpeg8
    libtiff6
    libpng16-16
    libwebp7
    libxpm4
    libxmu6
    libxext6
    libx11-6
"

GNUSTEP_BASE_RUN_DEPS="
    libffi8
    libavahi-client3
    libxml2
    libxslt1.1
    libicu74
    libicu-dev
    libgnutls30t64
    libcups2t64
"

FRAMEWORKS_RUN_DEPS="
    libmagic1
    libglib2.0-0t64
    dbus
    libdbus-1-3
    udisks2
    libudisks2-0
    libupower-glib3
    libxkbfile1
    libxrandr2
    pulseaudio
    libpulse0
    upower
"
