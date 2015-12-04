
#include <WINGs/WINGsP.h>
#include <X11/cursorfont.h>
#include <stdint.h>

#include "wtableview.h"

const char *WMTableViewSelectionDidChangeNotification = "WMTableViewSelectionDidChangeNotification";

struct W_TableColumn {
	WMTableView *table;
	WMWidget *titleW;
	char *title;
	int width;
	int minWidth;
	int maxWidth;

	void *id;

	WMTableColumnDelegate *delegate;

	unsigned resizable:1;
	unsigned editable:1;
};

static void handleResize(W_ViewDelegate * self, WMView * view);

static void rearrangeHeader(WMTableView * table);

static WMRange rowsInRect(WMTableView * table, WMRect rect);

WMTableColumn *WMCreateTableColumn(char *title)
{
	WMTableColumn *col = wmalloc(sizeof(WMTableColumn));

	col->table = NULL;
	col->titleW = NULL;
	col->width = 50;
	col->minWidth = 5;
	col->maxWidth = 0;

	col->id = NULL;

	col->title = wstrdup(title);

	col->delegate = NULL;

	col->resizable = 1;
	col->editable = 0;

	return col;
}

void WMSetTableColumnId(WMTableColumn * column, void *id)
{
	column->id = id;
}

void *WMGetTableColumnId(WMTableColumn * column)
{
	return column->id;
}

void WMSetTableColumnWidth(WMTableColumn * column, unsigned width)
{
	if (column->maxWidth == 0)
		column->width = WMAX(column->minWidth, width);
	else
		column->width = WMAX(column->minWidth, WMIN(column->maxWidth, width));

	if (column->table) {
		rearrangeHeader(column->table);
	}
}

void WMSetTableColumnDelegate(WMTableColumn * column, WMTableColumnDelegate * delegate)
{
	column->delegate = delegate;
}

void WMSetTableColumnConstraints(WMTableColumn * column, unsigned minWidth, unsigned maxWidth)
{
	wassertr(maxWidth == 0 || minWidth <= maxWidth);

	column->minWidth = minWidth;
	column->maxWidth = maxWidth;

	if (column->width < column->minWidth)
		WMSetTableColumnWidth(column, column->minWidth);
	else if (column->width > column->maxWidth && column->maxWidth != 0)
		WMSetTableColumnWidth(column, column->maxWidth);
}

void WMSetTableColumnEditable(WMTableColumn * column, Bool flag)
{
	column->editable = ((flag == 0) ? 0 : 1);
}

WMTableView *WMGetTableColumnTableView(WMTableColumn * column)
{
	return column->table;
}

struct W_TableView {
	W_Class widgetClass;
	WMView *view;

	WMFrame *header;

	WMLabel *corner;

	WMScroller *hscroll;
	WMScroller *vscroll;
	WMView *tableView;

	WMPixmap *viewBuffer;

	WMArray *columns;
	WMArray *splitters;

	WMArray *selectedRows;

	int tableWidth;

	int rows;

	WMColor *backColor;

	GC gridGC;
	WMColor *gridColor;

	Cursor splitterCursor;

	void *dataSource;

	WMTableViewDelegate *delegate;

	WMAction *action;
	void *clientData;

	void *clickedColumn;
	int clickedRow;

	int editingRow;

	unsigned headerHeight;

	unsigned rowHeight;

	unsigned dragging:1;
	unsigned drawsGrid:1;
	unsigned canSelectRow:1;
	unsigned canSelectMultiRows:1;
	unsigned canDeselectRow:1;

	unsigned int hasVScroller:1;
	unsigned int hasHScroller:1;
};

static W_Class tableClass = 0;

static W_ViewDelegate viewDelegate = {
	NULL,
	NULL,
	handleResize,
	NULL,
	NULL
};

static void reorganizeInterior(WMTableView * table);

static void handleEvents(XEvent * event, void *data);
static void handleTableEvents(XEvent * event, void *data);
static void repaintTable(WMTableView * table);

static WMSize getTotalSize(WMTableView * table)
{
	WMSize size;
	int i;

	/* get width from columns */
	size.width = 0;
	for (i = 0; i < WMGetArrayItemCount(table->columns); i++) {
		WMTableColumn *column;

		column = WMGetFromArray(table->columns, i);

		size.width += column->width;
	}

	/* get height from rows */
	size.height = table->rows * table->rowHeight;

	return size;
}

