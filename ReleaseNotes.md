This release introduces:
- numerous of bugfixes across the entire project;
- serious reengineering of Workspace and Window Manager including:
        - switch to Apple's CoreFoundation for internal data structures;
        - event handling of Window Manager was implemented with CFRunLoop, CFFileDescriptor and CFNotificationCenter;
        - use XML for configuration files;
        - implemented notitification interoperability between Objective C and C (external GNUstep applications may send notifications to Window Manager);
        - improved drag and drop between File Viewer and Dock;
        - implemented Cut/Copy/Paste operations for files and directories.
- feature completion of Terminal application, including: 
        - unlimited scrollback buffer support;
        - process tracking (Activity Monitor), display running program in titlebar;
        - miniwindow animation representing activity in minimized window;
        - automatic hide/show of mouse cursor.
- Workspace tracks for applications and services installation/removal, updates files in ~/Library/Services; 
- greatly improved script to build from sources - tested on Fedora, Ubuntu 22 and Debian 12.

Look into [changelog](https://github.com/trunkmaster/nextspace/blob/master/Documentation/Changelog-0.95.md) for details.

This release was built for 3 distributions of RedHat family: CentOS 7, Debian 12, Ubuntu 22.04, Fedora 39.
Packages are bundled into .tgz file for particular distribution and contains install script that automates install process.

Steps to install NextSpace (example for Fedora):

1. Download .tgz archive:
```
$ curl -L -O https://github.com/trunkmaster/nextspace/releases/download/0.95/NextSpace-0.95_Fedora-39.tgz
```
2. Unpack it:
```
$ tar zxf NextSpace-0.95_Fedora-39.tgz
```
3. Switch to the NextSpace-0.95 directory and run installer script:
```
$ cd NextSpace-0.95
$ ./nextspace_install.sh
```
Answer to the questions of nextspace_install.sh.