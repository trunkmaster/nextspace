#/bin/bash

yum remove nextspace* -y
yum remove libwraster* -y
yum remove libobjc2* -y
yum remove libcorefoundation* -y
yum remove libdispatch* -y
/bin/rm -rf /usr/NextSpace
/bin/rm -rf /usr/share/plymouth/themes/nextspace
/bin/rm -rf /Applications
/bin/rm -rf /Developer
/bin/rm -rf /Library