static WMRect getVisibleRect(WMTableView * table)
{
	WMSize size = getTotalSize(table);
	WMRect rect;

	if (table->vscroll) {
		rect.size.height = size.height * WMGetScrollerKnobProportion(table->vscroll);
		rect.pos.y = (size.height - rect.size.height) * WMGetScrollerValue(table->vscroll);
	} else {
		rect.size.height = size.height;
		rect.pos.y = 0;
	}

	if (table->hscroll) {
		rect.size.width = size.width * WMGetScrollerKnobProportion(table->hscroll);
		rect.pos.x = (size.width - rect.size.width) * WMGetScrollerValue(table->hscroll);
	} else {
		rect.size.width = size.width;
		rect.pos.x = 0;
	}

	return rect;
}

static void scrollToPoint(WMTableView * table, int x, int y)
{
	WMSize size = getTotalSize(table);
	int i;
	float value, prop;

	if (table->hscroll) {
		if (size.width > W_VIEW_WIDTH(table->tableView)) {
			prop = (float)W_VIEW_WIDTH(table->tableView) / (float)size.width;
			value = (float)x / (float)(size.width - W_VIEW_WIDTH(table->tableView));
		} else {
			prop = 1.0;
			value = 0.0;
		}
		WMSetScrollerParameters(table->hscroll, value, prop);
	}

	if (table->vscroll) {
		if (size.height > W_VIEW_HEIGHT(table->tableView)) {
			prop = (float)W_VIEW_HEIGHT(table->tableView) / (float)size.height;
			value = (float)y / (float)(size.height - W_VIEW_HEIGHT(table->tableView));
		} else {
			prop = 1.0;
			value = 0.0;
		}

		WMSetScrollerParameters(table->vscroll, value, prop);
	}

	if (table->editingRow >= 0) {
		for (i = 0; i < WMGetArrayItemCount(table->columns); i++) {
			WMTableColumn *column;

			column = WMGetFromArray(table->columns, i);

			if (column->delegate && column->delegate->beginCellEdit)
				(*column->delegate->beginCellEdit) (column->delegate, column, table->editingRow);
		}
	}

	repaintTable(table);
}

static void adjustScrollers(WMTableView * table)
{
	WMSize size = getTotalSize(table);
	WMSize vsize = WMGetViewSize(table->tableView);
	float prop, value;
	float oprop, ovalue;

	if (table->hscroll) {
		if (size.width <= vsize.width) {
			value = 0.0;
			prop = 1.0;
		} else {
			oprop = WMGetScrollerKnobProportion(table->hscroll);
			if (oprop == 0.0)
				oprop = 1.0;
			ovalue = WMGetScrollerValue(table->hscroll);

			prop = (float)vsize.width / (float)size.width;
			value = prop * ovalue / oprop;
		}
		WMSetScrollerParameters(table->hscroll, value, prop);
	}

	if (table->vscroll) {
		if (size.height <= vsize.height) {
			value = 0.0;
			prop = 1.0;
		} else {
			oprop = WMGetScrollerKnobProportion(table->vscroll);
			if (oprop == 0.0)
				oprop = 1.0;
			ovalue = WMGetScrollerValue(table->vscroll);

			prop = (float)vsize.height / (float)size.height;
			value = prop * ovalue / oprop;
		}
		WMSetScrollerParameters(table->vscroll, value, prop);
	}
}

