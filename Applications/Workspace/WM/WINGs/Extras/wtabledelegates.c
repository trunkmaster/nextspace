
#include <stdint.h>
#include <WINGs/WINGsP.h>

#include "wtableview.h"

#include "wtabledelegates.h"

typedef struct {
	WMTableView *table;
	WMFont *font;
	GC gc;
	GC selGC;
	WMColor *textColor;
} StringData;

typedef struct {
	WMTableView *table;
	GC selGc;
} PixmapData;

typedef struct {
	WMTextField *widget;
	WMTableView *table;
	WMFont *font;
	GC gc;
	GC selGC;
	WMColor *textColor;
} StringEditorData;

typedef struct {
	WMPopUpButton *widget;
	WMTableView *table;
	WMFont *font;
	char **options;
	int count;
	GC gc;
	GC selGC;
	WMColor *textColor;
} EnumSelectorData;

typedef struct {
	WMButton *widget;
	WMTableView *table;
	Bool state;
	GC gc;
	GC selGC;
} BooleanSwitchData;

static char *SelectionColor = "#bbbbcc";

static void
stringDraw(WMScreen * scr, Drawable d, GC gc, GC sgc, WMColor * textColor,
	   WMFont * font, void *data, WMRect rect, Bool selected)
{
	int x, y;
	XRectangle rects[1];
	Display *dpy = WMScreenDisplay(scr);

	x = rect.pos.x + 5;
	y = rect.pos.y + (rect.size.height - WMFontHeight(font)) / 2;

	rects[0].x = rect.pos.x + 1;
	rects[0].y = rect.pos.y + 1;
	rects[0].width = rect.size.width - 1;
	rects[0].height = rect.size.height - 1;
	XSetClipRectangles(dpy, gc, 0, 0, rects, 1, YXSorted);

	if (!selected) {
		XFillRectangles(dpy, d, gc, rects, 1);

		WMDrawString(scr, d, textColor, font, x, y, data, strlen(data));
	} else {
		XFillRectangles(dpy, d, sgc, rects, 1);

		WMDrawString(scr, d, textColor, font, x, y, data, strlen(data));
	}

	XSetClipMask(dpy, gc, None);
}

static void pixmapDraw(WMScreen * scr, Drawable d, GC gc, GC sgc, WMPixmap * pixmap, WMRect rect, Bool selected)
{
	int x, y;
	XRectangle rects[1];
	Display *dpy = WMScreenDisplay(scr);
	WMSize size;

	rects[0].x = rect.pos.x + 1;
	rects[0].y = rect.pos.y + 1;
	rects[0].width = rect.size.width - 1;
	rects[0].height = rect.size.height - 1;
	XSetClipRectangles(dpy, gc, 0, 0, rects, 1, YXSorted);

	if (!selected) {
		XFillRectangles(dpy, d, gc, rects, 1);

		if (pixmap) {
			size = WMGetPixmapSize(pixmap);
			x = rect.pos.x + (rect.size.width - size.width) / 2;
			y = rect.pos.y + (rect.size.height - size.height) / 2;

			WMDrawPixmap(pixmap, d, x, y);
		}
	} else {
		XFillRectangles(dpy, d, sgc, rects, 1);

		if (pixmap) {
			size = WMGetPixmapSize(pixmap);
			x = rect.pos.x + (rect.size.width - size.width) / 2;
			y = rect.pos.y + (rect.size.height - size.height) / 2;

			WMDrawPixmap(pixmap, d, x, y);
		}
	}

	XSetClipMask(dpy, gc, None);
}

/* ---------------------------------------------------------------------- */

static void SECellPainter(WMTableColumnDelegate * self, WMTableColumn * column, int row, Drawable d)
{
	StringEditorData *strdata = (StringEditorData *) self->data;
	WMTableView *table = WMGetTableColumnTableView(column);

	stringDraw(WMWidgetScreen(table), d,
		   strdata->gc, strdata->selGC, strdata->textColor, strdata->font,
		   WMTableViewDataForCell(table, column, row), WMTableViewRectForCell(table, column, row), False);
}

