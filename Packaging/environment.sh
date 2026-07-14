###############################################################################
# Variables
###############################################################################
ECHO="/usr/bin/echo -e"
_PWD=`pwd`

#----------------------------------------
# Install-layout versions (.so links, Framework Versions/ dirs).
# Sources are vendored in-tree; these are NOT download pins.
#----------------------------------------
libdispatch_version=6.3.3
libcorefoundation_version=5.9.2
libcfnetwork_version=129.20

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

# Compiler: clang is the only supported compiler; bootstrap it if missing
command -v clang > /dev/null || install_packages ${BUILD_TOOLS}
C_COMPILER=`command -v clang`
CXX_COMPILER=`command -v clang++`

# Linker: Arch's default linker. If link problems surface, try gold or lld
# via LDFLAGS=-fuse-ld=gold / -fuse-ld=lld here.
