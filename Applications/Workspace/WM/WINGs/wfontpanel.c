
#include "WINGsP.h"
#include "WUtil.h"
#include "wconfig.h"

#include <ctype.h>
#include <string.h>
#include <strings.h>
#include <stdint.h>

#include <X11/Xft/Xft.h>
#include <fontconfig/fontconfig.h>

/* XXX TODO */
char *WMFontPanelFontChangedNotification = "WMFontPanelFontChangedNotification";

typedef struct W_FontPanel {
	WMWindow *win;

	WMFrame *upperF;
	WMTextField *sampleT;

	WMSplitView *split;

	WMFrame *lowerF;
	WMLabel *famL;
	WMList *famLs;
	WMLabel *typL;
	WMList *typLs;
	WMLabel *sizL;
	WMTextField *sizT;
	WMList *sizLs;

	WMAction2 *action;
	void *data;

	WMButton *revertB;
	WMButton *setB;

	WMPropList *fdb;
} FontPanel;

#define MIN_UPPER_HEIGHT	20
#define MIN_LOWER_HEIGHT	140

#define BUTTON_SPACE_HEIGHT 40

#define MIN_WIDTH	250
#define MIN_HEIGHT 	(MIN_UPPER_HEIGHT+MIN_LOWER_HEIGHT+BUTTON_SPACE_HEIGHT)

#define DEF_UPPER_HEIGHT 60
#define DEF_LOWER_HEIGHT 310

#define DEF_WIDTH	320
#define DEF_HEIGHT	(DEF_UPPER_HEIGHT+DEF_LOWER_HEIGHT)

static const int scalableFontSizes[] = {
	8,
	10,
	11,
	12,
	14,
	16,
	18,
	20,
	24,
	36,
	48,
	64
};

static void setFontPanelFontName(FontPanel * panel, const char *family, const char *style, double size);

static int isXLFD(const char *font, int *length_ret);

static void arrangeLowerFrame(FontPanel * panel);

static void familyClick(WMWidget *, void *);
static void typefaceClick(WMWidget *, void *);
static void sizeClick(WMWidget *, void *);

static void listFamilies(WMScreen * scr, WMFontPanel * panel);

static void splitViewConstrainCallback(WMSplitView * sPtr, int indView, int *min, int *max)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) sPtr;
	(void) max;

	if (indView == 0)
		*min = MIN_UPPER_HEIGHT;
	else
		*min = MIN_LOWER_HEIGHT;
}

static void notificationObserver(void *self, WMNotification * notif)
{
	WMFontPanel *panel = (WMFontPanel *) self;
	void *object = WMGetNotificationObject(notif);

	if (WMGetNotificationName(notif) == WMViewSizeDidChangeNotification) {
		if (object == WMWidgetView(panel->win)) {
			int h = WMWidgetHeight(panel->win);
			int w = WMWidgetWidth(panel->win);

			WMResizeWidget(panel->split, w, h - BUTTON_SPACE_HEIGHT);

			WMMoveWidget(panel->setB, w - 80, h - (BUTTON_SPACE_HEIGHT - 5));

			WMMoveWidget(panel->revertB, w - 240, h - (BUTTON_SPACE_HEIGHT - 5));

		} else if (object == WMWidgetView(panel->upperF)) {

			if (WMWidgetHeight(panel->upperF) < MIN_UPPER_HEIGHT) {
				WMResizeWidget(panel->upperF, WMWidgetWidth(panel->upperF), MIN_UPPER_HEIGHT);
			} else {
				WMResizeWidget(panel->sampleT, WMWidgetWidth(panel->upperF) - 20,
					       WMWidgetHeight(panel->upperF) - 10);
			}

		} else if (object == WMWidgetView(panel->lowerF)) {

			if (WMWidgetHeight(panel->lowerF) < MIN_LOWER_HEIGHT) {
				WMResizeWidget(panel->upperF, WMWidgetWidth(panel->upperF), MIN_UPPER_HEIGHT);

				WMMoveWidget(panel->lowerF, 0, WMWidgetHeight(panel->upperF)
					     + WMGetSplitViewDividerThickness(panel->split));

				WMResizeWidget(panel->lowerF, WMWidgetWidth(panel->lowerF),
					       WMWidgetWidth(panel->split) - MIN_UPPER_HEIGHT
					       - WMGetSplitViewDividerThickness(panel->split));
			} else {
				arrangeLowerFrame(panel);
			}
		}
	}
}

