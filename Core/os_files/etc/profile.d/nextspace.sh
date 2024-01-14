### NextSpace additions to /etc/profile

#
# Paths
#
NS_PATH="/usr/NextSpace/bin:/Library/bin:/usr/NextSpace/sbin:/Library/sbin"
export PATH=$NS_PATH:$PATH
export MANPATH=:/Library/Documentation/man:/usr/NextSpace/Documentation/man
# Only user home lib dir here. Others in /etc/ld.so.conf.d/nextspace.conf
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$HOME/Library/Libraries"
export GNUSTEP_PATHLIST="$HOME:/:/usr/NextSpace:/Network"
export INFOPATH="$HOME/Library/Documentation/info:/Library/Documentation/info:/usr/NextSpace/Documentation/info"

#
# Localization
#
# Initialize time zone to system time zone, but only if not yet set.
if [ -x /Library/bin/defautls ];then
    defaults read NSGlobalDomain "Local Time Zone" 2>&1 > /dev/null
    if [ $? -ne 0 ]; then
        echo "Updating 'Local Time Zone' preference..."
        TZ=`/usr/bin/env -i stat --printf "%N\n" /etc/localtime |sed "s,.*-> '.*/zoneinfo/\([^']*\)',\1,"`
        defaults write NSGlobalDomain "Local Time Zone" $TZ
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
