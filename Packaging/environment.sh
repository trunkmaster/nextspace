###############################################################################
# Variables
###############################################################################
ECHO="/usr/bin/echo -e"
_PWD=`pwd`

#----------------------------------------
# Operating system
#----------------------------------------
. /etc/os-release
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

# Package dependencies for Debian/Ubuntu
if [ ${OS_ID} = "debian" ] || [ ${OS_ID} = "ubuntu" ]; then
    . ./${OS_ID}-${OS_VERSION}.deps.sh || exit 1
fi

#----------------------------------------
# Library versions
#----------------------------------------
if [ "${OS_ID}" = "centos" ] && [ "${OS_VERSION}" = "7" ]; then
  libdispatch_version=5.4.2
  libcorefoundation_version=5.4.2
  gnustep_make_version=2_7_0
  gnustep_base_version=1_28_0
  gnustep_gui_version=0_29_0
else
  libdispatch_version=5.9.2
  libcorefoundation_version=5.9.2
  libcfnetwork_version=129.20
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
  RELEASE_USR="$_PWD/$OS_ID-$OS_VERSION/NSUser"
  RELEASE_DEV="$_PWD/$OS_ID-$OS_VERSION/NSDeveloper"
  mkdir -p ${RELEASE_USR}
  mkdir -p ${RELEASE_DEV}

  RPM_SOURCES_DIR=~/rpmbuild/SOURCES
  RPM_SPECS_DIR=~/rpmbuild/SPECS
  RPMS_DIR=~/rpmbuild/RPMS/`uname -m`

  ${ECHO} "RPMs directory:\t$RPMS_DIR"
fi

#----------------------------------------
# Tools
#----------------------------------------
# Make
if [ "${OS_ID}" = "centos" ] && [ "${OS_VERSION}" = "7" ]; then
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
if [ "$OS_ID" = "fedora" ] || [ "$OS_ID" = "debian" ] || [ "$OS_ID" = "ubuntu" ]; then
  which clang 2>&1 > /dev/null || `echo "No clang compiler found. Please install clang package."; exit 1`
  C_COMPILER=`which clang`
  which clang++ 2>&1 > /dev/null || `echo "No clang++ compiler found. Please install clang++ package."; exit 1`
  CXX_COMPILER=`which clang++`
fi

###############################################################################
# Functions
###############################################################################

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

prepare_environment() 
{
    print_H1 " Prepare build environment"
    print_H2 "===== Create rpmbuild directories..."
    mkdir -p $RPM_SOURCES_DIR
    mkdir -p $RPM_SPECS_DIR

    print_H2 "===== Install RPM build tools..."
    rpm -q rpm-build 2>&1 > /dev/null
    if [ $? -eq 1 ]; then BUILD_TOOLS+=" rpm-build"; fi
    rpm -q rpmdevtools 2>&1 > /dev/null
    if [ $? -eq 1 ]; then BUILD_TOOLS+=" rpmdevtools"; fi
    rpm -q make 2>&1 > /dev/null
    if [ $? -eq 1 ]; then BUILD_TOOLS+=" make"; fi
    rpm -q patch 2>&1 > /dev/null
    if [ $? -eq 1 ]; then BUILD_TOOLS+=" patch"; fi

    if [ -f /etc/os-release ]; then 
        if [ $OS_ID == "centos" ];then
            if [ $OS_VERSION == "7" ];then
                yum repolist | grep "epel/" 2>&1 > /dev/null
                if [ $? -eq 1 ]; then
                    BUILD_TOOLS+=" https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm";
                fi
                rpm -q centos-release-scl 2>&1 > /dev/null
                if [ $? -eq 1 ]; then BUILD_TOOLS+=" centos-release-scl"; fi
                rpm -q centos-release-scl-rh 2>&1 > /dev/null
                if [ $? -eq 1 ]; then BUILD_TOOLS+=" centos-release-scl-rh"; fi
            fi
            if [ $OS_VERSION == "9" ];then
                # Could be "CentOS Linux" or "CentOS Stream"
                if [ "$OS_ID" == "CentOS Stream" ]; then
                    yum config-manager --set-enabled powertools
                else
                    yum config-manager --set-enabled PowerTools
                fi
                rpm -q epel-release 2>&1 > /dev/null
                if [ $? -eq 1 ]; then BUILD_TOOLS+=" epel-release"; fi
                rpm -q dnf-plugins-core 2>&1 > /dev/null
                if [ $? -eq 1 ]; then BUILD_TOOLS+=" dnf-plugins-core"; fi
                rpm -q git 2>&1 > /dev/null
                if [ $? -eq 1 ]; then BUILD_TOOLS+=" git"; fi
            fi
        fi
    else
        print_H2 ">>>>> Can't find /etc/os-release - this OS is unsupported."
        return 1
    fi
    
    if [ "${BUILD_TOOLS}" != "" ]; then
        sudo yum -y install ${BUILD_TOOLS}
    fi
}

rpm_version()
{
    echo `rpmspec -q --qf "%{version}-%{release}.%{arch}:" $1 | awk -F: '{print $1}'`
}

# $1 - path to spec file
build_rpm()
{
    SPEC_FILE=$1
    spectool -g -R ${SPEC_FILE}
    DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
    sudo yum -y install ${DEPS}
    rpmbuild -bb ${SPEC_FILE}
}

# $1 - package name, $2 - rpm file path
install_rpm()
{
    rpm -q $1 2>&1 > /dev/null
    if [ $? -eq 1 ]; then 
        INST_CMD=install
    else
        INST_CMD=reinstall
    fi
    sudo yum -y $INST_CMD $2
}

# Bold
print_H1()
{
    echo -e -n "\e[1m"
    echo "================================================================================"
    echo -e -n "\e[1m"
    echo -e "$1"
    echo -e -n "\e[1m"
    echo "================================================================================"
    echo -e -n "\e[0m"
}

# Brown
print_H2()
{
    echo -e -n "\e[33m"
    echo -e "$1"
    echo -e -n "\e[0m"
}

# Green
print_OK()
{
    echo -e -n "\e[32m"
    echo "================================================================================"
    echo -e -n "\e[32m"
    echo -e "$1"
    echo -e -n "\e[32m"
    echo "================================================================================"
    echo -e -n "\e[0m"
}

# Red
print_ERR()
{
    echo -e -n "\e[31m"
    echo "================================================================================"
    echo -e -n "\e[31m"
    echo -e "$1"
    echo -e -n "\e[31m"
    echo "================================================================================"
    echo -e -n "\e[0m"
}

print_help()
{
    SCRIPT_NAME=`basename $0`
    print_ERR " ERROR: No NEXTSPACE directory specified."
    printf "\n"
    print_H2 "You have to specify directory where NEXTSPACE git clone resides."
    print_H2 "For example, consider this scenario:"
    printf "\n"
    print_H2 "$ git clone https://github.com/trunkmaster/nextspace"
    print_H2 "$ cd nextspace"
    print_H2 "$ ./scripts/$SCRIPT_NAME ~/nextspace"
    printf "\n"
}