static void closeWindow(WMWidget * w, void *data)
{
	FontPanel *panel = (FontPanel *) data;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	WMHideFontPanel(panel);
}

static void setClickedAction(WMWidget * w, void *data)
{
	FontPanel *panel = (FontPanel *) data;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	if (panel->action)
		(*panel->action) (panel, panel->data);
}

static void revertClickedAction(WMWidget * w, void *data)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;
	(void) data;

	/*FontPanel *panel = (FontPanel*)data; */
	/* XXX TODO */
}

WMFontPanel *WMGetFontPanel(WMScreen * scr)
{
	FontPanel *panel;
	WMColor *dark, *white;
	WMFont *font;
	int divThickness;

	if (scr->sharedFontPanel)
		return scr->sharedFontPanel;

	panel = wmalloc(sizeof(FontPanel));

	panel->win = WMCreateWindow(scr, "fontPanel");
	/*    WMSetWidgetBackgroundColor(panel->win, WMWhiteColor(scr)); */
	WMSetWindowTitle(panel->win, _("Font Panel"));
	WMResizeWidget(panel->win, DEF_WIDTH, DEF_HEIGHT);
	WMSetWindowMinSize(panel->win, MIN_WIDTH, MIN_HEIGHT);
	WMSetViewNotifySizeChanges(WMWidgetView(panel->win), True);

	WMSetWindowCloseAction(panel->win, closeWindow, panel);

	panel->split = WMCreateSplitView(panel->win);
	WMResizeWidget(panel->split, DEF_WIDTH, DEF_HEIGHT - BUTTON_SPACE_HEIGHT);
	WMSetSplitViewConstrainProc(panel->split, splitViewConstrainCallback);

	divThickness = WMGetSplitViewDividerThickness(panel->split);

	panel->upperF = WMCreateFrame(panel->win);
	WMSetFrameRelief(panel->upperF, WRFlat);
	WMSetViewNotifySizeChanges(WMWidgetView(panel->upperF), True);
	panel->lowerF = WMCreateFrame(panel->win);
	/*    WMSetWidgetBackgroundColor(panel->lowerF, WMBlackColor(scr)); */
	WMSetFrameRelief(panel->lowerF, WRFlat);
	WMSetViewNotifySizeChanges(WMWidgetView(panel->lowerF), True);

	WMAddSplitViewSubview(panel->split, W_VIEW(panel->upperF));
	WMAddSplitViewSubview(panel->split, W_VIEW(panel->lowerF));

	WMResizeWidget(panel->upperF, DEF_WIDTH, DEF_UPPER_HEIGHT);

	WMResizeWidget(panel->lowerF, DEF_WIDTH, DEF_LOWER_HEIGHT);

	WMMoveWidget(panel->lowerF, 0, 60 + divThickness);

	white = WMWhiteColor(scr);
	dark = WMDarkGrayColor(scr);

	panel->sampleT = WMCreateTextField(panel->upperF);
	WMResizeWidget(panel->sampleT, DEF_WIDTH - 20, 50);
	WMMoveWidget(panel->sampleT, 10, 10);
	WMSetTextFieldText(panel->sampleT, _("The quick brown fox jumps over the lazy dog"));

	font = WMBoldSystemFontOfSize(scr, 12);

	panel->famL = WMCreateLabel(panel->lowerF);
	WMSetWidgetBackgroundColor(panel->famL, dark);
	WMSetLabelText(panel->famL, _("Family"));
	WMSetLabelFont(panel->famL, font);
	WMSetLabelTextColor(panel->famL, white);
	WMSetLabelRelief(panel->famL, WRSunken);
	WMSetLabelTextAlignment(panel->famL, WACenter);

	panel->famLs = WMCreateList(panel->lowerF);
	WMSetListAction(panel->famLs, familyClick, panel);

	panel->typL = WMCreateLabel(panel->lowerF);
	WMSetWidgetBackgroundColor(panel->typL, dark);
	WMSetLabelText(panel->typL, _("Typeface"));
	WMSetLabelFont(panel->typL, font);
	WMSetLabelTextColor(panel->typL, white);
	WMSetLabelRelief(panel->typL, WRSunken);
	WMSetLabelTextAlignment(panel->typL, WACenter);

	panel->typLs = WMCreateList(panel->lowerF);
	WMSetListAction(panel->typLs, typefaceClick, panel);

	panel->sizL = WMCreateLabel(panel->lowerF);
	WMSetWidgetBackgroundColor(panel->sizL, dark);
	WMSetLabelText(panel->sizL, _("Size"));
	WMSetLabelFont(panel->sizL, font);
	WMSetLabelTextColor(panel->sizL, white);
	WMSetLabelRelief(panel->sizL, WRSunken);
	WMSetLabelTextAlignment(panel->sizL, WACenter);

	panel->sizT = WMCreateTextField(panel->lowerF);
	/*    WMSetTextFieldAlignment(panel->sizT, WARight); */

	panel->sizLs = WMCreateList(panel->lowerF);
	WMSetListAction(panel->sizLs, sizeClick, panel);

	WMReleaseFont(font);
	WMReleaseColor(white);
	WMReleaseColor(dark);

	panel->setB = WMCreateCommandButton(panel->win);
	WMResizeWidget(panel->setB, 70, 24);
	WMMoveWidget(panel->setB, 240, DEF_HEIGHT - (BUTTON_SPACE_HEIGHT - 5));
	WMSetButtonText(panel->setB, _("Set"));
	WMSetButtonAction(panel->setB, setClickedAction, panel);

	panel->revertB = WMCreateCommandButton(panel->win);
	WMResizeWidget(panel->revertB, 70, 24);
	WMMoveWidget(panel->revertB, 80, DEF_HEIGHT - (BUTTON_SPACE_HEIGHT - 5));
	WMSetButtonText(panel->revertB, _("Revert"));
	WMSetButtonAction(panel->revertB, revertClickedAction, panel);

	WMRealizeWidget(panel->win);

	WMMapSubwidgets(panel->upperF);
	WMMapSubwidgets(panel->lowerF);
	WMMapSubwidgets(panel->split);
	WMMapSubwidgets(panel->win);

	WMUnmapWidget(panel->revertB);

	arrangeLowerFrame(panel);

	scr->sharedFontPanel = panel;

	/* register notification observers */
	WMAddNotificationObserver(notificationObserver, panel,
				  WMViewSizeDidChangeNotification, WMWidgetView(panel->win));
	WMAddNotificationObserver(notificationObserver, panel,
				  WMViewSizeDidChangeNotification, WMWidgetView(panel->upperF));
	WMAddNotificationObserver(notificationObserver, panel,
				  WMViewSizeDidChangeNotification, WMWidgetView(panel->lowerF));

	listFamilies(scr, panel);

	return panel;
}

