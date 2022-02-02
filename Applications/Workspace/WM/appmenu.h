#include "screen.h"
#include "menu.h"
#include "application.h"

WMenu *wApplicationMenuCreate(WScreen *scr, WApplication *wapp);
void wApplicationMenuDestroy(WApplication *wapp);
void wApplicationMenuOpen(WApplication *wapp, int x, int y);
void wApplicationMenuClose(WApplication *wapp);

CFArrayRef wApplicationMenuGetState(WMenu *main_menu);
void wApplicationMenuSaveState(WMenu *menu, CFMutableArrayRef menus_state);
void wApplicationMenuRestoreFromState(WMenu *main_menu, CFArrayRef state);

