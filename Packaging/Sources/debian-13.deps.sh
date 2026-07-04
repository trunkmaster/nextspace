# Works for Debian 13 (trixie).
#
# Keep the Debian 12 dependency groups as the baseline and override only package
# names that changed ABI/package names in Debian 13.

. ./debian-12.deps.sh

WRASTER_RUN_DEPS="
    libgif7
    libjpeg62-turbo
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
    libicu76
    libicu-dev
    libgnutls30
    libcups2
"