void WMFreeFontPanel(WMFontPanel * panel)
{
	if (panel == WMWidgetScreen(panel->win)->sharedFontPanel) {
		WMWidgetScreen(panel->win)->sharedFontPanel = NULL;
	}
	WMRemoveNotificationObserver(panel);
	WMUnmapWidget(panel->win);
	WMDestroyWidget(panel->win);
	wfree(panel);
}

void WMShowFontPanel(WMFontPanel * panel)
{
	WMMapWidget(panel->win);
}

void WMHideFontPanel(WMFontPanel * panel)
{
	WMUnmapWidget(panel->win);
}

WMFont *WMGetFontPanelFont(WMFontPanel * panel)
{
	return WMGetTextFieldFont(panel->sampleT);
}

void WMSetFontPanelFont(WMFontPanel * panel, const char *fontName)
{
	int fname_len;
	FcPattern *pattern;
	FcChar8 *family, *style;
	double size;

	if (!isXLFD(fontName, &fname_len)) {
		/* maybe its proper fontconfig and we can parse it */
		pattern = FcNameParse((const FcChar8 *) fontName);
	} else {
		/* maybe its proper xlfd and we can convert it to an FcPattern */
		pattern = XftXlfdParse(fontName, False, False);
		/*//FcPatternPrint(pattern); */
	}

	if (!pattern)
		return;

	if (FcPatternGetString(pattern, FC_FAMILY, 0, &family) == FcResultMatch)
		if (FcPatternGetString(pattern, FC_STYLE, 0, &style) == FcResultMatch)
			if (FcPatternGetDouble(pattern, "pixelsize", 0, &size) == FcResultMatch)
				setFontPanelFontName(panel, (char *)family, (char *)style, size);

	FcPatternDestroy(pattern);
}