static void selectedSECellPainter(WMTableColumnDelegate * self, WMTableColumn * column, int row, Drawable d)
{
	StringEditorData *strdata = (StringEditorData *) self->data;
	WMTableView *table = WMGetTableColumnTableView(column);

	stringDraw(WMWidgetScreen(table), d,
		   strdata->gc, strdata->selGC, strdata->textColor, strdata->font,
		   WMTableViewDataForCell(table, column, row), WMTableViewRectForCell(table, column, row), True);
}

static void beginSECellEdit(WMTableColumnDelegate * self, WMTableColumn * column, int row)
{
	StringEditorData *strdata = (StringEditorData *) self->data;
	WMRect rect = WMTableViewRectForCell(strdata->table, column, row);
	void *data = WMTableViewDataForCell(strdata->table, column, row);

	WMSetTextFieldText(strdata->widget, (char *)data);
	WMMoveWidget(strdata->widget, rect.pos.x, rect.pos.y);
	WMResizeWidget(strdata->widget, rect.size.width + 1, rect.size.height + 1);

	WMMapWidget(strdata->widget);
}

static void endSECellEdit(WMTableColumnDelegate * self, WMTableColumn * column, int row)
{
	StringEditorData *strdata = (StringEditorData *) self->data;
	char *text;

	WMUnmapWidget(strdata->widget);

	text = WMGetTextFieldText(strdata->widget);
	WMSetTableViewDataForCell(strdata->table, column, row, (void *)text);
}

WMTableColumnDelegate *WTCreateStringEditorDelegate(WMTableView * parent)
{
	WMTableColumnDelegate *delegate = wmalloc(sizeof(WMTableColumnDelegate));
	WMScreen *scr = WMWidgetScreen(parent);
	StringEditorData *data = wmalloc(sizeof(StringEditorData));

	data->widget = WMCreateTextField(parent);
	W_ReparentView(WMWidgetView(data->widget), WMGetTableViewDocumentView(parent), 0, 0);
	data->table = parent;
	data->font = WMSystemFontOfSize(scr, 12);
	data->gc = WMColorGC(WMWhiteColor(scr));
	data->selGC = WMColorGC(WMCreateNamedColor(scr, SelectionColor, False));
	data->textColor = WMBlackColor(scr);

	delegate->data = data;
	delegate->drawCell = SECellPainter;
	delegate->drawSelectedCell = selectedSECellPainter;
	delegate->beginCellEdit = beginSECellEdit;
	delegate->endCellEdit = endSECellEdit;

	return delegate;
}

/* ---------------------------------------------------------------------- */

static void ESCellPainter(WMTableColumnDelegate * self, WMTableColumn * column, int row, Drawable d)
{
	EnumSelectorData *strdata = (EnumSelectorData *) self->data;
	WMTableView *table = WMGetTableColumnTableView(column);
	uintptr_t i = (uintptr_t)WMTableViewDataForCell(table, column, row);

	stringDraw(WMWidgetScreen(table), d,
		   strdata->gc, strdata->selGC, strdata->textColor, strdata->font,
		   strdata->options[i], WMTableViewRectForCell(table, column, row), False);
}

static void selectedESCellPainter(WMTableColumnDelegate * self, WMTableColumn * column, int row, Drawable d)
{
	EnumSelectorData *strdata = (EnumSelectorData *) self->data;
	WMTableView *table = WMGetTableColumnTableView(column);
	uintptr_t i = (uintptr_t)WMTableViewDataForCell(table, column, row);

	stringDraw(WMWidgetScreen(table), d,
		   strdata->gc, strdata->selGC, strdata->textColor, strdata->font,
		   strdata->options[i], WMTableViewRectForCell(table, column, row), True);
}

static void beginESCellEdit(WMTableColumnDelegate * self, WMTableColumn * column, int row)
{
	EnumSelectorData *strdata = (EnumSelectorData *) self->data;
	WMRect rect = WMTableViewRectForCell(strdata->table, column, row);
	uintptr_t data = (uintptr_t)WMTableViewDataForCell(strdata->table, column, row);

	wassertr(data < strdata->count);

	WMSetPopUpButtonSelectedItem(strdata->widget, data);

	WMMoveWidget(strdata->widget, rect.pos.x, rect.pos.y);
	WMResizeWidget(strdata->widget, rect.size.width, rect.size.height + 1);

	WMMapWidget(strdata->widget);
}