static void doScroll(WMWidget * self, void *data)
{
	WMTableView *table = (WMTableView *) data;
	float value;
	float vpsize;
	float size;
	WMSize ts = getTotalSize(table);

	value = WMGetScrollerValue(self);

	if (table->hscroll == (WMScroller *) self) {
		vpsize = W_VIEW_WIDTH(table->tableView);
		size = ts.width;
	} else {
		vpsize = W_VIEW_HEIGHT(table->tableView);
		size = ts.height;
	}

	switch (WMGetScrollerHitPart(self)) {
	case WSDecrementWheel:
	case WSDecrementLine:
		value -= (float)table->rowHeight / size;
		if (value < 0)
			value = 0.0;
		WMSetScrollerParameters(self, value, WMGetScrollerKnobProportion(self));
		repaintTable(table);
		break;

	case WSIncrementWheel:
	case WSIncrementLine:
		value += (float)table->rowHeight / size;
		if (value > 1.0)
			value = 1.0;
		WMSetScrollerParameters(self, value, WMGetScrollerKnobProportion(self));
		repaintTable(table);
		break;

	case WSKnob:
		repaintTable(table);
		break;

	case WSDecrementPage:
		value -= vpsize / size;
		if (value < 0.0)
			value = 0.0;
		WMSetScrollerParameters(self, value, WMGetScrollerKnobProportion(self));
		repaintTable(table);
		break;

	case WSIncrementPage:
		value += vpsize / size;
		if (value > 1.0)
			value = 1.0;
		WMSetScrollerParameters(self, value, WMGetScrollerKnobProportion(self));
		repaintTable(table);
		break;

	case WSNoPart:
	case WSKnobSlot:
		break;
	}

	if (table->editingRow >= 0) {
		int i;
		for (i = 0; i < WMGetArrayItemCount(table->columns); i++) {
			WMTableColumn *column;

			column = WMGetFromArray(table->columns, i);

			if (column->delegate && column->delegate->beginCellEdit)
				(*column->delegate->beginCellEdit) (column->delegate, column, table->editingRow);
		}
	}

	if (table->hscroll == self) {
		int x = 0;
		int i;
		WMRect rect = getVisibleRect(table);

		for (i = 0; i < WMGetArrayItemCount(table->columns); i++) {
			WMTableColumn *column;
			WMView *splitter;

			column = WMGetFromArray(table->columns, i);

			WMMoveWidget(column->titleW, x - rect.pos.x, 0);

			x += W_VIEW_WIDTH(WMWidgetView(column->titleW)) + 1;

			splitter = WMGetFromArray(table->splitters, i);
			W_MoveView(splitter, x - rect.pos.x - 1, 0);
		}
	}
}

static void splitterHandler(XEvent * event, void *data)
{
	WMTableColumn *column = (WMTableColumn *) data;
	WMTableView *table = column->table;
	int done = 0;
	int cx, ox, offsX;
	WMPoint pos;
	WMScreen *scr = WMWidgetScreen(table);
	GC gc = scr->ixorGC;
	Display *dpy = WMScreenDisplay(scr);
	int h = WMWidgetHeight(table) - 22;
	Window w = WMViewXID(table->view);

	pos = WMGetViewPosition(WMWidgetView(column->titleW));

	offsX = pos.x + column->width;

	ox = cx = offsX;

	XDrawLine(dpy, w, gc, cx + 20, 0, cx + 20, h);

	while (!done) {
		XEvent ev;

		WMMaskEvent(dpy, ButtonMotionMask | ButtonReleaseMask, &ev);

		switch (ev.type) {
		case MotionNotify:
			ox = cx;

			if (column->width + ev.xmotion.x < column->minWidth)
				cx = pos.x + column->minWidth;
			else if (column->maxWidth > 0 && column->width + ev.xmotion.x > column->maxWidth)
				cx = pos.x + column->maxWidth;
			else
				cx = offsX + ev.xmotion.x;

			XDrawLine(dpy, w, gc, ox + 20, 0, ox + 20, h);
			XDrawLine(dpy, w, gc, cx + 20, 0, cx + 20, h);
			break;

		case ButtonRelease:
			column->width = cx - pos.x;
			done = 1;
			break;
		}
	}

	XDrawLine(dpy, w, gc, cx + 20, 0, cx + 20, h);
	rearrangeHeader(table);
	repaintTable(table);
}

static void realizeTable(void *data, WMNotification * notif)
{
	repaintTable(data);
}

