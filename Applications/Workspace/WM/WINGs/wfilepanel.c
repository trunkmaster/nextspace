
#include <sys/types.h>
#include <sys/stat.h>

#include <unistd.h>
#include <dirent.h>
#include <limits.h>
#include <errno.h>
#include <stdint.h>

#include "WINGsP.h"
#include "wconfig.h"

#ifndef PATH_MAX
#define PATH_MAX 1024
#endif

typedef struct W_FilePanel {
	WMWindow *win;

	WMLabel *iconLabel;
	WMLabel *titleLabel;

	WMFrame *line;

	WMLabel *nameLabel;
	WMBrowser *browser;

	WMButton *okButton;
	WMButton *cancelButton;

	WMButton *homeButton;
	WMButton *trashcanButton;
	WMButton *createDirButton;
	WMButton *disketteButton;
	WMButton *unmountButton;

	WMView *accessoryView;

	WMTextField *fileField;

	char **fileTypes;

	struct {
		unsigned int canExit:1;
		unsigned int canceled:1;	/* clicked on cancel */
		unsigned int filtered:1;
		unsigned int canChooseFiles:1;
		unsigned int canChooseDirectories:1;
		unsigned int autoCompletion:1;
		unsigned int showAllFiles:1;
		unsigned int canFreeFileTypes:1;
		unsigned int fileMustExist:1;
		unsigned int panelType:1;
	} flags;
} W_FilePanel;

/* Type of panel */
#define WP_OPEN         0
#define WP_SAVE         1

#define PWIDTH		330
#define PHEIGHT 	360

static void listDirectoryOnColumn(WMFilePanel * panel, int column, const char *path);
static void browserClick(WMWidget *widget, void *p_panel);
static void browserDClick(WMWidget *widget, void *p_panel);

static void fillColumn(WMBrowserDelegate * self, WMBrowser * bPtr, int column, WMList * list);

static void normalizePath(char *s);

static void deleteFile(WMWidget *widget, void *p_panel);
static void createDir(WMWidget *widget, void *p_panel);
static void goHome(WMWidget *widget, void *p_panel);
static void goFloppy(WMWidget *widget, void *p_panel);
static void goUnmount(WMWidget *widget, void *p_panel);
static void buttonClick(WMWidget *widget, void *p_panel);

static char *getCurrentFileName(WMFilePanel * panel);

static void handleEvents(XEvent * event, void *data);

static WMBrowserDelegate browserDelegate = {
	NULL,			/* data */
	fillColumn,		/* createRowsForColumn */
	NULL,			/* titleOfColumn */
	NULL,			/* didScroll */
	NULL			/* willScroll */
};

static int closestListItem(WMList * list, const char *text, Bool exact)
{
	WMListItem *item;
	WMArray *items = WMGetListItems(list);
	int i, nb_item, len = strlen(text);

	if (len == 0)
		return -1;

	nb_item = WMGetArrayItemCount(items);
	for (i = 0; i < nb_item; i++) {
		item = WMGetFromArray(items, i);
		if ((exact && strcmp(item->text, text) == 0) ||
			 (!exact && strncmp(item->text, text, len) == 0)) {
			return i;
		}
	}

	return -1;
}