void WMSetFontPanelAction(WMFontPanel * panel, WMAction2 * action, void *data)
{
	panel->action = action;
	panel->data = data;
}

static void arrangeLowerFrame(FontPanel * panel)
{
	int width = WMWidgetWidth(panel->lowerF) - 55 - 30;
	int height = WMWidgetHeight(panel->split) - WMWidgetHeight(panel->upperF);
	int fw, tw, sw;

#define LABEL_HEIGHT 20

	height -= WMGetSplitViewDividerThickness(panel->split);

	height -= LABEL_HEIGHT + 8;

	fw = (125 * width) / 235;
	tw = (110 * width) / 235;
	sw = 55;

	WMMoveWidget(panel->famL, 10, 0);
	WMResizeWidget(panel->famL, fw, LABEL_HEIGHT);

	WMMoveWidget(panel->famLs, 10, 23);
	WMResizeWidget(panel->famLs, fw, height);

	WMMoveWidget(panel->typL, 10 + fw + 3, 0);
	WMResizeWidget(panel->typL, tw, LABEL_HEIGHT);

	WMMoveWidget(panel->typLs, 10 + fw + 3, 23);
	WMResizeWidget(panel->typLs, tw, height);

	WMMoveWidget(panel->sizL, 10 + fw + 3 + tw + 3, 0);
	WMResizeWidget(panel->sizL, sw + 4, LABEL_HEIGHT);

	WMMoveWidget(panel->sizT, 10 + fw + 3 + tw + 3, 23);
	WMResizeWidget(panel->sizT, sw + 4, 20);

	WMMoveWidget(panel->sizLs, 10 + fw + 3 + tw + 3, 46);
	WMResizeWidget(panel->sizLs, sw + 4, height - 23);
}

#define NUM_FIELDS 14

static int isXLFD(const char *font, int *length_ret)
{
	int c = 0;

	*length_ret = 0;
	while (*font) {
		(*length_ret)++;
		if (*font++ == '-')
			c++;
	}

	return c == NUM_FIELDS;
}

typedef struct {
	char *typeface;
	WMArray *sizes;
} Typeface;

typedef struct {
	char *name;		/* gotta love simplicity */
	WMArray *typefaces;
} Family;

static int compare_int(const void *a, const void *b)
{
	int i1 = *(int *)a;
	int i2 = *(int *)b;

	if (i1 < i2)
		return -1;
	else if (i1 > i2)
		return 1;
	else
		return 0;
}

static void addSizeToTypeface(Typeface * face, int size)
{
	if (size == 0) {
		int j;

		for (j = 0; j < wlengthof(scalableFontSizes); j++) {
			size = scalableFontSizes[j];

			if (!WMCountInArray(face->sizes, (void *)(uintptr_t) size)) {
				WMAddToArray(face->sizes, (void *)(uintptr_t) size);
			}
		}
		WMSortArray(face->sizes, compare_int);
	} else {
		if (!WMCountInArray(face->sizes, (void *)(uintptr_t) size)) {
			WMAddToArray(face->sizes, (void *)(uintptr_t) size);
			WMSortArray(face->sizes, compare_int);
		}
	}
}

static void addTypefaceToXftFamily(Family * fam, const char *style)
{
	Typeface *face;
	WMArrayIterator i;

	if (fam->typefaces) {
		WM_ITERATE_ARRAY(fam->typefaces, face, i) {
			if (strcmp(face->typeface, style) != 0)
				continue;	/* go to next interation */
			addSizeToTypeface(face, 0);
			return;
		}
	} else {
		fam->typefaces = WMCreateArray(4);
	}

	face = wmalloc(sizeof(Typeface));

	face->typeface = wstrdup(style);
	face->sizes = WMCreateArray(4);
	addSizeToTypeface(face, 0);

	WMAddToArray(fam->typefaces, face);
}

/*
 * families (same family name) (Hashtable of family -> array)
 * 	registries (same family but different registries)
 *
 */
static void addFontToXftFamily(WMHashTable * families, const char *name, const char *style)
{
	WMArrayIterator i;
	WMArray *array;
	Family *fam;

	array = WMHashGet(families, name);
	if (array) {
		WM_ITERATE_ARRAY(array, fam, i) {
			if (strcmp(fam->name, name) == 0)
				addTypefaceToXftFamily(fam, style);
			return;
		}
	}

	array = WMCreateArray(8);

	fam = wmalloc(sizeof(Family));

	fam->name = wstrdup(name);

	addTypefaceToXftFamily(fam, style);

	WMAddToArray(array, fam);

	WMHashInsert(families, fam->name, array);
}

