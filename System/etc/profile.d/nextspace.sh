# NextSpace additions to /etc/profile

NS_PATH="/usr/NextSpace/bin:/Library/bin:/usr/NextSpace/sbin:/Library/sbin"
export PATH=$NS_PATH:$PATH

export MANPATH=:/Library/Documentation/man:/usr/NextSpace/Documentation/man

### Moved into NSGlobalDomain prefs. Format 'Local Time Zone' = Europe/Kiev
#export GNUSTEP_TZ=`cat /etc/timezone`
### NSString encoding should be determined from system locale
#export GNUSTEP_STRING_ENCODING="NSUTF8StringEncoding"
### LANGUAGES moved into NSLanguages in NSGlobalDomain preferences
#export LANGUAGES="English"

# If development package was installed set Gnustep developer variable
if [ -d /Developer/Makefiles ];then
    export GNUSTEP_MAKEFILES="/Developer/Makefiles"
fi

# Only user home lib dir here. Others in /etc/ld.so.conf.d/nextspace.conf
export LD_LIBRARY_PATH="$HOME/Library/Libraries"
export GNUSTEP_PATHLIST="$HOME:/:/usr/NextSpace:/Network"
export INFOPATH="$HOME/Library/Documentation/info:/Library/Documentation/info:/usr/NextSpace/Documentation/info"

export COLUMNS

export LC_CTYPE="en_US.UTF-8"

export NS_SYSTEM="/usr/NextSpace"

# Log file
export USER=`whoami`
GS_SECURE="/tmp/GNUstepSecure"$UID
export LOGFILE="$GS_SECURE/console.log"
if [ ! -d $GS_SECURE ];then
    mkdir $GS_SECURE
    chmod 700 $GS_SECURE
fi
        