static void textChangedObserver(void *observerData, WMNotification * notification)
{
	W_FilePanel *panel = (W_FilePanel *) observerData;
	char *text;
	WMList *list;
	int col = WMGetBrowserNumberOfColumns(panel->browser) - 1;
	int i;
	uintptr_t textEvent;

	if (!(list = WMGetBrowserListInColumn(panel->browser, col)))
		return;

	text = WMGetTextFieldText(panel->fileField);
	textEvent = (uintptr_t)WMGetNotificationClientData(notification);

	if (panel->flags.autoCompletion && textEvent != WMDeleteTextEvent)
		i = closestListItem(list, text, False);
	else
		i = closestListItem(list, text, True);

	WMSelectListItem(list, i);
	if (i >= 0 && panel->flags.autoCompletion) {
		WMListItem *item = WMGetListItem(list, i);
		int textLen = strlen(text), itemTextLen = strlen(item->text);
		int visibleItems = WMWidgetHeight(list) / WMGetListItemHeight(list);

		WMSetListPosition(list, i - visibleItems / 2);

		if (textEvent != WMDeleteTextEvent) {
			WMRange range;

			WMInsertTextFieldText(panel->fileField, &item->text[textLen], textLen);
			range.position = textLen;
			range.count = itemTextLen - textLen;
			WMSelectTextFieldRange(panel->fileField, range);
			/*WMSetTextFieldCursorPosition(panel->fileField, itemTextLen); */
		}
	}

	wfree(text);
}

static void textEditedObserver(void *observerData, WMNotification * notification)
{
	W_FilePanel *panel = (W_FilePanel *) observerData;

	if ((uintptr_t)WMGetNotificationClientData(notification) == WMReturnTextMovement) {
		WMPerformButtonClick(panel->okButton);
	}
}

