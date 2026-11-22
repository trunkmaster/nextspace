# Virtual desktop shortcuts

The default desktop shortcut family uses physical Control and Alt:

| Shortcut | Action |
| --- | --- |
| Ctrl+Alt+1–9 | Desktop 1–9 |
| Ctrl+Alt+0 | Desktop 10 |
| Ctrl+Alt+Left / Right | Previous / next desktop |

These are the WM preference keys `Desktop1Key` through `Desktop10Key`,
`PrevWorkspaceKey`, and `NextWorkspaceKey` in
`~/Library/Preferences/.NextSpace/WM.plist`. Existing explicit preferences
continue to override source defaults. Set an individual shortcut to `None` to
disable it. The existing CycleWorkspaces and AdvanceToNewWorkspace preferences
still govern relative navigation at the desktop boundaries.

Desktop shortcuts are reserved globally before application-menu shortcuts and
work with a focused application or the desktop background. Other WM shortcut
priorities are unchanged. Explicit X11 keyboard grabs, including some modal
menus or lock screens, can temporarily take precedence.

The WM installs root-window grabs as well as its existing frame grabs, using
its ignored lock-modifier combinations. Rebinding releases the previous exact
root grabs. Keyboard-map notifications must reach the WM through its embedded
event layer: Preferences may apply a layout after WM startup, changing the
keycodes for Left and Right. Refreshing Xlib's cache without resolving the
configured shortcut strings again leaves stale passive grabs.

Validation on FreeBSD includes direct and relative navigation in File Viewer,
Terminal and an AppKit text field; unchanged field contents; no unintended menu
actions; no bytes from desktop chords in a raw Terminal PTY; Caps Lock and Num
Lock; background focus; live rebinding; and changing/restoring the Right key's
keycode after startup. Native menu-action instrumentation includes a positive
control to ensure it detects a real Finder invocation.

Finder opening at login is independent saved-window behavior. Workspace restores
an entry with `Type = Finder; State = Normal` in the `SavedWindows` array in
`~/Library/Preferences/.NextSpace/Workspace`. Close Finder normally before
logout if it should not be restored. When repairing saved state while Workspace
is stopped, remove only its Finder entry and preserve other entries. Use a
GNUstep-compatible plist editor: this file can contain extended plist keys that
Apple XML serialization cannot preserve.