static void listFamilies(WMScreen * scr, WMFontPanel * panel)
{
	FcObjectSet *os = 0;
	FcFontSet *fs;
	FcPattern *pat;
	WMHashTable *families;
	WMHashEnumerator enumer;
	WMArray *array;
	int i;

	pat = FcPatternCreate();
	os = FcObjectSetBuild(FC_FAMILY, FC_STYLE, NULL);
	fs = FcFontList(0, pat, os);
	if (!fs) {
		WMRunAlertPanel(scr, panel->win, _("Error"),
				_("Could not init font config library\n"), _("OK"), NULL, NULL);
		return;
	}
	if (pat)
		FcPatternDestroy(pat);

	families = WMCreateHashTable(WMStringPointerHashCallbacks);

	if (fs) {
		for (i = 0; i < fs->nfont; i++) {
			FcChar8 *family;
			FcChar8 *style;

			if (FcPatternGetString(fs->fonts[i], FC_FAMILY, 0, &family) == FcResultMatch)
				if (FcPatternGetString(fs->fonts[i], FC_STYLE, 0, &style) == FcResultMatch)
					addFontToXftFamily(families, (char *)family, (char *)style);
		}
		FcFontSetDestroy(fs);
	}

	enumer = WMEnumerateHashTable(families);

	while ((array = WMNextHashEnumeratorItem(&enumer))) {
		WMArrayIterator i;
		Family *fam;
		char buffer[256];
		WMListItem *item;

		WM_ITERATE_ARRAY(array, fam, i) {
			wstrlcpy(buffer, fam->name, sizeof(buffer));
			item = WMAddListItem(panel->famLs, buffer);

			item->clientData = fam;
		}

		WMFreeArray(array);
	}

	WMSortListItems(panel->famLs);

	WMFreeHashTable(families);
}

static void getSelectedFont(FontPanel * panel, char buffer[], int bufsize)
{
	WMListItem *item;
	Family *family;
	Typeface *face;
	char *size;

	item = WMGetListSelectedItem(panel->famLs);
	if (!item)
		return;
	family = (Family *) item->clientData;

	item = WMGetListSelectedItem(panel->typLs);
	if (!item)
		return;
	face = (Typeface *) item->clientData;

	size = WMGetTextFieldText(panel->sizT);

	snprintf(buffer, bufsize, "%s:style=%s:pixelsize=%s", family->name, face->typeface, size);

	wfree(size);
}

static void preview(FontPanel * panel)
{
	char buffer[512];
	WMFont *font;

	getSelectedFont(panel, buffer, sizeof(buffer));
	font = WMCreateFont(WMWidgetScreen(panel->win), buffer);
	if (font) {
		WMSetTextFieldFont(panel->sampleT, font);
		WMReleaseFont(font);
	}
}

static void familyClick(WMWidget * w, void *data)
{
	WMList *lPtr = (WMList *) w;
	WMListItem *item;
	Family *family;
	Typeface *face;
	FontPanel *panel = (FontPanel *) data;
	WMArrayIterator i;
	/* current typeface and size */
	char *oface = NULL;
	char *osize = NULL;
	int facei = -1;
	int sizei = -1;

	/* must try to keep the same typeface and size for the new family */
	item = WMGetListSelectedItem(panel->typLs);
	if (item)
		oface = wstrdup(item->text);

	osize = WMGetTextFieldText(panel->sizT);

	item = WMGetListSelectedItem(lPtr);
	family = (Family *) item->clientData;

	WMClearList(panel->typLs);

	WM_ITERATE_ARRAY(family->typefaces, face, i) {
		char buffer[256];
		int top = 0;
		WMListItem *fitem;

		wstrlcpy(buffer, face->typeface, sizeof(buffer));
		if (strcasecmp(face->typeface, "Roman") == 0)
			top = 1;
		if (strcasecmp(face->typeface, "Regular") == 0)
			top = 1;
		if (top)
			fitem = WMInsertListItem(panel->typLs, 0, buffer);
		else
			fitem = WMAddListItem(panel->typLs, buffer);
		fitem->clientData = face;
	}

	if (oface) {
		facei = WMFindRowOfListItemWithTitle(panel->typLs, oface);
		wfree(oface);
	}
	if (facei < 0) {
		facei = 0;
	}
	WMSelectListItem(panel->typLs, facei);
	typefaceClick(panel->typLs, panel);

	if (osize) {
		sizei = WMFindRowOfListItemWithTitle(panel->sizLs, osize);
	}
	if (sizei >= 0) {
		WMSelectListItem(panel->sizLs, sizei);
		sizeClick(panel->sizLs, panel);
	}

	if (osize)
		wfree(osize);

	preview(panel);
}