static WMFilePanel *makeFilePanel(WMScreen * scrPtr, const char *name, const char *title)
{
	WMFilePanel *fPtr;
	WMFont *largeFont;
	WMPixmap *icon;

	fPtr = wmalloc(sizeof(WMFilePanel));

	fPtr->win = WMCreateWindowWithStyle(scrPtr, name, WMTitledWindowMask | WMResizableWindowMask);
	WMResizeWidget(fPtr->win, PWIDTH, PHEIGHT);
	WMSetWindowTitle(fPtr->win, "");

	WMCreateEventHandler(WMWidgetView(fPtr->win), StructureNotifyMask, handleEvents, fPtr);
	WMSetWindowMinSize(fPtr->win, PWIDTH, PHEIGHT);

	fPtr->iconLabel = WMCreateLabel(fPtr->win);
	WMResizeWidget(fPtr->iconLabel, 64, 64);
	WMMoveWidget(fPtr->iconLabel, 0, 0);
	WMSetLabelImagePosition(fPtr->iconLabel, WIPImageOnly);
	icon = WMCreateApplicationIconBlendedPixmap(scrPtr, (RColor *) NULL);
	if (icon) {
		WMSetLabelImage(fPtr->iconLabel, icon);
		WMReleasePixmap(icon);
	} else {
		WMSetLabelImage(fPtr->iconLabel, scrPtr->applicationIconPixmap);
	}

	fPtr->titleLabel = WMCreateLabel(fPtr->win);
	WMResizeWidget(fPtr->titleLabel, PWIDTH - 64, 64);
	WMMoveWidget(fPtr->titleLabel, 64, 0);
	largeFont = WMBoldSystemFontOfSize(scrPtr, 24);
	WMSetLabelFont(fPtr->titleLabel, largeFont);
	WMReleaseFont(largeFont);
	WMSetLabelText(fPtr->titleLabel, title);

	fPtr->line = WMCreateFrame(fPtr->win);
	WMMoveWidget(fPtr->line, 0, 64);
	WMResizeWidget(fPtr->line, PWIDTH, 2);
	WMSetFrameRelief(fPtr->line, WRGroove);

	fPtr->browser = WMCreateBrowser(fPtr->win);
	WMSetBrowserAllowEmptySelection(fPtr->browser, True);
	WMSetBrowserDelegate(fPtr->browser, &browserDelegate);
	WMSetBrowserAction(fPtr->browser, browserClick, fPtr);
	WMSetBrowserDoubleAction(fPtr->browser, browserDClick, fPtr);
	WMMoveWidget(fPtr->browser, 7, 72);
	WMResizeWidget(fPtr->browser, PWIDTH - 14, 200);
	WMHangData(fPtr->browser, fPtr);

	fPtr->nameLabel = WMCreateLabel(fPtr->win);
	WMMoveWidget(fPtr->nameLabel, 7, 282);
	WMResizeWidget(fPtr->nameLabel, 55, 14);
	WMSetLabelText(fPtr->nameLabel, _("Name:"));

	fPtr->fileField = WMCreateTextField(fPtr->win);
	WMMoveWidget(fPtr->fileField, 60, 278);
	WMResizeWidget(fPtr->fileField, PWIDTH - 60 - 10, 24);
	WMAddNotificationObserver(textEditedObserver, fPtr, WMTextDidEndEditingNotification, fPtr->fileField);
	WMAddNotificationObserver(textChangedObserver, fPtr, WMTextDidChangeNotification, fPtr->fileField);

	fPtr->okButton = WMCreateCommandButton(fPtr->win);
	WMMoveWidget(fPtr->okButton, 245, 325);
	WMResizeWidget(fPtr->okButton, 75, 28);
	WMSetButtonText(fPtr->okButton, _("OK"));
	WMSetButtonImage(fPtr->okButton, scrPtr->buttonArrow);
	WMSetButtonAltImage(fPtr->okButton, scrPtr->pushedButtonArrow);
	WMSetButtonImagePosition(fPtr->okButton, WIPRight);
	WMSetButtonAction(fPtr->okButton, buttonClick, fPtr);

	fPtr->cancelButton = WMCreateCommandButton(fPtr->win);
	WMMoveWidget(fPtr->cancelButton, 165, 325);
	WMResizeWidget(fPtr->cancelButton, 75, 28);
	WMSetButtonText(fPtr->cancelButton, _("Cancel"));
	WMSetButtonAction(fPtr->cancelButton, buttonClick, fPtr);

	fPtr->trashcanButton = WMCreateCommandButton(fPtr->win);
	WMMoveWidget(fPtr->trashcanButton, 7, 325);
	WMResizeWidget(fPtr->trashcanButton, 28, 28);
	WMSetButtonImagePosition(fPtr->trashcanButton, WIPImageOnly);
	WMSetButtonImage(fPtr->trashcanButton, scrPtr->trashcanIcon);
	WMSetButtonAltImage(fPtr->trashcanButton, scrPtr->altTrashcanIcon);
	WMSetButtonAction(fPtr->trashcanButton, deleteFile, fPtr);

	fPtr->createDirButton = WMCreateCommandButton(fPtr->win);
	WMMoveWidget(fPtr->createDirButton, 37, 325);
	WMResizeWidget(fPtr->createDirButton, 28, 28);
	WMSetButtonImagePosition(fPtr->createDirButton, WIPImageOnly);
	WMSetButtonImage(fPtr->createDirButton, scrPtr->createDirIcon);
	WMSetButtonAltImage(fPtr->createDirButton, scrPtr->altCreateDirIcon);
	WMSetButtonAction(fPtr->createDirButton, createDir, fPtr);

	fPtr->homeButton = WMCreateCommandButton(fPtr->win);
	WMMoveWidget(fPtr->homeButton, 67, 325);
	WMResizeWidget(fPtr->homeButton, 28, 28);
	WMSetButtonImagePosition(fPtr->homeButton, WIPImageOnly);
	WMSetButtonImage(fPtr->homeButton, scrPtr->homeIcon);
	WMSetButtonAltImage(fPtr->homeButton, scrPtr->altHomeIcon);
	WMSetButtonAction(fPtr->homeButton, goHome, fPtr);

	fPtr->disketteButton = WMCreateCommandButton(fPtr->win);
	WMMoveWidget(fPtr->disketteButton, 97, 325);
	WMResizeWidget(fPtr->disketteButton, 28, 28);
	WMSetButtonImagePosition(fPtr->disketteButton, WIPImageOnly);
	WMSetButtonImage(fPtr->disketteButton, scrPtr->disketteIcon);
	WMSetButtonAltImage(fPtr->disketteButton, scrPtr->altDisketteIcon);
	WMSetButtonAction(fPtr->disketteButton, goFloppy, fPtr);

	fPtr->unmountButton = WMCreateCommandButton(fPtr->win);
	WMMoveWidget(fPtr->unmountButton, 127, 325);
	WMResizeWidget(fPtr->unmountButton, 28, 28);
	WMSetButtonImagePosition(fPtr->unmountButton, WIPImageOnly);
	WMSetButtonImage(fPtr->unmountButton, scrPtr->unmountIcon);
	WMSetButtonAltImage(fPtr->unmountButton, scrPtr->altUnmountIcon);
	WMSetButtonAction(fPtr->unmountButton, goUnmount, fPtr);
	WMSetButtonEnabled(fPtr->unmountButton, False);

	WMRealizeWidget(fPtr->win);
	WMMapSubwidgets(fPtr->win);

	WMSetFocusToWidget(fPtr->fileField);
	WMSetTextFieldCursorPosition(fPtr->fileField, 0);

	WMLoadBrowserColumnZero(fPtr->browser);

	WMSetWindowInitialPosition(fPtr->win,
				   (scrPtr->rootView->size.width - WMWidgetWidth(fPtr->win)) / 2,
				   (scrPtr->rootView->size.height - WMWidgetHeight(fPtr->win)) / 2);

	fPtr->flags.canChooseFiles = 1;
	fPtr->flags.canChooseDirectories = 1;
	fPtr->flags.autoCompletion = 1;

	return fPtr;
}