static void endESCellEdit(WMTableColumnDelegate * self, WMTableColumn * column, int row)
{
	EnumSelectorData *strdata = (EnumSelectorData *) self->data;
	int option;

	WMUnmapWidget(strdata->widget);

	option = WMGetPopUpButtonSelectedItem(strdata->widget);
	WMSetTableViewDataForCell(strdata->table, column, row, (void *)(uintptr_t) option);
}

WMTableColumnDelegate *WTCreateEnumSelectorDelegate(WMTableView * parent)
{
	WMTableColumnDelegate *delegate = wmalloc(sizeof(WMTableColumnDelegate));
	WMScreen *scr = WMWidgetScreen(parent);
	EnumSelectorData *data = wmalloc(sizeof(EnumSelectorData));

	data->widget = WMCreatePopUpButton(parent);
	W_ReparentView(WMWidgetView(data->widget), WMGetTableViewDocumentView(parent), 0, 0);
	data->table = parent;
	data->font = WMSystemFontOfSize(scr, 12);
	data->gc = WMColorGC(WMWhiteColor(scr));
	data->selGC = WMColorGC(WMCreateNamedColor(scr, SelectionColor, False));
	data->textColor = WMBlackColor(scr);
	data->count = 0;
	data->options = NULL;

	delegate->data = data;
	delegate->drawCell = ESCellPainter;
	delegate->drawSelectedCell = selectedESCellPainter;
	delegate->beginCellEdit = beginESCellEdit;
	delegate->endCellEdit = endESCellEdit;

	return delegate;
}

void WTSetEnumSelectorOptions(WMTableColumnDelegate * delegate, char **options, int count)
{
	EnumSelectorData *data = (EnumSelectorData *) delegate->data;
	int i;

	for (i = 0; i < WMGetPopUpButtonNumberOfItems(data->widget); i++) {
		WMRemovePopUpButtonItem(data->widget, 0);
	}

	data->options = options;
	data->count = count;

	for (i = 0; i < count; i++) {
		WMAddPopUpButtonItem(data->widget, options[i]);
	}
}

/* ---------------------------------------------------------------------- */

static void BSCellPainter(WMTableColumnDelegate * self, WMTableColumn * column, int row, Drawable d)
{
	BooleanSwitchData *strdata = (BooleanSwitchData *) self->data;
	WMTableView *table = WMGetTableColumnTableView(column);
	uintptr_t i = (uintptr_t)WMTableViewDataForCell(table, column, row);
	WMScreen *scr = WMWidgetScreen(table);

	if (i) {
		pixmapDraw(scr, d,
			   strdata->gc, strdata->selGC, WMGetSystemPixmap(scr, WSICheckMark),
			   WMTableViewRectForCell(table, column, row), False);
	} else {
		pixmapDraw(scr, d,
			   strdata->gc, strdata->selGC, NULL, WMTableViewRectForCell(table, column, row), False);
	}
}

static void selectedBSCellPainter(WMTableColumnDelegate * self, WMTableColumn * column, int row, Drawable d)
{
	BooleanSwitchData *strdata = (BooleanSwitchData *) self->data;
	WMTableView *table = WMGetTableColumnTableView(column);
	uintptr_t i = (uintptr_t)WMTableViewDataForCell(table, column, row);
	WMScreen *scr = WMWidgetScreen(table);

	if (i) {
		pixmapDraw(scr, d,
			   strdata->gc, strdata->selGC, WMGetSystemPixmap(scr, WSICheckMark),
			   WMTableViewRectForCell(table, column, row), True);
	} else {
		pixmapDraw(scr, d,
			   strdata->gc, strdata->selGC, NULL, WMTableViewRectForCell(table, column, row), True);
	}
}

