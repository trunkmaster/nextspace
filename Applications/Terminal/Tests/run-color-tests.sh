#!/bin/sh
# Run from an existing desktop, e.g. DISPLAY=:0 XAUTHORITY=$HOME/.Xauthority.
# Creates and closes a small synthetic test window; no shell or user files.
set -e
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
. /etc/profile.d/nextspace.sh
set -u
export LD_LIBRARY_PATH=/usr/local/NextSpace/lib:/Library/Libraries
cd "$(dirname "$0")/.."
gmake ADDITIONAL_INCLUDE_DIRS="-I/usr/local/NextSpace/include -I/Library/Headers -I/usr/local/include" \
  ADDITIONAL_LIB_DIRS="-L/usr/local/NextSpace/lib -L/Library/Libraries -L/usr/local/lib"
(
  cd Tests
  gmake ADDITIONAL_INCLUDE_DIRS="-I.. -I/usr/local/NextSpace/include" \
    ADDITIONAL_LIB_DIRS="-L/usr/local/NextSpace/lib -L/Library/Libraries"
  ./obj/ghostty-adapter-test
)
# Match the application library order: DesktopKit/SystemKit before gui/base.
# Their protocol initialization depends on the dependency graph/load order.
clang $(gnustep-config --objc-flags) -DUSE_GHOSTTY_VT=1 \
  -I. -I/usr/local/NextSpace/include -I/Library/Headers \
  Tests/terminal-color-render-test.m \
  $(find obj/Terminal.obj -name '*.o' ! -name main.m.o) \
  -L/usr/local/NextSpace/lib -L/Library/Libraries -L/usr/local/lib \
  -lfontconfig -lfreetype -lharfbuzz -lutil -lDesktopKit -lSystemKit -lX11 \
  -ldispatch -liconv -lghostty-vt $(gnustep-config --gui-libs) \
  -o Tests/obj/terminal-color-render-test
: "${DISPLAY:?Run from an existing X desktop; do not start a second X server.}"
timeout -k 2 20 Tests/obj/terminal-color-render-test