WMTableView *WMCreateTableView(WMWidget * parent)
{
	WMTableView *table = wmalloc(sizeof(WMTableView));
	WMScreen *scr = WMWidgetScreen(parent);

	memset(table, 0, sizeof(WMTableView));

	if (!tableClass) {
		tableClass = W_RegisterUserWidget();
	}
	table->widgetClass = tableClass;

	table->view = W_CreateView(W_VIEW(parent));
	if (!table->view)
		goto error;
	table->view->self = table;

	table->view->delegate = &viewDelegate;

	table->headerHeight = 20;

	table->hscroll = WMCreateScroller(table);
	WMSetScrollerAction(table->hscroll, doScroll, table);
	WMMoveWidget(table->hscroll, 1, 2 + table->headerHeight);
	WMMapWidget(table->hscroll);

	table->hasHScroller = 1;

	table->vscroll = WMCreateScroller(table);
	WMSetScrollerArrowsPosition(table->vscroll, WSAMaxEnd);
	WMSetScrollerAction(table->vscroll, doScroll, table);
	WMMoveWidget(table->vscroll, 1, 2 + table->headerHeight);
	WMMapWidget(table->vscroll);

	table->hasVScroller = 1;

	table->header = WMCreateFrame(table);
	WMMoveWidget(table->header, 22, 2);
	WMMapWidget(table->header);
	WMSetFrameRelief(table->header, WRFlat);

	table->corner = WMCreateLabel(table);
	WMResizeWidget(table->corner, 20, table->headerHeight);
	WMMoveWidget(table->corner, 2, 2);
	WMMapWidget(table->corner);
	WMSetLabelRelief(table->corner, WRRaised);
	WMSetWidgetBackgroundColor(table->corner, scr->darkGray);

	table->tableView = W_CreateView(table->view);
	if (!table->tableView)
		goto error;
	table->tableView->self = table;
	W_MapView(table->tableView);

	WMAddNotificationObserver(realizeTable, table, WMViewRealizedNotification, table->tableView);

	table->tableView->flags.dontCompressExpose = 1;

	table->gridColor = WMCreateNamedColor(scr, "#cccccc", False);
	/*   table->gridColor = WMGrayColor(scr); */

	{
		XGCValues gcv;

		table->backColor = WMWhiteColor(scr);

		gcv.foreground = WMColorPixel(table->gridColor);
		gcv.dashes = 1;
		gcv.line_style = LineOnOffDash;
		table->gridGC = XCreateGC(WMScreenDisplay(scr), W_DRAWABLE(scr), GCForeground, &gcv);
	}

	table->editingRow = -1;
	table->clickedRow = -1;

	table->drawsGrid = 1;
	table->rowHeight = 16;

	table->tableWidth = 1;

	table->columns = WMCreateArray(4);
	table->splitters = WMCreateArray(4);

	table->selectedRows = WMCreateArray(16);

	table->splitterCursor = XCreateFontCursor(WMScreenDisplay(scr), XC_sb_h_double_arrow);

	table->canSelectRow = 1;

	WMCreateEventHandler(table->view, ExposureMask | StructureNotifyMask, handleEvents, table);

	WMCreateEventHandler(table->tableView, ExposureMask | ButtonPressMask |
			     ButtonReleaseMask | ButtonMotionMask, handleTableEvents, table);

	WMResizeWidget(table, 50, 50);

	return table;

 error:
	if (table->tableView)
		W_DestroyView(table->tableView);
	if (table->view)
		W_DestroyView(table->view);
	wfree(table);
	return NULL;
}

void WMAddTableViewColumn(WMTableView * table, WMTableColumn * column)
{
	WMScreen *scr = WMWidgetScreen(table);

	column->table = table;

	WMAddToArray(table->columns, column);

	if (!column->titleW) {
		column->titleW = WMCreateLabel(table);
		WMSetLabelRelief(column->titleW, WRRaised);
		WMSetLabelFont(column->titleW, scr->boldFont);
		WMSetLabelTextColor(column->titleW, scr->white);
		WMSetWidgetBackgroundColor(column->titleW, scr->darkGray);
		WMSetLabelText(column->titleW, column->title);
		W_ReparentView(WMWidgetView(column->titleW), WMWidgetView(table->header), 0, 0);
		if (W_VIEW_REALIZED(table->view))
			WMRealizeWidget(column->titleW);
		WMMapWidget(column->titleW);
	}

	{
		WMView *splitter = W_CreateView(WMWidgetView(table->header));

		W_SetViewBackgroundColor(splitter, WMWhiteColor(scr));

		if (W_VIEW_REALIZED(table->view))
			W_RealizeView(splitter);

		W_ResizeView(splitter, 2, table->headerHeight);
		W_MapView(splitter);

		W_SetViewCursor(splitter, table->splitterCursor);
		WMCreateEventHandler(splitter, ButtonPressMask | ButtonReleaseMask, splitterHandler, column);

		WMAddToArray(table->splitters, splitter);
	}

	rearrangeHeader(table);
}

void WMSetTableViewHeaderHeight(WMTableView * table, unsigned height)
{
	table->headerHeight = height;

	handleResize(NULL, table->view);
}

void WMSetTableViewDelegate(WMTableView * table, WMTableViewDelegate * delegate)
{
	table->delegate = delegate;
}

void WMSetTableViewAction(WMTableView * table, WMAction * action, void *clientData)
{
	table->action = action;

	table->clientData = clientData;
}

void *WMGetTableViewClickedColumn(WMTableView * table)
{
	return table->clickedColumn;
}

int WMGetTableViewClickedRow(WMTableView * table)
{
	return table->clickedRow;
}

WMArray *WMGetTableViewSelectedRows(WMTableView * table)
{
	return table->selectedRows;
}