static void beginBSCellEdit(WMTableColumnDelegate * self, WMTableColumn * column, int row)
{
	BooleanSwitchData *strdata = (BooleanSwitchData *) self->data;
	WMRect rect = WMTableViewRectForCell(strdata->table, column, row);
	uintptr_t data = (uintptr_t)WMTableViewDataForCell(strdata->table, column, row);

	WMSetButtonSelected(strdata->widget, data);
	WMMoveWidget(strdata->widget, rect.pos.x + 1, rect.pos.y + 1);
	WMResizeWidget(strdata->widget, rect.size.width - 1, rect.size.height - 1);

	WMMapWidget(strdata->widget);
}

static void endBSCellEdit(WMTableColumnDelegate * self, WMTableColumn * column, int row)
{
	BooleanSwitchData *strdata = (BooleanSwitchData *) self->data;
	int value;

	value = WMGetButtonSelected(strdata->widget);
	WMSetTableViewDataForCell(strdata->table, column, row, (void *)(uintptr_t) value);
	WMUnmapWidget(strdata->widget);
}

WMTableColumnDelegate *WTCreateBooleanSwitchDelegate(WMTableView * parent)
{
	WMTableColumnDelegate *delegate = wmalloc(sizeof(WMTableColumnDelegate));
	WMScreen *scr = WMWidgetScreen(parent);
	BooleanSwitchData *data = wmalloc(sizeof(BooleanSwitchData));
	WMColor *color;

	data->widget = WMCreateSwitchButton(parent);
	W_ReparentView(WMWidgetView(data->widget), WMGetTableViewDocumentView(parent), 0, 0);
	WMSetButtonText(data->widget, NULL);
	WMSetButtonImagePosition(data->widget, WIPImageOnly);
	WMSetButtonImage(data->widget, NULL);
	WMSetButtonAltImage(data->widget, WMGetSystemPixmap(scr, WSICheckMark));

	data->table = parent;
	color = WMCreateNamedColor(scr, SelectionColor, False);
	WMSetWidgetBackgroundColor(data->widget, color);
	data->gc = WMColorGC(WMWhiteColor(scr));
	data->selGC = WMColorGC(color);

	delegate->data = data;
	delegate->drawCell = BSCellPainter;
	delegate->drawSelectedCell = selectedBSCellPainter;
	delegate->beginCellEdit = beginBSCellEdit;
	delegate->endCellEdit = endBSCellEdit;

	return delegate;
}

/* ---------------------------------------------------------------------- */

static void SCellPainter(WMTableColumnDelegate * self, WMTableColumn * column, int row, Drawable d)
{
	StringData *strdata = (StringData *) self->data;
	WMTableView *table = WMGetTableColumnTableView(column);

	stringDraw(WMWidgetScreen(table), d,
		   strdata->gc, strdata->selGC, strdata->textColor, strdata->font,
		   WMTableViewDataForCell(table, column, row), WMTableViewRectForCell(table, column, row), False);
}

static void selectedSCellPainter(WMTableColumnDelegate * self, WMTableColumn * column, int row, Drawable d)
{
	StringData *strdata = (StringData *) self->data;
	WMTableView *table = WMGetTableColumnTableView(column);

	stringDraw(WMWidgetScreen(table), d,
		   strdata->gc, strdata->selGC, strdata->textColor, strdata->font,
		   WMTableViewDataForCell(table, column, row), WMTableViewRectForCell(table, column, row), True);
}

WMTableColumnDelegate *WTCreateStringDelegate(WMTableView * parent)
{
	WMTableColumnDelegate *delegate = wmalloc(sizeof(WMTableColumnDelegate));
	WMScreen *scr = WMWidgetScreen(parent);
	StringData *data = wmalloc(sizeof(StringData));

	data->table = parent;
	data->font = WMSystemFontOfSize(scr, 12);
	data->gc = WMColorGC(WMWhiteColor(scr));
	data->selGC = WMColorGC(WMCreateNamedColor(scr, SelectionColor, False));
	data->textColor = WMBlackColor(scr);

	delegate->data = data;
	delegate->drawCell = SCellPainter;
	delegate->drawSelectedCell = selectedSCellPainter;
	delegate->beginCellEdit = NULL;
	delegate->endCellEdit = NULL;

	return delegate;
}

