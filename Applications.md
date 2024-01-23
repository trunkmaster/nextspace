# Applications
Below is a brief description of core applications. More information about application functionality will be added in the future.

## Login
[Status of implementation](https://github.com/trunkmaster/nextspace/projects/6)

A simple login panel where you enter your user name and password. No screenshot - it's an exact copy of NeXTSTEP's `loginwindow` in terms of look and feel.

## Workspace
[Status of implementation](https://github.com/trunkmaster/nextspace/projects/4)

A fast and elegant Workspace Manager using multithreading to provide maximum smoothness for:
* File system navigation, file management (create, copy, move, link files/directories).
* Seamless application, process, and window management (start, autostart, close, resize, move, maximize, miniaturize, hide).
* macOS-style window resizing: the cursor stops moving when the maximum/minimum size of a window has been reached, and the cursor changes its image to give a hint for available directions.
* Virtual desktops, Dock, applications and window icons.
* Media management - automatically mounting removable media, providing menu items to eject/mount/unmount removables.
* Background processes - all file and media management operations have status indicators with controls (stop, pause, cancel).
* Launcher - a panel to run commands with autocompletion and history.
* Recycler - support for drag-and-drop and the ability to restore recycled objects to their original location with a single click.
* Other: inspectors for various types of contents, finder, console messages and preferences for various parts of Workspace.

> Note: Workspace is NOT:
> * WindowMaker with some patches
> * WindowMaker with some good configuration defaults only
> * Another implementation of WindowMaker.
> 
> Workspace is written from scratch. Some WindowMaker code is a part of Workspace (as well as configuration defaults) to provide window management functions. The code is tightly coupled with Workspace to provide seamless intergation. Configurable parameters of the integrated WindowMaker are spread across Workspace's Preferences and Preferences application.

![Workspace](Documentation/Workspace.png)

## Preferences
[Status of implementation](https://github.com/trunkmaster/nextspace/projects/2)

Settings for locale, fonts, displays (size, brightness, contrast (gamma correction), desktop background, displays arrangement), keyboard (repeat, layouts, numpad behaviour, modifiers), mouse (delay, threshold, scrollwheel settings, mouse buttons configutation), sound, network, power management.

![Display](Documentation/Preferences-Display.png) ![Screen](Documentation/Preferences-Screen.png) 
![Mouse](Documentation/Preferences-Mouse.png) ![Keypard](Documentation/Preferences-Keyboard.png)

## Terminal
[Status of implementation](https://github.com/trunkmaster/nextspace/projects/3)

A terminal with Linux console emulation. I've started with the version created by Alexander Malmberg and made numerous fixes and enhancements. The original application can be found on the [GNUstep Application Project](http://www.nongnu.org/gap/terminal/index.html) site. Enhancements to the original application are numerous. Some of them are as follows:
* Preferences and Services panels rewritten from scratch.
* Numerous fixes and enhancements in: color management (background/foreground elements can be set to any color), cursor placement fixes on scrolling and window resizing, and the addition of 'Clear Buffer' and 'Set Title' menu items.
* Search through the text displayed in the terminal window (Find panel).
* Session management: you can save a window with all its settings that are set in the preferences panel (including any running shells/commands) to a file and then open it. Configuration with multiple windows is supported.

![Terminals](Documentation/Terminals.png)