WMView *WMGetTableViewDocumentView(WMTableView * table)
{
	return table->tableView;
}

void *WMTableViewDataForCell(WMTableView * table, WMTableColumn * column, int row)
{
	return (*table->delegate->valueForCell) (table->delegate, column, row);
}

void WMSetTableViewDataForCell(WMTableView * table, WMTableColumn * column, int row, void *data)
{
	(*table->delegate->setValueForCell) (table->delegate, column, row, data);
}

WMRect WMTableViewRectForCell(WMTableView * table, WMTableColumn * column, int row)
{
	WMRect rect;
	int i;

	rect.pos.x = 0;
	rect.pos.y = row * table->rowHeight;
	rect.size.height = table->rowHeight;

	for (i = 0; i < WMGetArrayItemCount(table->columns); i++) {
		WMTableColumn *col;
		col = WMGetFromArray(table->columns, i);

		if (col == column) {
			rect.size.width = col->width;
			break;
		}

		rect.pos.x += col->width;
	}

	{
		WMRect r = getVisibleRect(table);

		rect.pos.y -= r.pos.y;
		rect.pos.x -= r.pos.x;
	}

	return rect;
}

void WMSetTableViewDataSource(WMTableView * table, void *source)
{
	table->dataSource = source;
}

void *WMGetTableViewDataSource(WMTableView * table)
{
	return table->dataSource;
}

void WMSetTableViewHasHorizontalScroller(WMTableView * tPtr, Bool flag)
{
	if (flag) {
		if (tPtr->hasHScroller)
			return;
		tPtr->hasHScroller = 1;

		tPtr->hscroll = WMCreateScroller(tPtr);
		WMSetScrollerAction(tPtr->hscroll, doScroll, tPtr);
		WMSetScrollerArrowsPosition(tPtr->hscroll, WSAMaxEnd);
		/* make it a horiz. scroller */
		WMResizeWidget(tPtr->hscroll, 1, 2);

		if (W_VIEW_REALIZED(tPtr->view)) {
			WMRealizeWidget(tPtr->hscroll);
		}

		reorganizeInterior(tPtr);

		WMMapWidget(tPtr->hscroll);
	} else {
		if (!tPtr->hasHScroller)
			return;
		tPtr->hasHScroller = 0;

		WMUnmapWidget(tPtr->hscroll);
		WMDestroyWidget(tPtr->hscroll);
		tPtr->hscroll = NULL;

		reorganizeInterior(tPtr);
	}
}

#if 0
/* not supported by now */
void WMSetTableViewHasVerticalScroller(WMTableView * tPtr, Bool flag)
{
	if (flag) {
		if (tPtr->hasVScroller)
			return;
		tPtr->hasVScroller = 1;

		tPtr->vscroll = WMCreateScroller(tPtr);
		WMSetScrollerAction(tPtr->vscroll, doScroll, tPtr);
		WMSetScrollerArrowsPosition(tPtr->vscroll, WSAMaxEnd);
		/* make it a vert. scroller */
		WMResizeWidget(tPtr->vscroll, 1, 2);

		if (W_VIEW_REALIZED(tPtr->view)) {
			WMRealizeWidget(tPtr->vscroll);
		}

		reorganizeInterior(tPtr);

		WMMapWidget(tPtr->vscroll);
	} else {
		if (!tPtr->hasVScroller)
			return;
		tPtr->hasVScroller = 0;

		WMUnmapWidget(tPtr->vscroll);
		WMDestroyWidget(tPtr->vscroll);
		tPtr->vscroll = NULL;

		reorganizeInterior(tPtr);
	}
}
#endif

void WMSetTableViewBackgroundColor(WMTableView * table, WMColor * color)
{
	W_SetViewBackgroundColor(table->tableView, color);

	if (table->backColor)
		WMReleaseColor(table->backColor);

	table->backColor = WMRetainColor(color);

	repaintTable(table);
}

void WMSetTableViewGridColor(WMTableView * table, WMColor * color)
{
	WMReleaseColor(table->gridColor);
	table->gridColor = WMRetainColor(color);
	XSetForeground(WMScreenDisplay(WMWidgetScreen(table)), table->gridGC, WMColorPixel(color));
	repaintTable(table);
}

void WMSetTableViewRowHeight(WMTableView * table, int height)
{
	table->rowHeight = height;

	repaintTable(table);
}

