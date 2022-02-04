#include "screen.h"
#include "menu.h"
#include "application.h"

WMenu *wApplicationMenuCreate(WScreen *scr, WApplication *wapp);
void wApplicationMenuDestroy(WApplication *wapp);
void wApplicationMenuOpen(WApplication *wapp, int x, int y);
void wApplicationMenuHide(WMenu *menu);
void wApplicationMenuShow(WMenu *menu);

void wApplicationMenuSaveState(WMenu *main_menu, CFMutableArrayRef menus_state);
void wApplicationMenuRestoreFromState(WMenu *menu, CFArrayRef state);

