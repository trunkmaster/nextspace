#include <string.h>
#include <core/log_utils.h>
#include <core/string_utils.h>

#include "appmenu.h"
#include "window.h"
#include "framewin.h"
#include "actions.h"

// Main application menu
//-------------------------------------------------------------------------------------------------
static void nullCallback(WMenu *menu, WMenuEntry *entry)
{
  WMLogInfo("Item %s was clicked in menu %s", entry->text, menu->frame->title);
}

static void mainCallback(WMenu *menu, WMenuEntry *entry)
{
  WApplication *wapp = (WApplication *)entry->clientdata;
  
  if (!strcmp(entry->text, "Hide")) {
    wHideApplication(wapp);
  } else if (!strcmp(entry->text, "Hide Others")) {
    wHideOtherApplications(wapp->last_focused);
  }
}

WMenu *wApplicationCreateMenu(WScreen *scr, WApplication *wapp)
{
  WMenu *menu, *info, *edit, *windows;
  WMenuEntry *info_item, *edit_item, *windows_item, *tmp_item;

  menu = wMenuCreate(scr, wapp->app_name, True);
  
  /* Info */

  info = wMenuCreate(scr, _("Info"), False);
  wMenuAddCallback(info, _("Info Panel..."), nullCallback, NULL);
  wMenuAddCallback(info, _("Legal..."), nullCallback, NULL);
  wMenuAddCallback(info, _("Preferences..."), nullCallback, NULL);
  info_item = wMenuAddCallback(menu, _("Info"), NULL, NULL);
  wMenuEntrySetCascade(menu, info_item, info);

  edit = wMenuCreate(scr, _("Edit"), False);
  tmp_item = wMenuAddCallback(edit, _("Cut"), nullCallback, NULL);
  tmp_item->rtext = wstrdup("x");
  tmp_item = wMenuAddCallback(edit, _("Copy"), nullCallback, NULL);
  tmp_item->rtext = wstrdup("c");
  tmp_item = wMenuAddCallback(edit, _("Paste"), nullCallback, NULL);
  tmp_item->rtext = wstrdup("v");
  tmp_item = wMenuAddCallback(edit, _("Select All"), nullCallback, NULL);
  tmp_item->rtext = wstrdup("a");
  edit_item = wMenuAddCallback(menu, _("Edit"), NULL, NULL);
  wMenuEntrySetCascade(menu, edit_item, edit);

  windows = wMenuCreate(scr, _("Windows"), False);
  wMenuAddCallback(windows, _("Arrange in Front"), nullCallback, NULL);
  tmp_item = wMenuAddCallback(windows, _("Miniaturize Window"), nullCallback, NULL);
  tmp_item->rtext = wstrdup("m");
  tmp_item = wMenuAddCallback(windows, _("Shade Window"), nullCallback, NULL);
  tmp_item = wMenuAddCallback(windows, _("Zoom window"), nullCallback, NULL);
  tmp_item = wMenuAddCallback(windows, _("Close Window"), nullCallback, NULL);
  tmp_item->rtext = wstrdup("w");
  windows_item = wMenuAddCallback(menu, _("Windows"), NULL, NULL);
  wMenuEntrySetCascade(menu, windows_item, windows);
  
  tmp_item = wMenuAddCallback(menu, _("Hide"), mainCallback, wapp);
  tmp_item->rtext = wstrdup("h");
  tmp_item = wMenuAddCallback(menu, _("Hide Others"), mainCallback, wapp);
  tmp_item->rtext = wstrdup("H");
  tmp_item = wMenuAddCallback(menu, _("Quit"), mainCallback, wapp);
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
