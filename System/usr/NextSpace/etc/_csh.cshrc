# $FreeBSD: src/etc/root/dot.cshrc,v 1.30 2007/05/29 06:37:58 dougb Exp $
# .cshrc - csh resource script, read at beginning of execution by each shell
# see also csh(1), environ(7).
# Default file

alias h		history 25
alias j		jobs -l
alias la	ls -a
alias lf	ls -FA
alias ll	ls -lA

# A righteous umask
umask 22

#set path = (/sbin /bin /usr/sbin /usr/bin /usr/games /usr/local/sbin /usr/local/bin $HOME/bin)

setenv	EDITOR	vi
setenv	PAGER	more
setenv	BLOCKSIZE	K

if ($?prompt) then
	# An interactive shell -- set some stuff up
	set userid = `id -u`
	if ( "${userid}" == "0" ) then
	    set prompt = "`/bin/hostname -s`# "
	else
	    set prompt = "`/bin/hostname -s`> "
	endif
	unset userid
	set filec
	set history = 100
	set savehist = 100
	set mail = (/var/mail/$USER)
	if ( $?tcsh ) then
		bindkey "^W" backward-delete-word
		bindkey -k up history-search-backward
		bindkey -k down history-search-forward
	endif
endif

#------------------------------------------------------------------------------
# System-wide .cshrc file for csh(1).
# CUBE modifications
#------------------------------------------------------------------------------
set nobeep

set path = (/private/bin /private/sbin /sbin /bin /usr/sbin /usr/bin /usr/games /usr/local/sbin /usr/local/bin $HOME/bin)

#setenv GNUSTEP_TZ `cat /etc/timezone`
setenv GNUSTEP_STRING_ENCODING "NSUTF8StringEncoding"
setenv LANGUAGES "English"

setenv GNUSTEP_MAKEFILES "/Developer/Makefiles"
setenv LIBRARY_COMBO "gnu-gnu-gnu"
setenv GNUSTEP_PATHLIST "${HOME}:/Local:/Network:/System"
setenv LD_LIBRARY_PATH "/Library/Libraries:/LocalLibrary/Libraries:$HOME/Library/Libraries"
setenv INFOPATH "$HOME/Library/Documentation/info:/Library/Documentation/info:/LocalLibrary/Documentation/info"

#source /Developer/Makefiles/GNUstep.csh
### Temporary should be fixed in GNUstep
#unsetenv GNUSTEP_FLATTENED
#unsetenv GNUSTEP_LOCAL_ROOT
#unsetenv GNUSTEP_NETWORK_ROOT
#unsetenv GNUSTEP_SYSTEM_ROOT
#unsetenv GNUSTEP_USER_DIR
#unsetenv GNUSTEP_USER_ROOT

#------------------------------------------------------------------------------
# 'root' user specific environment
#------------------------------------------------------------------------------
set userid = `id -u`
if ( "${userid}" == "0" ) then
	# CUBE building
	setenv CUBE_FILES "/private/etc/CUBE"
	
	# Ports building
#	setenv MAKEOBJDIRPREFIX  "/Developer/Sources/BSD/obj"
#	setenv DESTDIR  "/Developer/Sources/BSD/dist"
#	setenv PORTSDIR "/Developer/Sources/BSD/ports"
#	setenv DISTDIR  "/Developer/Packages/Sources"
#	setenv PACKAGES "/Developer/Packages/Fresh"
#	setenv PKGDIR "/Developer/Packages"
endif

#------------------------------------------------------------------------------
# User specific environment and startup programs
#------------------------------------------------------------------------------

### PATH
#if [ "$WMAKER_BIN_NAME" != "" ]; then
#    setenv PATH "$PATH:`dirname $WMAKER_BIN_NAME`"
#fi

### Terminals
#if [ "$TERM_PROGRAM" = "GNUstep_Terminal" ]; then
#  export COLUMNS
#    setterm -foreground black -background white -clear -store
#fi

setenv TERMCAP "/private/etc/termcap"

setenv DISPLAY :0.0
alias	startnewgui 'Xorg -config xorg.conf.new -br & ; openapp WindowMaker.app'
alias	startgui    'Xorg -br & ; openapp WindowMaker.app'

