
#include "WINGsP.h"

typedef struct W_MenuItem {
	char *title;

	WMPixmap *image;

	char *shortcutKey;
	int shortcutModifierMask;

	WMAction *action;
	void *data;

	struct W_Menu *submenu;

	void *object;

	WMPixmap *onStateImage;
	WMPixmap *offStateImage;
	WMPixmap *mixedStateImage;

	struct {
		unsigned enabled:1;
		unsigned state:2;
	} flags;
} MenuItem;

WMMenuItem *WMGetSeparatorMenuItem(void)
{
	return NULL;
}

Bool WMMenuItemIsSeparator(WMMenuItem * item)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) item;

	return False;
}

WMMenuItem *WMCreateMenuItem(void)
{
	WMMenuItem *item;

	item = wmalloc(sizeof(MenuItem));

	item->flags.enabled = 1;

	return item;
}

void WMDestroyMenuItem(WMMenuItem * item)
{
	if (item->title)
		wfree(item->title);

	if (item->image)
		WMReleasePixmap(item->image);

	if (item->shortcutKey)
		wfree(item->shortcutKey);

	if (item->onStateImage)
		WMReleasePixmap(item->onStateImage);

	if (item->offStateImage)
		WMReleasePixmap(item->offStateImage);

	if (item->mixedStateImage)
		WMReleasePixmap(item->mixedStateImage);
}

Bool WMGetMenuItemEnabled(WMMenuItem * item)
{
	return item->flags.enabled;
}

void WMSetMenuItemEnabled(WMMenuItem * item, Bool flag)
{
	item->flags.enabled = ((flag == 0) ? 0 : 1);
}

char *WMGetMenuItemShortcut(WMMenuItem * item)
{
	return item->shortcutKey;
}

unsigned WMGetMenuItemShortcutModifierMask(WMMenuItem * item)
{
	return item->shortcutModifierMask;
}

void WMSetMenuItemShortcut(WMMenuItem * item, const char *shortcut)
{
	if (item->shortcutKey)
		wfree(item->shortcutKey);

	item->shortcutKey = wstrdup(shortcut);
}

void WMSetMenuItemShortcutModifierMask(WMMenuItem * item, unsigned mask)
{
	item->shortcutModifierMask = mask;
}

void *WMGetMenuItemRepresentedObject(WMMenuItem * item)
{
	return item->object;
}

void WMSetMenuItemRepresentedObject(WMMenuItem * item, void *object)
{
	item->object = object;
}

void WMSetMenuItemAction(WMMenuItem * item, WMAction * action, void *data)
{
	item->action = action;
	item->data = data;
}

WMAction *WMGetMenuItemAction(WMMenuItem * item)
{
	return item->action;
}

void *WMGetMenuItemData(WMMenuItem * item)
{
	return item->data;
}

void WMSetMenuItemTitle(WMMenuItem * item, const char *title)
{
	if (item->title)
		wfree(item->title);

	if (title)
		item->title = wstrdup(title);
	else
		item->title = NULL;
}

char *WMGetMenuItemTitle(WMMenuItem * item)
{
	return item->title;
}

void WMSetMenuItemState(WMMenuItem * item, int state)
{
	item->flags.state = state;
}

int WMGetMenuItemState(WMMenuItem * item)
{
	return item->flags.state;
}

void WMSetMenuItemPixmap(WMMenuItem * item, WMPixmap * pixmap)
{
	if (item->image)
		WMReleasePixmap(item->image);

	item->image = WMRetainPixmap(pixmap);
}

WMPixmap *WMGetMenuItemPixmap(WMMenuItem * item)
{
	return item->image;
}

void WMSetMenuItemOnStatePixmap(WMMenuItem * item, WMPixmap * pixmap)
{
	if (item->onStateImage)
		WMReleasePixmap(item->onStateImage);

	item->onStateImage = WMRetainPixmap(pixmap);
}

WMPixmap *WMGetMenuItemOnStatePixmap(WMMenuItem * item)
{
	return item->onStateImage;
}

void WMSetMenuItemOffStatePixmap(WMMenuItem * item, WMPixmap * pixmap)
{
	if (item->offStateImage)
		WMReleasePixmap(item->offStateImage);

	item->offStateImage = WMRetainPixmap(pixmap);
}

WMPixmap *WMGetMenuItemOffStatePixmap(WMMenuItem * item)
{
	return item->offStateImage;
}

void WMSetMenuItemMixedStatePixmap(WMMenuItem * item, WMPixmap * pixmap)
{
	if (item->mixedStateImage)
		WMReleasePixmap(item->mixedStateImage);

	item->mixedStateImage = WMRetainPixmap(pixmap);
}

WMPixmap *WMGetMenuItemMixedStatePixmap(WMMenuItem * item)
{
	return item->mixedStateImage;
}

#if 0
void WMSetMenuItemSubmenu(WMMenuItem * item, WMMenu * submenu)
{
	item->submenu = submenu;
}

WMMenu *WMGetMenuItemSubmenu(WMMenuItem * item)
{
	return item->submenu;
}

Bool WMGetMenuItemHasSubmenu(WMMenuItem * item)
{
	return item->submenu != NULL;
}
#endif