WMOpenPanel *WMGetOpenPanel(WMScreen * scrPtr)
{
	WMFilePanel *panel;

	if (scrPtr->sharedOpenPanel)
		return scrPtr->sharedOpenPanel;

	panel = makeFilePanel(scrPtr, "openFilePanel", _("Open"));
	panel->flags.fileMustExist = 1;
	panel->flags.panelType = WP_OPEN;

	scrPtr->sharedOpenPanel = panel;

	return panel;
}

WMSavePanel *WMGetSavePanel(WMScreen * scrPtr)
{
	WMFilePanel *panel;

	if (scrPtr->sharedSavePanel)
		return scrPtr->sharedSavePanel;

	panel = makeFilePanel(scrPtr, "saveFilePanel", _("Save"));
	panel->flags.fileMustExist = 0;
	panel->flags.panelType = WP_SAVE;

	scrPtr->sharedSavePanel = panel;

	return panel;
}

void WMFreeFilePanel(WMFilePanel * panel)
{
	if (panel == WMWidgetScreen(panel->win)->sharedSavePanel) {
		WMWidgetScreen(panel->win)->sharedSavePanel = NULL;
	}
	if (panel == WMWidgetScreen(panel->win)->sharedOpenPanel) {
		WMWidgetScreen(panel->win)->sharedOpenPanel = NULL;
	}
	WMRemoveNotificationObserver(panel);
	WMUnmapWidget(panel->win);
	WMDestroyWidget(panel->win);
	wfree(panel);
}

int
WMRunModalFilePanelForDirectory(WMFilePanel * panel, WMWindow * owner, char *path, const char *name, char **fileTypes)
{
	WMScreen *scr = WMWidgetScreen(panel->win);

	if (name && !owner) {
		WMSetWindowTitle(panel->win, name);
	}

	WMChangePanelOwner(panel->win, owner);

	WMSetFilePanelDirectory(panel, path);

	switch (panel->flags.panelType) {
	case WP_OPEN:
		if (fileTypes)
			panel->flags.filtered = 1;
		panel->fileTypes = fileTypes;
		if (name == NULL)
			name = _("Open");
		break;
	case WP_SAVE:
		panel->fileTypes = NULL;
		panel->flags.filtered = 0;
		if (name == NULL)
			name = _("Save");
		break;
	default:
		break;
	}

	WMSetLabelText(panel->titleLabel, name);

	WMMapWidget(panel->win);

	WMRunModalLoop(scr, W_VIEW(panel->win));

	/* Must withdraw window because the next time we map
	 * it, it might have a different transient owner.
	 */
	WMCloseWindow(panel->win);

	return (panel->flags.canceled ? False : True);
}

