###############################################################################
# Variables
###############################################################################
ECHO="/usr/bin/echo -e"
_PWD=`pwd`

#----------------------------------------
# Libraries and applications
#----------------------------------------
# Apple
libdispatch_version=5.9.2
libcorefoundation_version=5.9.2
libcfnetwork_version=129.20
# GNUstep
libobjc2_version=2.2.1
gnustep_make_version=2_9_2
gnustep_base_version=1_31_1
gnustep_gui_version=0_32_0
gorm_version=1_5_0
projectcenter_version=0_7_0

#----------------------------------------
# Operating system: Arch Linux only
#----------------------------------------
. /etc/os-release
OS_ID=$ID
OS_NAME=$NAME
if [ "${OS_ID}" != "arch" ] && [ "${ID_LIKE}" != "arch" ]; then
  ${ECHO} "ArchSTEP builds on Arch Linux only (detected: ${OS_NAME:-unknown})."
  exit 1
fi
${ECHO} "OS:\t\t${OS_NAME} (rolling)"

MACHINE=`uname -m`

#----------------------------------------
# Paths
#----------------------------------------
# Directory where the ArchSTEP repo resides
cd ../..
PROJECT_DIR=`pwd`
${ECHO} "ArchSTEP repo:\t${PROJECT_DIR}"
cd ${_PWD}

BUILD_ROOT="${_PWD}/BUILD_ROOT"
if [ ! -d ${BUILD_ROOT} ]; then
  mkdir ${BUILD_ROOT}
fi
${ECHO} "Build in:\t${BUILD_ROOT}"

if [ "$1" != "" ];then
  DEST_DIR=${1}
  ${ECHO} "Install in:\t${1}"
else
  DEST_DIR=""
fi

. ../functions.sh
#----------------------------------------
# Package dependencies (pacman names)
#----------------------------------------
. ./arch.deps.sh || exit 1

#----------------------------------------
# Tools
#----------------------------------------
CMAKE_CMD=cmake
MAKE_CMD=make
#
if [ "$1" != "" ];then
  INSTALL_CMD="${MAKE_CMD} install DESTDIR=${1}"
else
  INSTALL_CMD="sudo -E ${MAKE_CMD} install"
fi

# Utilities
if [ "$1" != "" ];then
  RM_CMD="rm"
  LN_CMD="ln -sf"
  MV_CMD="mv -v"
  CP_CMD="cp -R"
  MKDIR_CMD="mkdir -p"
else
  RM_CMD="sudo rm"
  LN_CMD="sudo ln -sf"
  MV_CMD="sudo mv -v"
  CP_CMD="sudo cp -R"
  MKDIR_CMD="sudo mkdir -p"
fi

# Compiler: clang is the only supported compiler
which clang 2>&1 > /dev/null || { echo "No clang compiler found. Run: pacman -S clang"; exit 1; }
C_COMPILER=`which clang`
which clang++ 2>&1 > /dev/null || { echo "No clang++ compiler found. Run: pacman -S clang"; exit 1; }
CXX_COMPILER=`which clang++`

# Linker: Arch's default linker. If link problems surface, try gold or lld
# via LDFLAGS=-fuse-ld=gold / -fuse-ld=lld here.