void WMScrollTableViewRowToVisible(WMTableView * table, int row)
{
	WMScroller *scroller;
	WMRange range;
	WMRect rect;
	int newY, tmp;

	rect = getVisibleRect(table);
	range = rowsInRect(table, rect);

	scroller = table->vscroll;

	if (row < range.position) {
		newY = row * table->rowHeight - rect.size.height / 2;
	} else if (row >= range.position + range.count) {
		newY = row * table->rowHeight - rect.size.height / 2;
	} else {
		return;
	}
	tmp = table->rows * table->rowHeight - rect.size.height;
	newY = WMAX(0, WMIN(newY, tmp));

	scrollToPoint(table, rect.pos.x, newY);
}

static void drawGrid(WMTableView * table, WMRect rect)
{
	WMScreen *scr = WMWidgetScreen(table);
	Display *dpy = WMScreenDisplay(scr);
	int i;
	int y1, y2;
	int x1, x2;
	int xx;
	Drawable d = WMGetPixmapXID(table->viewBuffer);
	GC gc = table->gridGC;

#if 0
	char dashl[1] = { 1 };

	XSetDashes(dpy, gc, 0, dashl, 1);

	y1 = (rect.pos.y / table->rowHeight - 1) * table->rowHeight;
	y2 = y1 + (rect.size.height / table->rowHeight + 2) * table->rowHeight;
#endif
	y1 = 0;
	y2 = W_VIEW_HEIGHT(table->tableView);

	xx = -rect.pos.x;
	for (i = 0; i < WMGetArrayItemCount(table->columns); i++) {
		WMTableColumn *column;

		XDrawLine(dpy, d, gc, xx, y1, xx, y2);

		column = WMGetFromArray(table->columns, i);
		xx += column->width;
	}
	XDrawLine(dpy, d, gc, xx, y1, xx, y2);

	x1 = 0;
	x2 = rect.size.width;

	if (x2 <= x1)
		return;
#if 0
	XSetDashes(dpy, gc, (rect.pos.x & 1), dashl, 1);
#endif

	y1 = -rect.pos.y % table->rowHeight;
	y2 = y1 + rect.size.height + table->rowHeight;

	for (i = y1; i <= y2; i += table->rowHeight) {
		XDrawLine(dpy, d, gc, x1, i, x2, i);
	}
}

static WMRange columnsInRect(WMTableView * table, WMRect rect)
{
	WMTableColumn *column;
	int pos;
	int i, found;
	int totalColumns = WMGetArrayItemCount(table->columns);
	WMRange range;

	pos = 0;
	found = 0;
	for (i = 0; i < totalColumns; i++) {
		column = WMGetFromArray(table->columns, i);
		if (!found) {
			if (rect.pos.x >= pos && rect.pos.x < pos + column->width) {
				range.position = i;
				range.count = 1;
				found = 1;
			}
		} else {
			if (pos > rect.pos.x + rect.size.width) {
				break;
			}
			range.count++;
		}
		pos += column->width;
	}
	range.count = WMAX(1, WMIN(range.count, totalColumns - range.position));
	return range;
}

static WMRange rowsInRect(WMTableView * table, WMRect rect)
{
	WMRange range;
	int rh = table->rowHeight;
	int dif;

	dif = rect.pos.y % rh;

	range.position = WMAX(0, (rect.pos.y - dif) / rh);
	range.count = WMAX(1, WMIN((rect.size.height + dif) / rh, table->rows));

	return range;
}

static void drawRow(WMTableView * table, int row, WMRect clipRect)
{
	int i;
	WMRange cols = columnsInRect(table, clipRect);
	WMTableColumn *column;
	Drawable d = WMGetPixmapXID(table->viewBuffer);

	for (i = cols.position; i < cols.position + cols.count; i++) {
		column = WMGetFromArray(table->columns, i);

		if (!column->delegate || !column->delegate->drawCell)
			continue;

		if (WMFindInArray(table->selectedRows, NULL, (void *)(uintptr_t) row) != WANotFound)
			(*column->delegate->drawSelectedCell) (column->delegate, column, row, d);
		else
			(*column->delegate->drawCell) (column->delegate, column, row, d);
	}
}

#if 0
static void drawFullRow(WMTableView * table, int row)
{
	int i;
	WMTableColumn *column;
	Drawable d = WMGetPixmapXID(table->viewBuffer);

	for (i = 0; i < WMGetArrayItemCount(table->columns); i++) {
		column = WMGetFromArray(table->columns, i);

		if (!column->delegate || !column->delegate->drawCell)
			continue;

		if (WMFindInArray(table->selectedRows, NULL, (void *)row) != WANotFound)
			(*column->delegate->drawSelectedCell) (column->delegate, column, row, d);
		else
			(*column->delegate->drawCell) (column->delegate, column, row, d);
	}
}
#endif

