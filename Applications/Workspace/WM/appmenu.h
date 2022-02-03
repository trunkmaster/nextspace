#include "screen.h"
#include "menu.h"
#include "application.h"

WMenu *wApplicationMenuCreate(WScreen *scr, WApplication *wapp);
void wApplicationMenuDestroy(WApplication *wapp);
void wApplicationMenuOpen(WApplication *wapp, int x, int y);
void wApplicationMenuClose(WApplication *wapp);

void wApplicationMenuSaveState(WMenu *main_menu, CFMutableArrayRef menus_state, Boolean is_live);
void wApplicationMenuRestoreFromState(WApplication *wapp, CFArrayRef state);

