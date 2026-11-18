### NextSpace additions to /etc/profile

#
# Paths
#
NS_PATH="/usr/NextSpace/bin:/Library/bin:/usr/NextSpace/sbin:/Library/sbin"
export PATH=$NS_PATH:$PATH
export MANPATH=:/Library/Documentation/man:/usr/NextSpace/Documentation/man
# Only user home lib dir here. Others in /etc/ld.so.conf.d/nextspace.conf
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$HOME/Library/Libraries:/Library/Libraries:/usr/NextSpace/lib"
export GNUSTEP_PATHLIST="$HOME:/:/usr/NextSpace:/Network"
export INFOPATH="$HOME/Library/Documentation/info:/Library/Documentation/info:/usr/NextSpace/Documentation/info"

#
# Localization
#
# Initialize time zone to system time zone, but only if not yet set.
if [ -x /Library/bin/defaults ]; then
    if ! defaults read NSGlobalDomain "Local Time Zone" >/dev/null 2>&1; then
        ns_timezone=
        if [ -r /var/db/zoneinfo ]; then
            ns_timezone=$(head -n 1 /var/db/zoneinfo)
        else
            ns_timezone=$(readlink /etc/localtime 2>/dev/null || :)
            case "$ns_timezone" in
                */zoneinfo/*) ns_timezone=${ns_timezone#*/zoneinfo/} ;;
                *) ns_timezone= ;;
            esac
        fi
        if [ -n "$ns_timezone" ] && [ -f "/usr/share/zoneinfo/$ns_timezone" ]; then
            printf "Updating Local Time Zone preference...\n"
            defaults write NSGlobalDomain "Local Time Zone" "\"$ns_timezone\""
        fi
    fi
fi

export LC_CTYPE=$LANG
### NSString encoding should be determined from system locale
#export GNUSTEP_STRING_ENCODING="NSUTF8StringEncoding"
### LANGUAGES moved into NSLanguages in NSGlobalDomain preferences
#export LANGUAGES="English"

# CentOS 7: if Clang from SCLo was installed - setup GNUstep developer environment
if [ -d /Developer/Makefiles ];then
    export GNUSTEP_MAKEFILES="/Developer/Makefiles"
    if [ -f /opt/rh/llvm-toolset-7.0/enable ];then
        . /opt/rh/llvm-toolset-7.0/enable
    fi
fi

# Has been used in ~/,xinitrc - remove it?
export NS_SYSTEM="/usr/NextSpace"

#
# Log file
#
export USER=`whoami`
if [ ! -n "$UID" ];then
    export UID=`id -u`
fi
GS_SECURE="/tmp/GNUstepSecure"$UID
export LOGFILE="$GS_SECURE/console.log"
if [ ! -d $GS_SECURE ];then
    mkdir $GS_SECURE
    chmod 700 $GS_SECURE
fi
 
#
# ZSH: replace ~/.zshrc with NextSpace supplied version
#
if [ -n "$SHELL" -a "$SHELL" = "/bin/zsh" ]; then
    if [ -f ~/.zshrc.nextspace ]; then
        echo "Replacing .zshrc with .zshrc.nextspace"
        mv -f ~/.zshrc.nextspace ~/.zshrc
    fi
fi
