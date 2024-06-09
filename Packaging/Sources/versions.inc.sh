
ECHO="/usr/bin/echo -e"

#----------------------------------------
# Paths
#----------------------------------------
_PWD=`pwd`
BUILD_ROOT="${_PWD}/BUILD_ROOT"
if [ ! -d ${BUILD_ROOT} ]; then
  mkdir ${BUILD_ROOT}
fi
${ECHO} "Build in:\t${BUILD_ROOT}"

# Directory where nextspace GitHub repo resides
cd ../..
PROJECT_DIR=`pwd`
cd ${PWD}
${ECHO} "NextSpace:\t${PROJECT_DIR}"
cd ${_PWD}

if [ "$1" != "" ];then
  DEST_DIR=${1}
else
  DEST_DIR=""
fi
#----------------------------------------
# OS release
#----------------------------------------
OS_NAME=`cat /etc/os-release | grep "^ID=" | awk -F= '{print $2}'`
NAME=`echo ${OS_NAME} | awk -F\" '{print $2}'`
if [ -n "${NAME}" ] && [ "${NAME}" != " " ]; then
  OS_NAME=${NAME}
fi
OS_VERSION=`cat /etc/os-release | grep "^VERSION_ID" | awk -F= '{print $2}'`
VER=`echo ${OS_VERSION} | awk -F\" '{print $2}'`
if [ -n "${VER}" ] && [ "${VER}" != " " ]; then
  _VER=`echo ${VER} | awk -F\. '{print $1}'`
  if [ -n "${_VER}" ] && [ "${_VER}" != " " ]; then
    OS_VERSION=${_VER}
  else
    OS_VERSION=${VER}
  fi
fi
${ECHO} "OS:\t\t${OS_NAME}-${OS_VERSION}"

if [ ${OS_NAME} = "debian" ] || [ ${OS_NAME} = "ubuntu" ]; then
    . ./${OS_NAME}-${OS_VERSION}.deps.sh || exit 1
fi

#----------------------------------------
# Tools
#----------------------------------------
# Make
if [ "${OS_NAME}" = "centos" ] && [ "${OS_VERSION}" = "7" ]; then
  CMAKE_CMD=cmake3
else
  CMAKE_CMD=cmake
fi
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
which clang 2>&1 > /dev/null || `echo "No clang compiler found. Please install clang package."; exit 1`
if [ "${OS_NAME}" = "centos" ] && [ "${OS_VERSION}" = "7" ]; then
  source /opt/rh/llvm-toolset-7.0/enable
fi
C_COMPILER=`which clang`
which clang++ 2>&1 > /dev/null || `echo "No clang++ compiler found. Please install clang++ package."; exit 1`
CXX_COMPILER=`which clang++`

#----------------------------------------
# Versions
#----------------------------------------
if [ "${OS_NAME}" = "centos" ] && [ "${OS_VERSION}" = "7" ]; then
  libdispatch_version=5.4.2
  libcorefoundation_version=5.4.2
  gnustep_make_version=2_7_0
  gnustep_base_version=1_28_0
  gnustep_gui_version=0_29_0
else
  libdispatch_version=5.9.2
  libcorefoundation_version=5.9.2
  gnustep_make_version=2_9_2
  gnustep_base_version=1_30_0
  gnustep_gui_version=0_31_0
fi
libobjc2_version=2.2.1
#gnustep_back_version=0_30_0

gorm_version=1_4_0
projectcenter_version=0_7_0

roboto_mono_version=0.2020.05.08
roboto_mono_checkout=master

#----------------------------------------
# Functions
#----------------------------------------
git_remote_archive() {
  local url="$1"
  local dest="$2"
  local branch="$3"

  cd ${BUILD_ROOT}

  if [ -d "$dest" ];then
    echo "$dest exists, skipping"
  else
    git clone --recurse-submodules "$url" "$dest"
    cd "$dest"
    if [ "$branch" != "master" ];then
      git checkout $branch
    fi
  fi
}

install_packages() {
  apt-get install -y $@ || exit 1
}

uninstall_packages() {
  apt-get purge -y $@ || exit 1
}