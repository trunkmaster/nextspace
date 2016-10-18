# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin

export PATH

. /usr/NextSpace/etc/profile

clear
cd ~/
echo "Welcome to the NeXT world!"
