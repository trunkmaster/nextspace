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
gnustep_base_version=1_31_0
gnustep_gui_version=0_32_0
gorm_version=1_5_0
projectcenter_version=0_7_0

#----------------------------------------
# Operating system
#----------------------------------------
. /etc/os-release
# OS type like "rhel"
OS_LIKE=`echo ${ID_LIKE} | awk '{print $1}'`
# OS name like "fedora"
OS_ID=$ID
_ID=`echo ${ID} | awk -F\" '{print $2}'`
if [ -n "${_ID}" ] && [ "${_ID}" != " " ]; then
  OS_ID=${_ID}
fi
# OS version like "39"
OS_VERSION=$VERSION_ID
_VER=`echo ${VERSION_ID} | awk -F\. '{print $1}'`
if [ -n "${_VER}" ] && [ "${_VER}" != " " ]; then
  OS_VERSION=$_VER
fi
# Name like "Fedora Linux"
OS_NAME=$NAME
${ECHO} "OS:\t\t${OS_ID}-${OS_VERSION}"

#---------------------------------------
# Machine
#---------------------------------------
MACHINE=`uname -m`
if [ -f /proc/device-tree/model ];then
	MODEL=`cat /proc/device-tree/model | awk '{print $1}'`
else
	MODEL="unkown"
fi

if [ -f /proc/device-tree/compatible ];then
	GPU=`tr -d '\0' < /proc/device-tree/compatible | awk -F, '{print $3}'`
else
	GPU="unknown"
fi

#----------------------------------------
# Paths
#----------------------------------------
# Directory where nextspace GitHub repo resides
cd ../..
PROJECT_DIR=`pwd`
${ECHO} "NextSpace repo:\t${PROJECT_DIR}"
cd ${_PWD}

if [ -z $BUILD_RPM ]; then
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
else
  print_H2 "===== Create rpmbuild directories..."
  RELEASE_USR="$_PWD/$OS_ID-$OS_VERSION/NSUser"
  RELEASE_DEV="$_PWD/$OS_ID-$OS_VERSION/NSDeveloper"
  mkdir -p ${RELEASE_USR}
  mkdir -p ${RELEASE_DEV}

  RPM_SOURCES_DIR=~/rpmbuild/SOURCES
  RPM_SPECS_DIR=~/rpmbuild/SPECS
  RPMS_DIR=~/rpmbuild/RPMS/`uname -m`
  mkdir -p $RPM_SOURCES_DIR
  mkdir -p $RPM_SPECS_DIR

  ${ECHO} "RPMs directory:\t$RPMS_DIR"
fi

. ../functions.sh
#----------------------------------------
# Package dependencies
#----------------------------------------
if [ ${OS_ID} = "debian" ] || [ ${OS_ID} = "ubuntu" ]; then
    . ./${OS_ID}-${OS_VERSION}.deps.sh || exit 1
else
    prepare_environment
fi

#----------------------------------------
# Tools
#----------------------------------------
# Make
  CMAKE_CMD=cmake
if type "gmake" 2>/dev/null >/dev/null ;then
  MAKE_CMD=gmake
else
  MAKE_CMD=make
fi
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

# Linker
ld -v | grep "gold" 2>&1 > /dev/null
if [ "$?" = "1" ]; then
  ${ECHO} "Setting up Gold linker..."
  sudo update-alternatives --install /usr/bin/ld ld /usr/bin/ld.gold 100
  sudo update-alternatives --install /usr/bin/ld ld /usr/bin/ld.bfd 10
  sudo update-alternatives --auto ld
  ld -v | grep "gold" 2>&1 > /dev/null
  if [ "$?" = "1" ]; then
    ${ECHO} "Failed to setup Gold linker"
    exit 1
  fi
else
  ${ECHO} "Using linker:\tGold"
fi
# Compiler
if [ "$OS_ID" = "fedora" ] || [ "$OS_LIKE" = "rhel" ] || [ "$OS_ID" = "debian" ] || [ "$OS_ID" = "ubuntu" ] || [ "$OS_ID" = "ultramarine" ]; then
  which clang 2>&1 > /dev/null || `echo "No clang compiler found. Please install clang package."; exit 1`
  C_COMPILER=`which clang`
  which clang++ 2>&1 > /dev/null || `echo "No clang++ compiler found. Please install clang++ package."; exit 1`
  CXX_COMPILER=`which clang++`
fi
