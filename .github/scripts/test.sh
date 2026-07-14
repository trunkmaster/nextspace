#! /usr/bin/env sh

set -ex

echo "Testing..."

. $HOME/staging/share/GNUstep/Makefiles/GNUstep.sh;

# Test gorm
make check || (cat Tests/tests.log && false);
