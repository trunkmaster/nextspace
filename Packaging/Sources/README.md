# Building ArchSTEP from sources

The scripts in this directory build ArchSTEP and the libraries it depends on from source, on **Arch Linux only** (`environment.sh` refuses anything else).

Each script performs the following actions:
- installs the pacman packages required for the build (see `arch.deps.sh`);
- downloads or copies sources into the build directory (`BUILD_ROOT`);
- builds and installs the component.

Run the scripts from inside this directory as a regular user. They use `sudo` for package installation and `make install`, and will ask for your password when needed.

## Build and install each dependency

Dependencies have to be built and installed in this order:
```
$ ./0_build_libdispatch.sh
$ ./1_build_libcorefoundation.sh
$ ./2_build_libobjc2.sh
$ ./3_build_core.sh
$ ./3_build_tools-make.sh
$ ./4_build_libwraster.sh
$ ./5_build_libs-base.sh
$ ./6_build_libs-gui.sh
$ ./7_build_libs-back.sh
```
Once everything is installed for the first time, you can be more selective about what to rebuild.

## Build and install ArchSTEP itself

```
$ ./8_build_Frameworks.sh
$ ./9_build_Applications.sh
```

## Installing default profile and configuration

If you omit running `setup_user_home.sh` at installation time, configuration files are available in /etc/skel.

Before you can run ArchSTEP, various scripts and configurations need to be installed at runtime. Some are system-wide (installed by root), some go in the user's home directory — so run the script twice:
```
$ sudo ./setup_user_home.sh
$ ./setup_user_home.sh
```
Note that this is a "minimal" startup configuration which uses an xinitrc script to start everything (usually invoked via startx). To use Login.app as the display manager instead, enable its systemd unit (see roadmap M3) — preferably in a VM first.

User home directory profile consists of the following components:
- `~/Library` — ArchSTEP and GNUstep specific data (configuration, caches, fonts and so on)
- `~/.config/fontconfig/fonts.conf` — X11 font handling; adds /Library/Fonts and ~/Library/Fonts to the font path so .nfont package contents are available to non-GNUstep applications
- `~/.config/pulse` — PulseAudio-protocol settings (served by pipewire-pulse on Arch)
