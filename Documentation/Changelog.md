# 0.90: changes since 0.85

## Login

- Some reengeneering of application was done.
- Return code of Workspace application handled specifically: if `11` returned Login execute shutdown procedure without panel displayed; if `12` returned - executes reboot procedure.
- Fixed bug specific to Linux child processes handling: by default SIGCHLD singnal handler is set to `SIG_IGN`. In this case `waitpid()` returns `-1` with error explained as "No child process" - waitpid looses tracked child proces by some away. To prevent ot from happening signal handler should be set to `SIG_DFL`.
- Start sequence was changed: Login completely handles Xorg start and stop; loginwindow.service now handles only Login (doesn't kill Xorg on service stop).
- Defauls splitted into system (/usr/NextSpace/Preferences/Login) and user ($HOME/Library/Preferences/.NextSpace/Login). User defaults is a place were login/logout hooks are placed by "Login Preferences".

### Workspace

- Workspace returns exit code `11` on quit if "Power Off" button was pressed. As a result Login application performs OS shutdown without ordering front panel - should switch to Plymouth shutdown screen.
- "Power Off" quit panel button now starts OS shutdown sequence.
- Current keyboard layout now displayed in first Dock icon - quite ugly but it remains until I'll find better design solution (window titlebar is not an option for me - it's ugly also).
- Bell sound is played via SoundKit with "event" type, so it can be controlled via "System Sounds" application/stream in Mixer.
- Improved application launching and status tracking:
	- launching appicon now reused as normal application icon;
	- if application failed to start launching appicon removed from screen;
	- application that started from FileViewer and ebnormally terminated (segfault, killed with signal) removed from Processes panel;
	- on quit do not try to terminate application if it cannot be connected (just remove from list of known applications).
- Copy operation speed improved. It's 4 times faster now.
- Appicon of runing application can be dragged out of the Dock. It automatically placed in the Icon Yard after mouse up.

### Preferences

- "Login Preferences" module was implemented:
	- implementation completed for "Login Hook", "Logout Hook", "Restore Last Logged In User Name", "Display Host Name".
	- "Display Host Name", "Restore Last Logged In User Name", screen saver, and custom UI and saver preferences can be changed by administrator (user that is member of `wheel` group).
- "Sound Preferences" now display configured "System Beep" with selection of sound in list at first module loading.
- "Password Preferences" module was implemented. Now I need to find out how to change PAM settings to change password as user without SUID bit set (as `passwd` command works).

## Frameworks

### DesktopKit

- Implemented `NXTOpenPanel : NXTSavePanel` and `NXTSavePanel : NSSavePanel`. 
  Differences to NSOpenPanel and NSSavePanel:
	- No icons in browser.
	- Keyboard focus always stays in textfield but Up/Down/Left/Right arrow keys browsing still available (Left/Right only if texfield is empty).
	- Improved performance of scrolling through the list on long Down/Up key press.
	- Selecting directory with keyboard reuires Enter key pres to load directory contents.
	- Unified with File Viewer sorting and displaying hidden files (configurable through "Expert Preferences" "Sort By" and "Show Hidden Files" options).
	- Panels save/restore its position and size;
	- Escape key press pastes current path into textfield - default completion shortcut (also used in Workspace's Finder).
- NXAlertPanel fixed setting size for multi-line messages.

### SoundKit

- implemented play of sound bytes via the SNDPlayStream;
- SNDPlayStream and SNDRecord stream now have ability to pause/resume;