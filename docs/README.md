# Release 0.90

General
---
- Based on latest release of GNUstep libraries with some custom patches and improvements which are left unmerged to `master` branch. GNUstep GUI and Back now have `nextspace` branch to hold these specific changes.
- Switched to use LLVM/clang from distribution repositories (SCL for CentOS 7, CentOS 8 and Fedora already have correct compiler).
- Reduced debug output to console.
- WRaster library moved out of Workspace and can be used by GNUstep Back as shared library.
- Configured CircleCI automated build check.
- /etc/skel/.zshrc renamed to .zshrc.nextspace to prevent conflict with zsh RPM resource file.
- Numerous SoundKit fixes and improvements.
- Created scripts for automated creation of RPM packages.

Applications
---
### Login
- Startup and shutdown sequences were re-engineered. Login completely handles Xorg start and stop. loginwindow.service now handles only Login (doesn't kill Xorg on service stop).
- Defauls splitted into system (/usr/NextSpace/Preferences/Login) and user ($HOME/Library/Preferences/.NextSpace/Login). User defaults is a place were login/logout hooks are placed by "Login Preferences".
- "LoginHook" and "LogoutHook" preferences were added to defaults file.
- On unclean exit of user session dialog is shown to select restart (keep running application) or cleanup (kill user applications).
- Fixed panel positioning on monitor dimension and monitor layout changes.
- Fixed bug specific to Linux child processes handling: by default SIGCHLD signal handler is set to `SIG_IGN`. In this case `waitpid()` returns `-1` with error explained as "No child process" - waitpid looses tracked child process by some away. To prevent it from happening signal handler should be set to `SIG_DFL`.

### Workspace
  - Copy operation now 4 times faster for large files.
  - "Shutdown" and "Power Off" return exit code for correct Login application handling. Workspace returns exit code `11` on quit if "Power Off" button was pressed. As a result Login application performs OS shutdown without ordering front panel - should switch to Plymouth shutdown screen.
  - Current keyboard layout now displayed in first Dock icon - quite ugly but it remains until I'll find better design solution (window titlebar is not an option for me - it's ugly too).
  - Bell sound is played via SoundKit with "event" type, so it can be controlled via "System Sounds" application/stream in Mixer.
  - While window moved/resized current window position/size displayed in window titlebar temporary replacing application titlebar text.
  - Help Panel was added as result of NXTHelpPanel (table of contents, index, clickable links in articles, backtrack).
  - Console on-the-fly applies font changed in "Font Preferences".
  - Reuse appicon created by launch from FileViewer for appeared application instead of creating new and remove icon with 'launching' state.
  - Improved application execution handling. When application double-clicked in FileViewer several things happen:
    - icon slides down to IconYard and appicon with 'launching' state created holding WM name and command;
    - if application quits with error (no app was started) appicon removed from screen and alert panel appears;
    - after successful startup of application 'launching' appicon get used as normal application icon.
  - Ubuntu and Fedora logos were added.
  - Running apps' appicons which are dragged out of the Dock are automatically slides into the Icon Yard now.
  - Launcher: Workspace Launcher: changed completion logic: on first Escape press directory name completed, on second press - shows directory contents in completion list.
  - Fixed alpha channel handling while drawing application icons.
  - Set `_NET_WM_WINDOW_TYPE_DOCK` property to icon core window. This helps compositing managers like compton correctly handle dock icons and miniwindows.
  - Some fixes to Recycler icon positioning.
  - Xinerama support replaced with XRandR.
  - WINGs and WUtil libraries now compiled statically so vanilla WindowMaker may be installed aside.
  - Fixed WM's internal string drawing: prevents appearance of `RenderBadPicture` X internal error in Console.

### Preferences
  - Login: add initial implementation of - you can setup login and logout hooks now.
  - Password: added implementation (needs more testing).
  - Font: sends notification on font changes to NSDistributedNotificationCenter.
  - Sound: was implemented (uses SoundKit).
  - honor system keyboard settings if no keyboard preferences found in defaults file.
  - Keyboard: added data and UI elements for keyboard model selection section.

Frameworks
---
### DesktopKit
  - Implemented `NXTOpenPanel : NXTSavePanel` and `NXTSavePanel : NSSavePanel`. Differences to NSOpenPanel and NSSavePanel:
    - No icons in browser.
    - Keyboard focus always stays in textfield but Up/Down/Left/Right arrow keys browsing still available (Left/Right only if texfield is empty).
    - Improved performance of scrolling through the list on long Down/Up key press.
    - Selecting directory with keyboard requires `Enter` key press to load directory contents.
    - Unified with File Viewer sorting and displaying hidden files (configurable through "Expert Preferences" "Sort By" and "Show Hidden Files" options).
    - Panels save/restore its position and size;
    - `Escape` key press pastes current path into textfield - default completion shortcut (also used in Workspace's Finder).  
  - NXTSound: new class to play sounds leveraging SoundKit.
  - NXTAlert: set window level to modal; fixed placement of programatically created panel.
  - NXTIcon: fixed problem of NXTIcon usage inside one application but from different classes.
  - Fixed and optimized label resizing in edit mode. Problem: if NSTextView is not sized to draw new character or text GSLayoutManager fails to find glyph for character and label doesn't receive textDidChange: message. Now NXTIconLabel receive adjust it's frame in insertText: method (called before GSLayouManager's methods) and paste:.
  - NXTListView: new class for creating comprehensive (attributed text, icons, sections) lists.
  - NXTHelpPanel: NeXT-style application help panel usually available at "Info->Help..." menu item.
  - Helvetica.nfont: recreate bitmaps for sizes 8,10,12,14 for Medium, Bold and Oblique.
  - Keith.nfont: created new fixed width font similar to Ohlfs NeXTSTEP font.
