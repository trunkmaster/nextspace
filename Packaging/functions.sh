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
    SPEC_FILE=$1
    shift
    RELEASE=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --release) shift; RELEASE="$1"; test -n "$RELEASE" || error_exit "Missing argument to '--release'.";;
            *) error_exit "Unsupported argument: '$1'.";;
        esac
        shift
    done
    if [ -n "$RELEASE" ]; then
        rpmspec --define "release $RELEASE" -q --qf "%{version}-%{release}.%{arch}:" ${SPEC_FILE} | awk -F: '{print $1}'
    else
        rpmspec -q --qf "%{version}-%{release}.%{arch}:" ${SPEC_FILE} | awk -F: '{print $1}'
    fi
}

# $1 - path to spec file
build_rpm()
{
    SPEC_FILE=$1
    spectool -g -R ${SPEC_FILE}
    DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
    sudo yum -y install ${DEPS}
    run_rpmbuild ${SPEC_FILE}
}

# $1 - path to spec file, optional: $2, $3, ... - rpm build flags
run_rpmbuild()
{
    SPEC_FILE=$1
    shift
    RELEASE=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --release) shift; RELEASE="$1"; test -n "$RELEASE" || error_exit "Missing argument to '--release'.";;
            *) error_exit "Unsupported argument: '$1'.";;
        esac
        shift
    done
    if [ -n "$RELEASE" ]; then
        echo "rpmbuild --define \"release $RELEASE\" -bb ${SPEC_FILE}"
        rpmbuild --define "release $RELEASE" -bb ${SPEC_FILE}
    else
        echo "rpmbuild -bb ${SPEC_FILE}"
        rpmbuild -bb ${SPEC_FILE}
    fi
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
    sudo yum -y $INST_CMD $2 || exit 1
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

prepare_redhat_environment() 
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
                sudo dnf -y install clang binutils-gold
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

error_exit() {
    print_ERR "*** $*"
    exit 1
}

abort_with_message() {
    echo "Aborting..."
    exit 1
}