static void setRowSelected(WMTableView * table, unsigned row, Bool flag)
{
	int repaint = 0;

	if (WMFindInArray(table->selectedRows, NULL, (void *)(uintptr_t) row) != WANotFound) {
		if (!flag) {
			WMRemoveFromArray(table->selectedRows, (void *)(uintptr_t) row);
			repaint = 1;
		}
	} else {
		if (flag) {
			WMAddToArray(table->selectedRows, (void *)(uintptr_t) row);
			repaint = 1;
		}
	}
	if (repaint && row < table->rows) {
		/*drawFullRow(table, row); */
		repaintTable(table);
	}
}

static void repaintTable(WMTableView * table)
{
	WMRect rect;
	WMRange rows;
	WMScreen *scr = WMWidgetScreen(table);
	int i;

	if (!table->delegate || !W_VIEW_REALIZED(table->view))
		return;

	wassertr(table->delegate->numberOfRows);

	if (!table->viewBuffer) {
		table->viewBuffer = WMCreatePixmap(scr,
						   W_VIEW_WIDTH(table->tableView),
						   W_VIEW_HEIGHT(table->tableView), WMScreenDepth(scr), 0);
	}

	XFillRectangle(scr->display,
		       WMGetPixmapXID(table->viewBuffer),
		       WMColorGC(table->backColor), 0, 0,
		       W_VIEW_WIDTH(table->tableView), W_VIEW_HEIGHT(table->tableView));

	rect = getVisibleRect(table);

	if (table->drawsGrid) {
		drawGrid(table, rect);
	}

	rows = rowsInRect(table, rect);
	for (i = rows.position; i < WMIN(rows.position + rows.count + 1, table->rows); i++) {
		drawRow(table, i, rect);
	}

	XSetWindowBackgroundPixmap(scr->display, table->tableView->window, WMGetPixmapXID(table->viewBuffer));
	XClearWindow(scr->display, table->tableView->window);
}

static void stopRowEdit(WMTableView * table, int row)
{
	int i;
	WMTableColumn *column;

	table->editingRow = -1;
	for (i = 0; i < WMGetArrayItemCount(table->columns); i++) {
		column = WMGetFromArray(table->columns, i);

		if (column->delegate && column->delegate->endCellEdit)
			(*column->delegate->endCellEdit) (column->delegate, column, row);
	}
}

void WMEditTableViewRow(WMTableView * table, int row)
{
	int i;
	WMTableColumn *column;

	if (table->editingRow >= 0) {
		stopRowEdit(table, table->editingRow);
	}

	table->editingRow = row;

	if (row < 0)
		return;

	for (i = 0; i < WMGetArrayItemCount(table->columns); i++) {
		column = WMGetFromArray(table->columns, i);

		if (column->delegate && column->delegate->beginCellEdit)
			(*column->delegate->beginCellEdit) (column->delegate, column, row);
	}
}

void WMSelectTableViewRow(WMTableView * table, int row)
{
	if (table->clickedRow >= 0)
		setRowSelected(table, table->clickedRow, False);

	if (row >= table->rows) {
		return;
	}

	setRowSelected(table, row, True);
	table->clickedRow = row;

	if (table->action)
		(*table->action) (table, table->clientData);
	WMPostNotificationName(WMTableViewSelectionDidChangeNotification, table, NULL);
}

void WMReloadTableView(WMTableView * table)
{
	if (table->editingRow >= 0)
		stopRowEdit(table, table->editingRow);

	/* when this is called, nothing in the table can be assumed to be
	 * like the last time we accessed it (ie, rows might have disappeared) */

	WMEmptyArray(table->selectedRows);

	if (table->clickedRow >= 0) {
		if (table->action)
			(*table->action) (table, table->clientData);
		WMPostNotificationName(WMTableViewSelectionDidChangeNotification, table, NULL);
		table->clickedRow = -1;
	}

	if (table->delegate && table->delegate->numberOfRows) {
		int rows;

		rows = (*table->delegate->numberOfRows) (table->delegate, table);

		if (rows != table->rows) {
			table->rows = rows;
			handleResize(table->view->delegate, table->view);
		} else {
			repaintTable(table);
		}
	}
}

void WMNoteTableViewNumberOfRowsChanged(WMTableView * table)
{
	WMReloadTableView(table);
}