void WMSetFilePanelDirectory(WMFilePanel * panel, char *path)
{
	WMList *list;
	WMListItem *item;
	int col;
	char *rest;

	rest = WMSetBrowserPath(panel->browser, path);
	if (strcmp(path, "/") == 0)
		rest = NULL;

	col = WMGetBrowserSelectedColumn(panel->browser);
	list = WMGetBrowserListInColumn(panel->browser, col);
	if (list && (item = WMGetListSelectedItem(list))) {
		if (item->isBranch) {
			WMSetTextFieldText(panel->fileField, rest);
		} else {
			WMSetTextFieldText(panel->fileField, item->text);
		}
	} else {
		WMSetTextFieldText(panel->fileField, rest);
	}
}

void WMSetFilePanelCanChooseDirectories(WMFilePanel * panel, Bool flag)
{
	panel->flags.canChooseDirectories = ((flag == 0) ? 0 : 1);
}

void WMSetFilePanelCanChooseFiles(WMFilePanel * panel, Bool flag)
{
	panel->flags.canChooseFiles = ((flag == 0) ? 0 : 1);
}

void WMSetFilePanelAutoCompletion(WMFilePanel * panel, Bool flag)
{
	panel->flags.autoCompletion = ((flag == 0) ? 0 : 1);
}

char *WMGetFilePanelFileName(WMFilePanel * panel)
{
	return getCurrentFileName(panel);
}

void WMSetFilePanelAccessoryView(WMFilePanel * panel, WMView * view)
{
	WMView *v;

	panel->accessoryView = view;

	v = WMWidgetView(panel->win);

	W_ReparentView(view, v, 0, 0);

	W_MoveView(view, (v->size.width - v->size.width) / 2, 300);
}

WMView *WMGetFilePanelAccessoryView(WMFilePanel * panel)
{
	return panel->accessoryView;
}

static char *get_name_from_path(const char *path)
{
	int size;

	assert(path != NULL);

	size = strlen(path);

	/* remove trailing / */
	while (size > 0 && path[size - 1] == '/')
		size--;
	/* directory was root */
	if (size == 0)
		return wstrdup("/");

	while (size > 0 && path[size - 1] != '/')
		size--;

	return wstrdup(&(path[size]));
}

#define CAST(item) (*((WMListItem**)item))
static int comparer(const void *a, const void *b)
{
	if (CAST(a)->isBranch == CAST(b)->isBranch)
		return (strcmp(CAST(a)->text, CAST(b)->text));
	if (CAST(a)->isBranch)
		return (-1);
	return (1);
}

#undef CAST

static void listDirectoryOnColumn(WMFilePanel * panel, int column, const char *path)
{
	WMBrowser *bPtr = panel->browser;
	struct dirent *dentry;
	DIR *dir;
	struct stat stat_buf;
	char pbuf[PATH_MAX + 16];
	char *name;

	assert(column >= 0);
	assert(path != NULL);

	/* put directory name in the title */
	name = get_name_from_path(path);
	WMSetBrowserColumnTitle(bPtr, column, name);
	wfree(name);

	dir = opendir(path);

	if (!dir) {
#ifdef VERBOSE
		printf(_("WINGs: could not open directory %s\n"), path);
#endif
		return;
	}

	/* list contents in the column */
	while ((dentry = readdir(dir))) {
		if (strcmp(dentry->d_name, ".") == 0 || strcmp(dentry->d_name, "..") == 0)
			continue;

		if (wstrlcpy(pbuf, path, sizeof(pbuf)) >= sizeof(pbuf))
			goto out;
		if (strcmp(path, "/") != 0 &&
		    wstrlcat(pbuf, "/", sizeof(pbuf)) >= sizeof(pbuf))
			goto out;
		if (wstrlcat(pbuf, dentry->d_name, sizeof(pbuf)) >= sizeof(pbuf))
			goto out;

		if (stat(pbuf, &stat_buf) != 0) {
#ifdef VERBOSE
			printf(_("WINGs: could not stat %s\n"), pbuf);
#endif
			continue;
		} else {
			int isDirectory;

			isDirectory = S_ISDIR(stat_buf.st_mode);
			WMInsertBrowserItem(bPtr, column, -1, dentry->d_name, isDirectory);
		}
	}
	WMSortBrowserColumnWithComparer(bPtr, column, comparer);

out:
	closedir(dir);
}

