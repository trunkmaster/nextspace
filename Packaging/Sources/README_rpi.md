# Porting NeXTspace to Raspberry SBC

# Hardware

The code is adapted to deal with Raspberry SBC.

- Model: pi400
- Architecture: aarch64
- GPU: VideoCore VI
- RAM: 4Gb

# Status

- Date: Mon. Feb. 10th
None of the following tries are complete.
Todo : Login.app issues and Xorg issues in several cases.

## OS: Debian

- OS Version: 12
- Revision: 12.9
- Flavour: Lite img from Raspberry Pi Imager menu
- Storage: SD card 16 GB
- Need PR: yes
- PR submitted: todo

### Status

It is usable. See kwown minor issues at the orignal Github repo of Trunkmaster.

- BUILD (all STAGES): OK

- LOADING Workspace from `startx` and with `$HOME/.xinitrc` :
  1) First attempt: issue with HD resolution (flickering). Workaround: in `Prefrences.app`, set resolution and refresh rate to:
   > 1680x1050 @60Hz
  2) Following launches: OK.

- LOGIN.APP: not yet tested again. Known to flicker with default HD resolution.

## OS: Ultramarine

- OS Version: 40
- OS Like: Fedora
- Flavour: Lite img from Raspberry Pi Imager menu
- Storage: SD card 16 GB
- Need PR: yes
- PR submitted: not yet (see status)

### Status

It is useless. See major following issue.

- BUILD (all STAGES): OK 

- LOADING Workspace from `startx` and with `$HOME/.xinitrc` :
  - **Issue**: _console.log_ said:
    > Workspace [1337:1337] NSColor.m:279 Assertion failed in void initSystemColors(void). couldn't get default system color of selectedKnobColor.
    > XIO: fatal IO error 2 (No such file or directory) on X server ":0" after 75 requests.

  - To investigate: is the driver vc4-kms-v3d loaded ? Other WM (i3wm) seems OK... 

## OS: FreeBSD

TODO
