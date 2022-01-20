#include "screen.h"
#include "menu.h"
#include "application.h"

WMenu *wApplicationMenuCreate(WScreen *scr, WApplication *wapp);
void wApplicationMenuDestroy(WApplication *wapp);
void wApplicationMenuOpen(WApplication *wapp, int x, int y);
void wApplicationMenuClose(WApplication *wapp);

CFDictionaryRef wApplicationMenuGetState(WMenu *main_menu);