static void fillColumn(WMBrowserDelegate * self, WMBrowser * bPtr, int column, WMList * list)
{
	char *path;
	WMFilePanel *panel;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;
	(void) list;

	if (column > 0) {
		path = WMGetBrowserPathToColumn(bPtr, column - 1);
	} else {
		path = wstrdup("/");
	}

	panel = WMGetHangedData(bPtr);
	listDirectoryOnColumn(panel, column, path);
	wfree(path);
}

static void browserDClick(WMWidget *widget, void *p_panel)
{
	WMFilePanel *panel = p_panel;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) widget;

	WMPerformButtonClick(panel->okButton);
}

static void browserClick(WMWidget *widget, void *p_panel)
{
	WMBrowser *bPtr = (WMBrowser *) widget;
	WMFilePanel *panel = p_panel;
	int col = WMGetBrowserSelectedColumn(bPtr);
	WMListItem *item = WMGetBrowserSelectedItemInColumn(bPtr, col);

	if (!item || item->isBranch)
		WMSetTextFieldText(panel->fileField, NULL);
	else {
		WMSetTextFieldText(panel->fileField, item->text);
	}
}

static void showError(WMScreen * scr, WMWindow * owner, const char *s, const char *file)
{
	char *errStr;

	if (file) {
		errStr = wmalloc(strlen(file) + strlen(s) + 1);
		sprintf(errStr, s, file);
	} else {
		errStr = wstrdup(s);
	}
	WMRunAlertPanel(scr, owner, _("Error"), errStr, _("OK"), NULL, NULL);
	wfree(errStr);
}

static void createDir(WMWidget *widget, void *p_panel)
{
	WMFilePanel *panel = p_panel;
	char *dirName, *directory, *file;
	size_t slen;
	WMScreen *scr = WMWidgetScreen(panel->win);

	/* Parameter not used, but tell the compiler that it is ok */
	(void) widget;

	dirName = WMRunInputPanel(scr, panel->win, _("Create Directory"),
				  _("Enter directory name"), "", _("OK"), _("Cancel"));
	if (!dirName)
		return;

	/* if `dirName' is an absolute path, don't mind `directory'.
	 * normalize as needed (possibly not needed at all?) */
	normalizePath(dirName);
	if (*dirName != '/') {
		directory = getCurrentFileName(panel);
		normalizePath(directory);
	} else {
		directory = NULL;
	}

	slen = strlen(dirName) + (directory ? strlen(directory) + 1 /* "/" */  : 0) + 1 /* NULL */;
	file = wmalloc(slen);

	if (directory &&
		(wstrlcat(file, directory, slen) >= slen ||
		 wstrlcat(file, "/", slen) >= slen))
			goto out;

	if (wstrlcat(file, dirName, slen) >= slen)
		goto out;

	if (mkdir(file, 00777) != 0) {
#define __msgbufsize__ 512
		char *buffer = wmalloc(__msgbufsize__);
		snprintf(buffer, __msgbufsize__, _("Can not create %s: %s"), file, strerror(errno));
		showError(scr, panel->win, buffer, NULL);
		wfree(buffer);
#undef __msgbufsize__
	} else {
		WMSetFilePanelDirectory(panel, file);
	}

out:
	if (dirName)
		wfree(dirName);
	if (directory)
		wfree(directory);
	if (file)
		wfree(file);
}