/* ---------------------------------------------------------------------- */

static void PCellPainter(WMTableColumnDelegate * self, WMTableColumn * column, int row, Drawable d)
{
	StringData *strdata = (StringData *) self->data;
	WMTableView *table = WMGetTableColumnTableView(column);

	pixmapDraw(WMWidgetScreen(table), d,
		   strdata->gc, strdata->selGC,
		   (WMPixmap *) WMTableViewDataForCell(table, column, row),
		   WMTableViewRectForCell(table, column, row), False);
}

static void selectedPCellPainter(WMTableColumnDelegate * self, WMTableColumn * column, int row, Drawable d)
{
	StringData *strdata = (StringData *) self->data;
	WMTableView *table = WMGetTableColumnTableView(column);

	pixmapDraw(WMWidgetScreen(table), d,
		   strdata->gc, strdata->selGC,
		   (WMPixmap *) WMTableViewDataForCell(table, column, row),
		   WMTableViewRectForCell(table, column, row), True);
}

WMTableColumnDelegate *WTCreatePixmapDelegate(WMTableView * table)
{
	WMTableColumnDelegate *delegate = wmalloc(sizeof(WMTableColumnDelegate));
	WMScreen *scr = WMWidgetScreen(table);
	StringData *data = wmalloc(sizeof(StringData));

	data->table = table;
	data->gc = WMColorGC(WMWhiteColor(scr));
	data->selGC = WMColorGC(WMCreateNamedColor(scr, SelectionColor, False));

	delegate->data = data;
	delegate->drawCell = PCellPainter;
	delegate->drawSelectedCell = selectedPCellPainter;
	delegate->beginCellEdit = NULL;
	delegate->endCellEdit = NULL;

	return delegate;
}

/* ---------------------------------------------------------------------- */

static void drawPSCell(WMTableColumnDelegate * self, Drawable d, WMTableColumn * column, int row, Bool selected)
{
	StringData *strdata = (StringData *) self->data;
	WMTableView *table = WMGetTableColumnTableView(column);
	void **data;
	WMPixmap *pix;
	char *str;
	WMRect rect;
	WMSize size;

	data = WMTableViewDataForCell(table, column, row);

	str = (char *)data[0];
	pix = (WMPixmap *) data[1];

	rect = WMTableViewRectForCell(table, column, row);

	if (pix) {
		int owidth = rect.size.width;

		size = WMGetPixmapSize(pix);
		rect.size.width = size.width;

		pixmapDraw(WMWidgetScreen(table),
			   WMViewXID(WMGetTableViewDocumentView(table)),
			   strdata->gc, strdata->selGC, pix, rect, selected);

		rect.pos.x += size.width - 1;
		rect.size.width = owidth - size.width + 1;
	}

	stringDraw(WMWidgetScreen(table), d, strdata->gc, strdata->selGC,
		   strdata->textColor, strdata->font, str, rect, selected);
}

static void PSCellPainter(WMTableColumnDelegate * self, WMTableColumn * column, int row, Drawable d)
{
	drawPSCell(self, d, column, row, False);
}

static void selectedPSCellPainter(WMTableColumnDelegate * self, WMTableColumn * column, int row, Drawable d)
{
	drawPSCell(self, d, column, row, True);
}

WMTableColumnDelegate *WTCreatePixmapStringDelegate(WMTableView * parent)
{
	WMTableColumnDelegate *delegate = wmalloc(sizeof(WMTableColumnDelegate));
	WMScreen *scr = WMWidgetScreen(parent);
	StringData *data = wmalloc(sizeof(StringData));

	data->table = parent;
	data->font = WMSystemFontOfSize(scr, 12);
	data->gc = WMColorGC(WMWhiteColor(scr));
	data->selGC = WMColorGC(WMCreateNamedColor(scr, SelectionColor, False));
	data->textColor = WMBlackColor(scr);

	delegate->data = data;
	delegate->drawCell = PSCellPainter;
	delegate->drawSelectedCell = selectedPSCellPainter;
	delegate->beginCellEdit = NULL;
	delegate->endCellEdit = NULL;

	return delegate;
}
