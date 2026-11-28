#!/bin/sh
# It is a helper script for automated install of NEXTSPACE which has been built
# with scripts. Should be placed next to binary build hierarchy.

SCRIPT_DIR=`CDPATH= cd -- "$(dirname -- "$0")" && pwd`
RUN_DIR=`pwd`

. "${SCRIPT_DIR}/../install_environment.sh"
ECHO="printf %b\n"
ECHO_N="printf %b"
. /etc/os-release
OS_ID=${ID}
OS_VERSION=${VERSION_ID%%.*}

if command -v dnf >/dev/null 2>&1; then
    RPM_PACKAGE_MANAGER=dnf
elif command -v yum >/dev/null 2>&1; then
    RPM_PACKAGE_MANAGER=yum
fi

. "${SCRIPT_DIR}/../functions.sh"

if is_debian_like; then
    DEPS_FILE="${SCRIPT_DIR}/${OS_ID}-${OS_VERSION}.deps.sh"
    if [ ! -f "${DEPS_FILE}" ]; then
        $ECHO "Unsupported ${OS_ID}-${OS_VERSION}: missing ${DEPS_FILE}"
        exit 1
    fi
    . "${DEPS_FILE}" || exit 1
fi

find_distribution_root()
{
    candidate="$1"

    if [ -n "$candidate" ] && [ -d "$candidate/usr/NextSpace" ]; then
        echo "$candidate"
        return
    fi
}

run_source_builds()
{
    BUILD_SCRIPTS="
0_build_libdispatch.sh
1_build_libcorefoundation.sh
2_build_libobjc2.sh
3_build_core.sh
3_build_tools-make.sh
4_build_libwraster.sh
5_build_libs-base.sh
6_build_libs-gui.sh
7_build_libs-back.sh
8_build_Frameworks.sh
9_build_Applications.sh
"

    OLD_DIR=`pwd`
    cd "${SCRIPT_DIR}" || exit 1
    for build_script in ${BUILD_SCRIPTS}; do
        if [ ! -x "${build_script}" ]; then
            chmod +x "${build_script}" 2>/dev/null
        fi
        if [ ! -f "${build_script}" ]; then
            $ECHO "ERROR: Missing build script: ${SCRIPT_DIR}/${build_script}"
            cd "${OLD_DIR}" || exit 1
            return 1
        fi
        $ECHO "\033[1m"
        $ECHO "========================================================================="
        $ECHO "Running ${build_script}"
        $ECHO "========================================================================="
        $ECHO_N "\033[0m"
        "./${build_script}"
        if [ $? -ne 0 ]; then
            $ECHO "\033[31mERROR: ${build_script} failed. Stopping installation.\033[0m"
            cd "${OLD_DIR}" || exit 1
            return 1
        fi
    done
    cd "${OLD_DIR}" || exit 1
}

