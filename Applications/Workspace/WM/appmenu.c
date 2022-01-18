#include "core/log_utils.h"
#include <core/string_utils.h>

#include "appmenu.h"
#include "window.h"
#include "framewin.h"

// Main application menu
//-------------------------------------------------------------------------------------------------
static void nullCallback(WMenu *menu, WMenuEntry *entry)
{
  WMLogInfo("Item %s was clicked in menu %s", entry->text, menu->frame->title);
}

WMenu *wApplicationCreateMenu(WScreen *scr, WApplication *wapp)
{
  WMenu *menu, *info, *edit, *windows;
  WMenuEntry *info_item, *edit_item, *windows_item, *tmp_item;

  menu = wMenuCreate(scr, wapp->main_window_desc->wm_class, True);
  
  /* Info */

  info = wMenuCreate(scr, _("Info"), False);
  wMenuAddCallback(info, _("Info Panel..."), nullCallback, NULL);
  wMenuAddCallback(info, _("Legal..."), nullCallback, NULL);
  wMenuAddCallback(info, _("Preferences..."), nullCallback, NULL);
  info_item = wMenuAddCallback(menu, _("Info"), NULL, NULL);
  wMenuEntrySetCascade(menu, info_item, info);

  edit = wMenuCreate(scr, _("Edit"), False);
  wMenuAddCallback(edit, _("Cut"), nullCallback, NULL);
  wMenuAddCallback(edit, _("Copy"), nullCallback, NULL);
  wMenuAddCallback(edit, _("Paste"), nullCallback, NULL);
  wMenuAddCallback(edit, _("Select All"), nullCallback, NULL);
  edit_item = wMenuAddCallback(menu, _("Edit"), NULL, NULL);
  wMenuEntrySetCascade(menu, edit_item, edit);

  windows = wMenuCreate(scr, _("Windows"), False);
  wMenuAddCallback(windows, _("Arrange in Front"), nullCallback, NULL);
  wMenuAddCallback(windows, _("Miniaturize Window"), nullCallback, NULL);
  wMenuAddCallback(windows, _("Close Window"), nullCallback, NULL);
  wMenuAddCallback(windows, _("Select All"), nullCallback, NULL);
  windows_item = wMenuAddCallback(menu, _("Windows"), NULL, NULL);
  wMenuEntrySetCascade(menu, windows_item, windows);
  
  tmp_item = wMenuAddCallback(menu, _("Hide"), nullCallback, NULL);
  tmp_item->rtext = wstrdup("h");
  tmp_item = wMenuAddCallback(menu, _("Quit"), nullCallback, NULL);
  tmp_item->rtext = wstrdup("q");
  
  return menu;
}

void wApplicationOpenMenu(WApplication *wapp, int x, int y)
{
  WScreen *scr = wapp->main_window_desc->screen_ptr;
  WMenu *menu;
  int i;

  if (!wapp->menu) {
    WMLogError("Applicastion menu can't be opened because it was not created");
    return;
  }
  menu = wapp->menu;

  /* set client data */
  for (i = 0; i < menu->entry_no; i++) {
    menu->entries[i]->clientdata = wapp;
  }
  
  if (wapp->flags.hidden) {
    menu->entries[3]->text = wstrdup(_("Unhide"));
  } else {
    menu->entries[3]->text = wstrdup(_("Hide"));
  }

  menu->flags.realized = 0;
  wMenuRealize(menu);
  
  /* Place menu on screen */
  x -= menu->frame->core->width / 2;
  if (x + menu->frame->core->width > scr->scr_width) {
    x = scr->scr_width - menu->frame->core->width;
  }
  if (x < 0) {
    x = 0;
  }
  wMenuMapAt(menu, x, y, False);
}