static void typefaceClick(WMWidget * w, void *data)
{
	FontPanel *panel = (FontPanel *) data;
	WMListItem *item;
	Typeface *face;
	WMArrayIterator i;
	char buffer[32];

	char *osize = NULL;
	int sizei = -1;
	void *size;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	osize = WMGetTextFieldText(panel->sizT);

	item = WMGetListSelectedItem(panel->typLs);
	face = (Typeface *) item->clientData;

	WMClearList(panel->sizLs);

	WM_ITERATE_ARRAY(face->sizes, size, i) {
		if (size != NULL) {
			int size_int = (int) size;

			sprintf(buffer, "%i", size_int);

			WMAddListItem(panel->sizLs, buffer);
		}
	}

	if (osize) {
		sizei = WMFindRowOfListItemWithTitle(panel->sizLs, osize);
	}
	if (sizei < 0) {
		sizei = WMFindRowOfListItemWithTitle(panel->sizLs, "12");
	}
	if (sizei < 0) {
		sizei = 0;
	}
	WMSelectListItem(panel->sizLs, sizei);
	WMSetListPosition(panel->sizLs, sizei);
	sizeClick(panel->sizLs, panel);

	if (osize)
		wfree(osize);

	preview(panel);
}

static void sizeClick(WMWidget * w, void *data)
{
	FontPanel *panel = (FontPanel *) data;
	WMListItem *item;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	item = WMGetListSelectedItem(panel->sizLs);
	WMSetTextFieldText(panel->sizT, item->text);

	WMSelectTextFieldRange(panel->sizT, wmkrange(0, strlen(item->text)));

	preview(panel);
}

static void setFontPanelFontName(FontPanel * panel, const char *family, const char *style, double size)
{
	int famrow;
	int stlrow;
	int sz;
	char asize[64];
	void *vsize;
	WMListItem *item;
	Family *fam;
	Typeface *face;
	WMArrayIterator i;

	famrow = WMFindRowOfListItemWithTitle(panel->famLs, family);
	if (famrow < 0) {
		famrow = 0;
		return;
	}
	WMSelectListItem(panel->famLs, famrow);
	WMSetListPosition(panel->famLs, famrow);

	WMClearList(panel->typLs);

	item = WMGetListSelectedItem(panel->famLs);

	fam = (Family *) item->clientData;
	WM_ITERATE_ARRAY(fam->typefaces, face, i) {
		char buffer[256];
		int top = 0;
		WMListItem *fitem;

		wstrlcpy(buffer, face->typeface, sizeof(buffer));
		if (strcasecmp(face->typeface, "Roman") == 0)
			top = 1;
		if (top)
			fitem = WMInsertListItem(panel->typLs, 0, buffer);
		else
			fitem = WMAddListItem(panel->typLs, buffer);
		fitem->clientData = face;
	}

	stlrow = WMFindRowOfListItemWithTitle(panel->typLs, style);

	if (stlrow < 0) {
		stlrow = 0;
		return;
	}

	WMSelectListItem(panel->typLs, stlrow);

	item = WMGetListSelectedItem(panel->typLs);

	face = (Typeface *) item->clientData;

	WMClearList(panel->sizLs);

	WM_ITERATE_ARRAY(face->sizes, vsize, i) {
		char buffer[32];

		if (vsize != NULL) {
			int size_int = (int) vsize;

			sprintf(buffer, "%i", size_int);

			WMAddListItem(panel->sizLs, buffer);
		}
	}

	snprintf(asize, sizeof(asize) - 1, "%d", (int)(size + 0.5));

	sz = WMFindRowOfListItemWithTitle(panel->sizLs, asize);

	if (sz < 0) {
		return;
	}

	WMSelectListItem(panel->sizLs, sz);
	sizeClick(panel->sizLs, panel);

	return;
}