/*
 *----------------------------------------------------------------------
 * normalizePath--
 *	Remove multiple consecutive and any trailing slashes from
 *	a path.
 *----------------------------------------------------------------------
 */
static void normalizePath(char *s)
{
	int i, j, found;

	found = 0;
	for (i = 0; s[i]; (void)(!found && i++)) {
		found = 0;
		if (s[i] == '/' && s[i+1] == '/') {
			int nslash = 1;
			found = 1;
			i++;
			while (s[i+nslash] == '/')
				nslash++;
			for (j = 0; s[i+j+nslash]; j++)
				s[i+j] = s[i+j+nslash];
			s[i+j] = '\0';
		}
	}
	if (i > 1 && s[--i] == '/')
		s[i] = '\0';
}


static void deleteFile(WMWidget *widget, void *p_panel)
{
	WMFilePanel *panel = p_panel;
	char *file;
	char buffer[512];
	struct stat filestat;
	WMScreen *scr = WMWidgetScreen(panel->win);

	/* Parameter not used, but tell the compiler that it is ok */
	(void) widget;

	file = getCurrentFileName(panel);
	if (file == NULL)
		return;

	normalizePath(file);

	if (stat(file, &filestat) == -1) {
		snprintf(buffer, sizeof(buffer),
		         _("Can not find %s: %s"),
		         file, strerror(errno));
		showError(scr, panel->win, buffer, NULL);
		goto out;
	}

	snprintf(buffer, sizeof(buffer), _("Delete %s %s?"),
		S_ISDIR(filestat.st_mode) ? _("directory") : _("file"), file);

	if (!WMRunAlertPanel(WMWidgetScreen(panel->win), panel->win,
			     _("Warning"), buffer, _("OK"), _("Cancel"), NULL)) {

		if (remove(file) == -1) {
			snprintf(buffer, sizeof(buffer),
			         _("Removing %s failed: %s"),
			         file, strerror(errno));
			showError(scr, panel->win, buffer, NULL);
		} else {
			char *s = strrchr(file, '/');
			if (s)
				s[0] = 0;
			WMSetFilePanelDirectory(panel, file);
		}

	}
out:
	wfree(file);
}

static void goUnmount(WMWidget *widget, void *p_panel)
{
	/* Not implemented yet */
	(void) widget;
	(void) p_panel;
}

static void goFloppy(WMWidget *widget, void *p_panel)
{
	WMFilePanel *panel = p_panel;
	struct stat filestat;
	WMScreen *scr = WMWidgetScreen(panel->win);

	/* Parameter not used, but tell the compiler that it is ok */
	(void) widget;

	if (stat(WINGsConfiguration.floppyPath, &filestat)) {
		showError(scr, panel->win, _("An error occurred browsing '%s'."), WINGsConfiguration.floppyPath);
		return;
	} else if (!S_ISDIR(filestat.st_mode)) {
		showError(scr, panel->win, _("'%s' is not a directory."), WINGsConfiguration.floppyPath);
		return;
	}

	WMSetFilePanelDirectory(panel, WINGsConfiguration.floppyPath);
}

static void goHome(WMWidget *widget, void *p_panel)
{
	WMFilePanel *panel = p_panel;
	char *home;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) widget;

	/* home is statically allocated. Don't free it! */
	home = wgethomedir();
	if (!home)
		return;

	WMSetFilePanelDirectory(panel, home);
}