start_service_if_possible()
{
    service_name=$1
    executable_path=$2

    if [ ! -x "${executable_path}" ]; then
        $ECHO "\033[33mWARNING: ${service_name} was not started because ${executable_path} is missing or not executable.\033[0m"
        return 0
    fi

    if [ "${OS_ID}" = "fedora" ] || [ "${OS_ID}" = "ultramarine" ]; then
        sudo chmod 755 "${executable_path}" 2>/dev/null
        if command -v chcon >/dev/null 2>&1; then
            sudo chcon -t bin_t "${executable_path}" 2>/dev/null
        fi
    fi

    if ! systemctl --quiet is-active "${service_name}"; then
        sudo systemctl start "${service_name}"
        if [ $? -ne 0 ]; then
            $ECHO "\033[31mERROR: Failed to start ${service_name}.\033[0m"
            if [ "${OS_ID}" = "fedora" ] || [ "${OS_ID}" = "ultramarine" ]; then
                $ECHO "\033[33mFedora hint: if status shows 203/EXEC, check SELinux AVCs with: ausearch -m avc -ts recent\033[0m"
                $ECHO "\033[33mCurrent file context:\033[0m"
                ls -Z "${executable_path}" 2>/dev/null
            fi
            systemctl --no-pager --full status "${service_name}"
            return 1
        fi
        $ECHO "  ${service_name}: started"
    else
        $ECHO "  ${service_name}: active"
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

clear

#=========================================================================
# Main sequence
#=========================================================================
$ECHO_N "\033[33m"
$ECHO "========================================================================="
$ECHO "This script will install NEXTSPACE release $RELEASE and configure system."
$ECHO "========================================================================="
$ECHO_N "\033[1m"
$ECHO_N "Do you want to continue? [y/N]: "
$ECHO_N "\033[0m"
read YN
if [ "$YN" != "y" ]; then
    $ECHO "OK, maybe next time. Exiting..."
    exit
fi

#=========================================================================
# Install dependency packages
#=========================================================================
$ECHO "\033[1m"
$ECHO "========================================================================="
$ECHO "Installing system packages needed for NextSpace..."
$ECHO "========================================================================="
$ECHO_N "\033[0m"
if is_debian_like; then
    install_apt_packages ${RUNTIME_RUN_DEPS} ${WRASTER_RUN_DEPS} ${GNUSTEP_BASE_RUN_DEPS} \
                         ${GNUSTEP_GUI_RUN_DEPS} ${BACK_ART_RUN_DEPS} ${FRAMEWORKS_RUN_DEPS} \
                         ${APPS_RUN_DEPS}
elif [ "${OS_ID}" = "fedora" ] || [ "${OS_ID}" = "ultramarine" ]; then
    if [ -z "${RPM_PACKAGE_MANAGER}" ]; then
        $ECHO "Neither dnf nor yum was found. Cannot install Fedora dependencies."
        exit 1
    fi
    install_rpm_packages xorg-x11-drivers xorg-x11-xinit
else
    $ECHO "Unsupported OS for automatic package installation: ${OS_ID}-${OS_VERSION}"
    exit 1
fi
$ECHO "\033[32m Done! \033[0m"

#=========================================================================
# Extract distribution
#=========================================================================
$ECHO "\033[1m"
$ECHO "========================================================================="
$ECHO "Installing NextSpace..."
$ECHO "========================================================================="
$ECHO_N "\033[0m"
CORE_SOURCES=`find_distribution_root "$1"`
DEST_DIR=""

run_source_builds || exit 1

if [ -n "$CORE_SOURCES" ]; then
    $ECHO "Using distribution root: $CORE_SOURCES"

    if [ -d "$CORE_SOURCES/Applications" ]; then
        $ECHO "Copying /Applications..."
        $CP_CMD "$CORE_SOURCES"/Applications /
    fi
    if [ -d "$CORE_SOURCES/Developer" ]; then
        $ECHO "Copying /Developer..."
        $CP_CMD "$CORE_SOURCES"/Developer /
    fi
    if [ -d "$CORE_SOURCES/Library" ]; then
        $ECHO "Copying /Library..."
        $CP_CMD "$CORE_SOURCES"/Library /
    fi
    if [ -d "$CORE_SOURCES/usr/NextSpace" ]; then
        $ECHO "Copying /usr/NextSpace..."
        $CP_CMD "$CORE_SOURCES"/usr/NextSpace /usr
    fi
else
    if [ -d /usr/NextSpace ]; then
        $ECHO "No binary distribution tree found; using existing /usr/NextSpace installation."
        if [ ! -f /etc/ld.so.conf.d/nextspace.conf ]; then
            $MKDIR_CMD -v /etc/ld.so.conf.d
            echo "/usr/NextSpace/lib" | sudo tee /etc/ld.so.conf.d/nextspace.conf >/dev/null
        fi
    else
        $ECHO "ERROR: /usr/NextSpace was not created by the source build."
        $ECHO "If you need to install from a binary distribution tree, pass that path as the first argument."
        exit 1
    fi
fi
refresh_ldconfig

#=========================================================================
# More X drivers. Workaround until NextSpace RPMs include them as dependencies
#=========================================================================
$ECHO "\033[1m"
$ECHO "========================================================================="
$ECHO "Installing X11 drivers and utilities..."
$ECHO "========================================================================="
$ECHO_N "\033[0m"
if is_debian_like; then
    install_apt_packages xserver-xorg-input-all xserver-xorg-video-all
elif [ "${OS_ID}" = "fedora" ] || [ "${OS_ID}" = "ultramarine" ]; then
    install_rpm_packages xorg-x11-drivers xorg-x11-xinit
fi
$ECHO "\033[32m Done! \033[0m"

$ECHO "\033[1m"
$ECHO "========================================================================="
$ECHO "Performing system check and configuration..."
$ECHO "========================================================================="
$ECHO_N "\033[0m"
#=========================================================================
# Hostname in /etc/hosts
#=========================================================================
setup_hosts

if [ "${OS_ID}" = "fedora" ] || [ "${OS_ID}" = "ultramarine" ]; then
    $ECHO "Preparing Fedora service executable contexts..."
    for ns_exec in /Library/bin/gdomap /Library/bin/gdnc /Library/bin/gpbs; do
        if [ -f "$ns_exec" ]; then
            sudo chmod 755 "$ns_exec" 2>/dev/null
            if command -v chcon >/dev/null 2>&1; then
                sudo chcon -t bin_t "$ns_exec" 2>/dev/null
            fi
        fi
    done
fi

#=========================================================================
# Enable services
#=========================================================================
sudo systemctl daemon-reload
$ECHO "Checking for Distributed Objects Mapper..."
systemctl --quiet is-enabled gdomap
if [ $? -ne 0 ];then
    $ECHO "  gdomap: enabling"
    sudo systemctl enable /usr/NextSpace/lib/systemd/gdomap.service
else
    $ECHO "  gdomap: enabled"
fi
start_service_if_possible gdomap /Library/bin/gdomap || exit 1
$ECHO "Checking for Distributed Notification Center..."
systemctl --quiet is-enabled gdnc
if [ $? -ne 0 ];then
    $ECHO "  gdnc: enabling"
    sudo systemctl enable /usr/NextSpace/lib/systemd/gdnc.service
    sudo systemctl enable /usr/NextSpace/lib/systemd/gdnc-local.service
else
    $ECHO "  gdnc: enabled"
fi
start_service_if_possible gdnc /Library/bin/gdnc || exit 1
start_service_if_possible gdnc-local /Library/bin/gdnc || exit 1
$ECHO "Checking for Pasteboard..."
systemctl --quiet is-enabled gpbs
if [ $? -ne 0 ];then
    $ECHO "  gpbs: enabling"
    sudo systemctl enable /usr/NextSpace/lib/systemd/gpbs.service
else
    $ECHO "  gpbs: enabled"
fi
start_service_if_possible gpbs /Library/bin/gpbs || exit 1
$ECHO "Checking for Login panel..."
systemctl --quiet is-enabled loginwindow
if [ $? -ne 0 ];then
    $ECHO "  loginwindow: enabling"
    sudo systemctl enable /usr/NextSpace/lib/systemd/loginwindow.service
else
    $ECHO "  loginwindow: enabled"
fi

#=========================================================================
# SELinux configuration
#=========================================================================
#setup_selinux

$ECHO_N "\033[1m"
$ECHO "========================================================================="
$ECHO "Post-install optional configuration"
$ECHO "========================================================================="
$ECHO_N "\033[0m"

# Adding user
add_user

# Setting up Login Panel
setup_loginwindow

# Setting up Plymouth boot splash on Debian
configure_debian_plymouth_boot || exit 1


$ECHO "\033[32m"
$ECHO "========================================================================="
$ECHO "    NEXTSPACE $RELEASE successfuly installed! Wolcome to the NeXT world! "
$ECHO "========================================================================="
$ECHO "\033[0m"
