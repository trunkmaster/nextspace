###############################################################################
# Functions
###############################################################################

: ${ECHO:="printf %b\n"}
: ${ECHO_N:="printf %b"}

if command -v dnf >/dev/null 2>&1; then
    RPM_PACKAGE_MANAGER=dnf
elif command -v yum >/dev/null 2>&1; then
    RPM_PACKAGE_MANAGER=yum
else
    RPM_PACKAGE_MANAGER=dnf
fi

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
  apt-get install ${APT_INSTALL_OPTIONS:--y} $@ || exit 1
}

uninstall_packages() {
  apt-get purge -y $@ || exit 1
}

is_debian_like()
{
    [ "${OS_ID}" = "debian" ] || [ "${OS_ID}" = "ubuntu" ]
}

is_rpm_like()
{
    ! is_debian_like
}

install_apt_packages()
{
    if [ $# -eq 0 ]; then
        return 0
    fi
    sudo apt-get install ${APT_INSTALL_OPTIONS:--y} "$@" || exit 1
}

install_rpm_packages()
{
    if [ $# -eq 0 ]; then
        return 0
    fi
    sudo ${RPM_PACKAGE_MANAGER} -y install "$@" || exit 1
}

rpm_spec_deps()
{
    query_flag=$1
    spec_file=$2
    shift 2

    rpmspec -q "${query_flag}" "${spec_file}" | awk '{print $1}' | while read dep_name; do
        skip_dep=0
        for skip_pattern in "$@"; do
            echo "${dep_name}" | grep -q "${skip_pattern}" && skip_dep=1
        done
        [ ${skip_dep} -eq 0 ] && echo "${dep_name}"
    done
}

install_rpm_spec_buildrequires()
{
    spec_file=$1
    shift
    deps=`rpm_spec_deps --buildrequires "${spec_file}" "$@"`
    install_rpm_packages ${deps}
}

install_rpm_spec_requires()
{
    spec_file=$1
    shift
    deps=`rpm_spec_deps --requires "${spec_file}" "$@"`
    install_rpm_packages ${deps}
}

download_tarball_once()
{
    url=$1
    archive_file=$2
    extract_dir=$3

    if [ ! -d "${extract_dir}" ]; then
        curl -L "${url}" -o "${archive_file}" || exit 1
        old_dir=`pwd`
        cd "${BUILD_ROOT}" || exit 1
        tar zxf "${archive_file}" || exit 1
        cd "${old_dir}" || exit 1
    fi
}

copy_clean_build_tree()
{
    source_dir=$1
    build_dir=$2

    if [ -d "${build_dir}" ]; then
        rm -rf "${build_dir}" || exit 1
    fi
    cp -R "${source_dir}" "${BUILD_ROOT}" || exit 1
}

refresh_ldconfig()
{
    if [ "$DEST_DIR" = "" ]; then
        sudo ldconfig
    fi
}

reload_systemd_if_live()
{
    if [ "$DEST_DIR" = "" ] && [ "$GITHUB_ACTIONS" != "true" ] && [ "$CI" != "true" ]; then
        sudo systemctl daemon-reload || exit 1
    fi
}

enable_service_once()
{
    service_name=$1
    unit_path=$2

    if [ "$DEST_DIR" = "" ] && [ "$GITHUB_ACTIONS" != "true" ] && [ "$CI" != "true" ]; then
        systemctl --quiet is-enabled "${service_name}" || sudo systemctl enable "${unit_path}" || exit 1
    fi
}

configure_debian_plymouth_boot()
{
    if [ "${OS_ID}" != "debian" ]; then
        return 0
    fi

    if [ ! -f /etc/default/grub ]; then
        $ECHO "\033[33mWARNING: /etc/default/grub was not found; skipping Plymouth boot splash configuration.\033[0m"
        return 0
    fi

    $ECHO "Configuring Debian Plymouth boot splash..."
    tmp_grub=`mktemp` || return 1

    awk '
    BEGIN { updated = 0 }
    /^GRUB_CMDLINE_LINUX_DEFAULT="/ {
        args = $0
        sub(/^GRUB_CMDLINE_LINUX_DEFAULT="/, "", args)
        sub(/".*$/, "", args)
        if ((" " args " ") !~ / splash /) {
            args = args " splash"
        }
        print "GRUB_CMDLINE_LINUX_DEFAULT=\"" args "\""
        updated = 1
        next
    }
    { print }
    END {
        if (updated == 0) {
            print "GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\""
        }
    }
    ' /etc/default/grub > "${tmp_grub}" || {
        rm -f "${tmp_grub}"
        return 1
    }

    if ! cmp -s "${tmp_grub}" /etc/default/grub; then
        sudo cp "${tmp_grub}" /etc/default/grub || {
            rm -f "${tmp_grub}"
            return 1
        }
        sudo update-grub || {
            rm -f "${tmp_grub}"
            return 1
        }
        sudo update-initramfs -u || {
            rm -f "${tmp_grub}"
            return 1
        }
    else
        $ECHO "  Plymouth boot splash already configured."
    fi

    rm -f "${tmp_grub}"
}

configure_plymouth_theme()
{
    theme_name=$1

    if [ -z "${theme_name}" ]; then
        return 0
    fi

    if [ "$DEST_DIR" != "" ] || [ "$GITHUB_ACTIONS" = "true" ] || [ "$CI" = "true" ]; then
        $ECHO "Skipping Plymouth theme activation in build/CI environment."
        return 0
    fi

    if [ -f /.dockerenv ] || { command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --container --quiet; }; then
        $ECHO "Skipping Plymouth theme activation inside container."
        return 0
    fi

    if [ ! -d "/lib/modules/`uname -r`" ]; then
        $ECHO "\033[33mWARNING: /lib/modules/`uname -r` was not found; skipping Plymouth initramfs regeneration.\033[0m"
        return 0
    fi

    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        if [ ! "`plymouth-set-default-theme`" = "${theme_name}" ]; then
            plymouth-set-default-theme -R "${theme_name}" || return 1
        fi
    fi
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
    DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk '{print $1}'`
    sudo ${RPM_PACKAGE_MANAGER} -y install ${DEPS}
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
    sudo ${RPM_PACKAGE_MANAGER} -y $INST_CMD $2 || exit 1
}

# Bold
print_H1()
{
    $ECHO_N "\033[1m"
        $ECHO "========================================================================="
    $ECHO_N "\033[1m"
    $ECHO "$1"
    $ECHO_N "\033[1m"
        $ECHO "========================================================================="
    $ECHO_N "\033[0m"
}

# Brown
print_H2()
{
    $ECHO_N "\033[33m"
    $ECHO "$1"
    $ECHO_N "\033[0m"
}

# Green
print_OK()
{
    $ECHO_N "\033[32m"
        $ECHO "========================================================================="
    $ECHO_N "\033[32m"
    $ECHO "$1"
    $ECHO_N "\033[32m"
        $ECHO "========================================================================="
    $ECHO_N "\033[0m"
}

# Red
print_ERR()
{
    $ECHO_N "\033[31m"
        $ECHO "========================================================================="
    $ECHO_N "\033[31m"
    $ECHO "$1"
    $ECHO_N "\033[31m"
        $ECHO "========================================================================="
    $ECHO_N "\033[0m"
}

prepare_redhat_environment() 
{
    print_H1 " Prepare build environment"
    print_H2 "===== Install RPM build tools..."
    BUILD_TOOLS=""
    
    rpm -q rpm-build 2>&1 > /dev/null
    if [ $? -eq 1 ]; then BUILD_TOOLS="${BUILD_TOOLS} rpm-build"; fi
    rpm -q rpmdevtools 2>&1 > /dev/null
    if [ $? -eq 1 ]; then BUILD_TOOLS="${BUILD_TOOLS} rpmdevtools"; fi
    rpm -q make 2>&1 > /dev/null
    if [ $? -eq 1 ]; then BUILD_TOOLS="${BUILD_TOOLS} make"; fi
    rpm -q patch 2>&1 > /dev/null
    if [ $? -eq 1 ]; then BUILD_TOOLS="${BUILD_TOOLS} patch"; fi

    if [ -f /etc/os-release ]; then 
	    if [ "${OS_ID}" = "rhel" ] && [ "${OS_VERSION}" = "9" ];then
            sudo ${RPM_PACKAGE_MANAGER} -y install epel-release
            sudo ${RPM_PACKAGE_MANAGER} config-manager --set-enabled crb
            sudo ${RPM_PACKAGE_MANAGER} -y install clang
        else
            if [ "$OS_ID" = "fedora" ] || [ "$OS_ID" = "ultramarine" ];then
                sudo ${RPM_PACKAGE_MANAGER} -y install clang binutils-gold
            else
                print_H2 ">>>>> Can't find /etc/os-release - this OS is unsupported."
                return 1
            fi
        fi
    fi
    
    if [ "${BUILD_TOOLS}" != "" ]; then
        sudo ${RPM_PACKAGE_MANAGER} -y install ${BUILD_TOOLS}
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
