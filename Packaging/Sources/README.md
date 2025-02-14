# Building NEXTSPACE from sources

The scripts in this directory should make it easier to build NEXTSPACE and libraries it depends on from source. 
Versions of components are the same as in .spec files located in respective source directories.

Each script preform the following actions:
- installs package which are required for build;
- download or copy sorces into build directory (BUILD_ROOT);
- runs build and install of component;

Scripts assume that you preform run inside this directory as user. Scripts use `sudo` to install build resultsa and ask you for the password when it's needed.

Build scripts were tested on:
- Debian 12, Ubuntu 22.04
- Fedora 35, 39
- Rocky Linux 9, Alma Linux 9 and CentOS Stream 9

## Build and install each dependency

Dependencies have to be built and installed in predetermined order like this:
```
$ ./0_build_libdispatch.sh
$ ./1_build_licorefoundation.sh
$ ./2_build_libobjc2.sh
$ ./3_build_core.sh
$ ./3_build_tools-make.sh
$ ./4_build_libwraster.sh
$ ./5_build_libs-base.sh
$ ./6_build_libs-gui.sh
$ ./7_build_libs-back.sh
```
Once you install everything for the very first time, you can more selective as to what to build.

## Build and install NEXTSPACE itself

Building NEXTSPACE will simply use this source tree.
```
$ ./8_build_Frameworks.sh
$ ./9_build_Applications.sh
```

## Installing default profile and configuration and Post-Install

If you omit running `setup_user_home.sh` script at installation time, configartion files available at /etc/skel directory.

Before you can run NEXTSPACE, you need to make sure you install various scripts and configurations that the NEXTSPACE depends on at runtime. Some stuff is system-wide and it need to be installed by root, other is installed in user's home directory. For this reason you should run the following installation script twice. 
```
$ sudo ./setup_user_home.sh
$ ./setup_user_home.sh
```

Before installing a display manager, you should test NeXTspace:

`startx`

Maybe Your Screen is "flickering" due to a bad resolution:
1) Try open `Preferences.app` (double click on the clock inside the Dock)
2) In the tab "Display Preferences", choose another resolution that works.
3) Note this: i.e.: "1680x1050"
4) Logout the Workspace.
5) Then edit and set the resolution in the field "Modes" inside:
  `nextspace/Core/os_files/etc/X11/xorg.conf.d/screen.resolution.conf`

Install the Display Manager.

```
$ ./setup_display_manager.sh
```


User home directory profile consists of the following components:
- ~/Library contents contains NEXTSPACE and GNUstep specific data (configuration, caches, fonts and so on)
- ~/.config/fontconfig/fonts.conf - X11-specific fonts handling settings. Adds /Library/Fouts and ~/Library/Fonts to font path - make .nfont packages contents available to non-GNUstep applications
- ~/.config/pulse - PulseAudio-specific settings
