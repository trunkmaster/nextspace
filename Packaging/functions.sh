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

prepare_environment() 
{
    print_H1 " Prepare build environment"
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
	    if [ "${OS_ID}" = "rhel" ] && [ "${OS_VERSION}" = "9" ];then
            sudo dnf -y install epel-release
            sudo dnf config-manager --set-enabled crb
            sudo dnf -y install clang
        else
            if [ "$OS_ID" = "fedora" ] || [ "$OS_ID" = "ultramarine" ];then
                sudo dnf -y install clang
            else
                print_H2 ">>>>> Can't find /etc/os-release - this OS is unsupported."
                return 1
            fi
        fi
    fi
    
    if [ "${BUILD_TOOLS}" != "" ]; then
        sudo dnf -y install ${BUILD_TOOLS}
    fi
}
