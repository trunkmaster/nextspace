# ChangeLog Release 0.90

### General
- Switched to latest release of GNUstep libraries with some custom patches and improvements which are left unmerged. GNUstep GUI and Back now have "nextspace" branch to hold these changes.
- Switched to use LLVM/clang from distribution repositories (SCL for CentOS 7, CentOS 8 and Fedora already have correct compiler).
- Reduced debug output to console.
- WRaster library moved out of Workspace and can be used by GNUstep Back as shared library.
- Configured CircleCI automated build check.
- /etc/skel/.zshrc renamed to .zshrc.nextspace to prevent conflict with zsh RPM resource file.

### SoundKit
- numerous bugfixes and improvements

### Login
- Startup and shutdown sequences were re-engineered and now looks good.
- "LoginHook" and "LogoutHook" preferences were added to defaults file.
- On unclean exit of user session show dialog to select restart or cleanup.
- Fixed panel positioning on monitor dimension and monitor layout changes.

### Workspace
  - Copy operation now 4 times faster;
  - "Shutdown" and "Power Off" return exit code for correct Login application handling;
  - While window moved/resized current window position/size displayed in window titlebar temporary replacing application titlebar text;
  - Help Panel was added as result of NXTHelpPanel (table of contents, index, clickable links in articles, backtrack);
  - Console on-the-fly applies font changed in "Font Preferences";
  - Reuse appicon created by launch from FileViewer for appeared application instead of creating new and remove icon with 'launching' state;
  - Improved application execution handling. When application double-clicked in FileViewer several things happen:
    - icon slides down to IconYard and appicon with 'launching' state created holding WM name and command;
    - if application quits with error (no app was started) appicon removed from screen and alert panel appears;
    - after successful startup of application 'launching' appicon get used as normal application icon.
  - Ubuntu and Fedora logos were added;
  - Running apps' appicons which are dragged out of the Dock are automatically slides into the Icon Yard now.
  - Launcher: Workspace Launcher: changed completion logic: on first Escape press directory name completed, on second press - shows directory contents in completion list;
  - Fixed alpha channel handling while drawing application icons;
  - Set `_NET_WM_WINDOW_TYPE_DOCK` property to icon core window. This helps compositing managers like compton correctly handle dock icons and miniwindows.
  - Some fixes to Recycler icon positioning.
  - Xinerama support replaced with XRandR.
  - WINGs and WUtil libraries now compiled statically so vanilla WindowMaker may be installed aside.
  - Fixed WM's internal string drawing: prevents appearance of `RenderBadPicture` X internal error in Console.

### Preferences
  - Login: add initial implementation of - you can setup login and logout hooks now;
  - Password: added implementation (needs more testing);
  - Font: sends notification on font changes to NSDistributedNotificationCenter;
  - Sound: was implemented (uses SoundKit);
  - honor system keyboard settings if no keyboard preferences found in defaults file;
  - Keyboard: added data and UI elements for keyboard model selection section

### DesktopKit
  - NXTOpenPanel, NXTSavePanel: new custom open ans save panels.
    Much improved usability against vanilla GNUstep panels. 
    New panels honors “Show Hiddes Files” setting (Expert Preferences in Preferences application).
  - NXTSound: new class to play sounds leveraging SoundKit;
  - NXTAlert: set window level to modal; fixed placement of programatically created panel;
  - NXTIcon: fixed problem of NXTIcon usage inside one application but from different classes;
  - Fixed and optimized label resizing in edit mode. Problem: if NSTextView is not sized to draw new character or text GSLayoutManager fails to find glyph for character and label doesn't receive textDidChange: message. Now NXTIconLabel receive adjust it's frame in insertText: method (called before GSLayouManager's methods) and paste:.
  - NXTListView: new class for creating comprehensive (attributed text, icons, sections) lists;
  - NXTHelpPanel: 
  - Helvetica.nfont: recreate bitmaps for sizes 8,10,12,14 for Medium, Bold and Oblique;
  - Keith.nfont: created new fixed width font similar to Ohlfs NeXTSTEP font;
  
  - NXTFileManager: now it's a subcluss of NSFileManager;