static void handleEvents(XEvent * event, void *data)
{
	W_FilePanel *pPtr = (W_FilePanel *) data;
	W_View *view = WMWidgetView(pPtr->win);

	if (event->type == ConfigureNotify) {
		if (event->xconfigure.width != view->size.width || event->xconfigure.height != view->size.height) {
			unsigned int newWidth = event->xconfigure.width;
			unsigned int newHeight = event->xconfigure.height;
			int newColumnCount;

			W_ResizeView(view, newWidth, newHeight);
			WMResizeWidget(pPtr->line, newWidth, 2);
			WMResizeWidget(pPtr->browser, newWidth - 14, newHeight - (PHEIGHT - 200));
			WMResizeWidget(pPtr->fileField, newWidth - 60 - 10, 24);
			WMMoveWidget(pPtr->nameLabel, 7, newHeight - (PHEIGHT - 282));
			WMMoveWidget(pPtr->fileField, 60, newHeight - (PHEIGHT - 278));
			WMMoveWidget(pPtr->okButton, newWidth - (PWIDTH - 245), newHeight - (PHEIGHT - 325));
			WMMoveWidget(pPtr->cancelButton, newWidth - (PWIDTH - 165), newHeight - (PHEIGHT - 325));

			WMMoveWidget(pPtr->trashcanButton, 7, newHeight - (PHEIGHT - 325));
			WMMoveWidget(pPtr->createDirButton, 37, newHeight - (PHEIGHT - 325));
			WMMoveWidget(pPtr->homeButton, 67, newHeight - (PHEIGHT - 325));
			WMMoveWidget(pPtr->disketteButton, 97, newHeight - (PHEIGHT - 325));
			WMMoveWidget(pPtr->unmountButton, 127, newHeight - (PHEIGHT - 325));

			newColumnCount = (newWidth - 14) / 140;
			WMSetBrowserMaxVisibleColumns(pPtr->browser, newColumnCount);
		}
	}
}

static char *getCurrentFileName(WMFilePanel * panel)
{
	char *path;
	char *file;
	char *ret;
	size_t slen;

	path = WMGetBrowserPath(panel->browser);

	if (!path)
		return NULL;

	if (path[strlen(path) -1] != '/')
		return path;

	file = WMGetTextFieldText(panel->fileField);
	slen = strlen(path) + strlen(file) + 1;
	ret = wmalloc(slen);

	if (file[0] != '/')
		strcpy(ret, path);

	strcat(ret, file);

	wfree(file);
	wfree(path);
	return ret;
}


static Bool validOpenFile(WMFilePanel * panel)
{
	WMListItem *item;
	int col, haveFile = 0;
	char *file = WMGetTextFieldText(panel->fileField);

	if (file[0] != '\0')
		haveFile = 1;
	wfree(file);

	col = WMGetBrowserSelectedColumn(panel->browser);
	item = WMGetBrowserSelectedItemInColumn(panel->browser, col);
	if (item) {
		if (item->isBranch && !panel->flags.canChooseDirectories && !haveFile)
			return False;
		else if (!item->isBranch && !panel->flags.canChooseFiles)
			return False;
		else
			return True;
	} else {
		/* we compute for / here */
		if (!panel->flags.canChooseDirectories && !haveFile)
			return False;
		else
			return True;
	}
	return True;
}

static void buttonClick(WMWidget *widget, void *p_panel)
{
	WMButton *bPtr = (WMButton *) widget;
	WMFilePanel *panel = p_panel;
	WMRange range;

	if (bPtr == panel->okButton) {
		if (!validOpenFile(panel))
			return;
		if (panel->flags.fileMustExist) {
			char *file;

			file = getCurrentFileName(panel);
			if (access(file, F_OK) != 0) {
				WMRunAlertPanel(WMWidgetScreen(panel->win), panel->win,
						_("Error"), _("File does not exist."), _("OK"), NULL, NULL);
				wfree(file);
				return;
			}
			wfree(file);
		}
		panel->flags.canceled = 0;
	} else
		panel->flags.canceled = 1;

	range.count = range.position = 0;
	WMSelectTextFieldRange(panel->fileField, range);
	WMBreakModalLoop(WMWidgetScreen(bPtr));
}
