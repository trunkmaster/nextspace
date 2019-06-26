Changes since 0.85 release of NEXTSPACE
===

Applications
---

**Login**

- some reengeneering of application was done;
- return code of Workspace application handled specifically: if `11` returned Login execute shutdown procedure without panel displayed; if `12` returned - executes reboot procedure;
- fixed bug specific to Linux child processes handling: by default SIGCHLD singnal handler is set to `SIG_IGN`. In this case `waitpid()` returns `-1` with error explained as "No child process" - waitpid looses tracked child proces by some away. To prevent ot from happening signal handler should be set to `SIG_DFL`;
- changed start sequence: Login completely handles Xorg start and stop; loginwindow.service now handles only Login (doesn't kill Xorg on service stop);
- defauls splitted into system (/root/Library/Preferences/.NextSpace/Login) and user ($HOME/Library/Preferences/.NextSpace/Login). User defaults is a place were login/logout hooks will be placed by Preferences;

**Workspace**

- Workspace returns exit code `11` on quit if "Power Off" button was pressed. As a result Login application performs OS shutdown without ordering front panel - should switch to Plymouth shutdown screen;

**Preferences**

- ;

Frameworks
---

**SoundKit**

- implemented play of sound bytes via the SNDPlayStream;
- SNDPlayStream and SNDRecord stream now have ability to pause/resume;