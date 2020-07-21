# NextSpace additions to /etc/profile

NS_PATH="/usr/NextSpace/bin:/Library/bin:/usr/NextSpace/sbin:/Library/sbin"
export PATH=$NS_PATH:$PATH

export MANPATH=:/Library/Documentation/man:/usr/NextSpace/Documentation/man

# Initialize time zone to system time zone, but only if not yet set.
# NSGlobalDomain preference. Format 'Local Time Zone' = Europe/Kiev
defaults read NSGlobalDomain "Local Time Zone" 2>&1 > /dev/null
if [ $? -ne 0 ]; then
    echo "Updating `Local Time Zone` preference..."
    TZ=`/usr/bin/env -i stat --printf "%N\n" /etc/localtime |sed "s,.*-> '.*/zoneinfo/\([^']*\)',\1,"`
    defaults write NSGlobalDomain "Local Time Zone" $TZ
fi
### NSString encoding should be determined from system locale
#export GNUSTEP_STRING_ENCODING="NSUTF8StringEncoding"
### LANGUAGES moved into NSLanguages in NSGlobalDomain preferences
#export LANGUAGES="English"

# If development package was installed set Gnustep developer variable
if [ -d /Developer/Makefiles ];then
    export GNUSTEP_MAKEFILES="/Developer/Makefiles"
    if [ -f /opt/rh/llvm-toolset-7.0/enable ];then
        source /opt/rh/llvm-toolset-7.0/enable
    fi
fi

# Only user home lib dir here. Others in /etc/ld.so.conf.d/nextspace.conf
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$HOME/Library/Libraries"
export GNUSTEP_PATHLIST="$HOME:/:/usr/NextSpace:/Network"
export INFOPATH="$HOME/Library/Documentation/info:/Library/Documentation/info:/usr/NextSpace/Documentation/info"

export COLUMNS

export NS_SYSTEM="/usr/NextSpace"

# Log file
export USER=`whoami`
export UID=`id -u`
GS_SECURE="/tmp/GNUstepSecure"$UID
export LOGFILE="$GS_SECURE/console.log"
if [ ! -d $GS_SECURE ];then
    mkdir $GS_SECURE
    chmod 700 $GS_SECURE
fi
        
# Replace ~/.zshrc with NextSpace supplied version
if [ $SHELL == "/bin/zsh" ]; then
    if [ -f ~/.zshrc.nextspace ]; then
        echo "Replacing .zshrc with .zshrc.nextspace"
        mv -f ~/.zshrc.nextspace ~/.zshrc
    fi
fi

