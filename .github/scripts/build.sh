#! /usr/bin/env sh

set -ex

echo "Building..."

# build dependencies...
./.github/scripts/dependencies.sh

export LIBRARY_PATH=$HOME/staging/lib:$HOME/staging/lib64:$LIBRARY_PATH;
export LD_LIBRARY_PATH=$HOME/staging/lib:$HOME/staging/lib64:$LD_LIBRARY_PATH;
if [ $LIBRARY_COMBO = 'ng-gnu-gnu' ];
then
  export CPATH=$HOME/staging/include;
else
  export CPATH=/usr/lib/gcc/x86_64-linux-gnu/4.8/include;
fi;
export PATH=$HOME/staging/bin:$PATH;
export GNUSTEP_MAKEFILES=$HOME/staging/share/GNUstep/Makefiles;
. $HOME/staging/share/GNUstep/Makefiles/GNUstep.sh;

# Build gorm
make && make install && make check || (cat Tests/tests.log && false);