static void handleTableEvents(XEvent * event, void *data)
{
	WMTableView *table = (WMTableView *) data;
	int row;

	switch (event->type) {
	case ButtonPress:
		if (event->xbutton.button == Button1) {
			WMRect rect = getVisibleRect(table);

			row = (event->xbutton.y + rect.pos.y) / table->rowHeight;
			if (row != table->clickedRow) {
				setRowSelected(table, table->clickedRow, False);
				setRowSelected(table, row, True);
				table->clickedRow = row;
				table->dragging = 1;
			} else {
				table->dragging = 1;
			}
		}
		break;

	case MotionNotify:
		if (table->dragging && event->xmotion.y >= 0) {
			WMRect rect = getVisibleRect(table);

			row = (event->xmotion.y + rect.pos.y) / table->rowHeight;
			if (table->clickedRow != row && row >= 0 && row < table->rows) {
				setRowSelected(table, table->clickedRow, False);
				setRowSelected(table, row, True);
				table->clickedRow = row;
			}
		}
		break;

	case ButtonRelease:
		if (event->xbutton.button == Button1) {
			if (table->action)
				(*table->action) (table, table->clientData);
			WMPostNotificationName(WMTableViewSelectionDidChangeNotification, table, NULL);
			table->dragging = 0;
		}
		break;
	}
}

static void handleEvents(XEvent * event, void *data)
{
	WMTableView *table = (WMTableView *) data;
	WMScreen *scr = WMWidgetScreen(table);

	switch (event->type) {
	case Expose:
		W_DrawRelief(scr, W_VIEW_DRAWABLE(table->view), 0, 0,
			     W_VIEW_WIDTH(table->view), W_VIEW_HEIGHT(table->view), WRSunken);
		break;
	}
}

static void handleResize(W_ViewDelegate * self, WMView * view)
{
	reorganizeInterior(view->self);
}

static void reorganizeInterior(WMTableView * table)
{
	int width;
	int height;
	WMSize size = getTotalSize(table);
	WMView *view = table->view;
	int vw, vh;
	int hsThickness, vsThickness;

	if (table->vscroll)
		vsThickness = WMWidgetWidth(table->vscroll);
	if (table->hscroll)
		hsThickness = WMWidgetHeight(table->hscroll);

	width = W_VIEW_WIDTH(view) - 2;
	height = W_VIEW_HEIGHT(view) - 3;

	height -= table->headerHeight;	/* table header */

	if (table->corner)
		WMResizeWidget(table->corner, 20, table->headerHeight);

	WMMoveWidget(table->vscroll, 1, table->headerHeight + 1);
	WMResizeWidget(table->vscroll, 20, height + 1);

	if (table->hscroll) {
		WMMoveWidget(table->hscroll, vsThickness, W_VIEW_HEIGHT(view) - hsThickness - 1);
		WMResizeWidget(table->hscroll, width - (vsThickness + 1), hsThickness);
	}

	if (table->header)
		WMResizeWidget(table->header, width - (vsThickness + 1), table->headerHeight);

	if (table->viewBuffer) {
		WMReleasePixmap(table->viewBuffer);
		table->viewBuffer = NULL;
	}

	width -= vsThickness;
	height -= hsThickness;

	vw = WMIN(size.width, width);
	vh = WMIN(size.height, height);

	W_MoveView(table->tableView, vsThickness + 1, 1 + table->headerHeight + 1);
	W_ResizeView(table->tableView, WMAX(vw, 1), WMAX(vh, 1) + 1);

	adjustScrollers(table);

	repaintTable(table);
}

static void rearrangeHeader(WMTableView * table)
{
	int width;
	int count;
	int i;
	/*WMRect rect = WMGetScrollViewVisibleRect(table->scrollView); */

	width = 0;

	count = WMGetArrayItemCount(table->columns);
	for (i = 0; i < count; i++) {
		WMTableColumn *column = WMGetFromArray(table->columns, i);
		WMView *splitter = WMGetFromArray(table->splitters, i);

		WMMoveWidget(column->titleW, width, 0);
		WMResizeWidget(column->titleW, column->width - 1, table->headerHeight);

		width += column->width;
		W_MoveView(splitter, width - 1, 0);
	}

	wassertr(table->delegate && table->delegate->numberOfRows);

	table->rows = table->delegate->numberOfRows(table->delegate, table);

	table->tableWidth = width + 1;

	handleResize(table->view->delegate, table->view);
}
