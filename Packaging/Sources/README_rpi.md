# Porting NeXTspace to Raspberry SBC

# Hardware

The code is adapted to deal with Raspberry SBC.

- Model: pi400
- Architecture: aarch64
- GPU: VideoCore VI
- RAM: 4Gb
- Display: Acer, ACR Model 57e wired at HDMI port

# Date and updates

- Date: Mon. Feb. 10th of 2025; updated: Fri. 14th of 2025

## OS: Debian

- OS Version: 12
- Revision: 12.9
- Flavour: Debian Lite image from Raspberry Pi Imager menu
- Storage: SD card of 16 GB
- Need PR: yes
- PR submitted: from branch `rpi_aarch64_compatible`.

### Status

It works now: `Login.app`, `Workspace` and Applications.
See kwown issues at the orignal Github repo of [Trunkmaster/nextspace](https://github.com/trunkmaster/nextspace).

- **BUILD** (all STAGES): OK

- **Workspace** 
  1) LOADING first Workspace from `startx` and with `$HOME/.xinitrc` :
   a) First attempt: issue with HD resolution (flickering). Workaround: in `Prefrences.app`, set resolution and refresh rate to:
    > 1680x1050 @60Hz
   b) Following launches: OK.
  2) From `Login.app` (see above) : OK

- **LOGIN.APP display Manager**
  1) First attempt : was flickering after a new boot or reboot, nether after logout from Worpspace.
  2) Solved with `screen.resolution.conf` copied from `Core/os_files/etc/X11/xorg.conf.d` to `/etc/X11/xorg.conf.d/`.
  3) Now, inserted within `setup_display_manager`.

- **Applications**
  - Preferences: OK
  - NetMon: OK 
  - Terminal: OK
  - TextEdit: OK
  - 

## OS: Ultramarine

- OS Version: 40
- OS Like: Fedora
- Flavour: Lite Ultramarine image from Raspberry Pi Imager menu
- Storage: SD card 16 GB
- Need PR: not yet. Things to do.
- PR submitted: not yet (see status)

### Status

It is stuck. See major following issue.

- **BUILD** (all STAGES): OK 

- **Workspace** 
  1) LOADING Workspace from `startx` and with `$HOME/.xinitrc` :
  - **Issue**: _console.log_ said:
    > Workspace [1337:1337] NSColor.m:279 Assertion failed in void initSystemColors(void). couldn't get default system color of selectedKnobColor.
    > XIO: fatal IO error 2 (No such file or directory) on X server ":0" after 75 requests.

  - To investigate: is the driver vc4-kms-v3d loaded ? Other WM (i3wm) seems OK... 

## OS: FreeBSD

### Status

The firt difficulty is to establish the dependencies with native FreeBSD libs. No interest in a Linux compat mode...
To follow...
