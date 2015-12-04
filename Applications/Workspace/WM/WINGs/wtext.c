
/*  WINGs WMText: multi-line/font/color/graphic text widget,  by Nwanua. */

#include "WINGsP.h"
#include <ctype.h>
#include <X11/keysym.h>
#include <X11/Xatom.h>

#define DO_BLINK 0

/* TODO:
 * -  verify what happens with XK_return in insertTextInt...
 * -  selection code... selects can be funny if it crosses over. use rect?
 * -       also inspect behaviour for WACenter and WARight
 * -  what if a widget grabs the click... howto say: "pressed me"?
 *       note that WMCreateEventHandler takes one data, but need widget & tPtr
 * -  FIX: graphix blocks MUST be skipped if monoFont even though they exist!
 * -  check if support for Horizontal Scroll is complete
 * -  Tabs now are simply replaced by 4 spaces...
 * -  redo blink code to reduce paint event... use pixmap buffer...
 * -  add paragraph support (full) and '\n' code in getStream..
*/

/* a Section is a section of a TextBlock that describes what parts
       of a TextBlock has been laid out on which "line"...
   o  this greatly aids redraw, scroll and selection.
   o  this is created during layoutLine, but may be later modified.
   o  there may be many Sections per TextBlock, hence the array */
typedef struct {
	unsigned int x, y;	/* where to draw it from */
	unsigned short w, h;	/* its width and height  */
	unsigned short begin;	/* where the layout begins */
	unsigned short end;	/* where it ends */
	unsigned short max_d;	/* a quick hack for layOut if(laidOut) */
	unsigned short last:1;	/* is it the last section on a "line"? */
	unsigned int _y:31;	/* the "line" it and other textblocks are on */
} Section;

/* a TextBlock is a node in a doubly-linked list of TextBlocks containing:
    o text for the block, color and font
    o or a pointer to the pixmap
    o OR a pointer to the widget and the (text) description for its graphic
*/

typedef struct _TextBlock {
	struct _TextBlock *next;	/* next text block in linked list */
	struct _TextBlock *prior;	/* prior text block in linked list */

	char *text;		/* pointer to text (could be kanji) */
	/* or to the object's description */
	union {
		WMFont *font;	/* the font */
		WMWidget *widget;	/* the embedded widget */
		WMPixmap *pixmap;	/* the pixmap */
	} d;			/* description */

	unsigned short used;	/* number of chars in this block */
	unsigned short allocated;	/* size of allocation (in chars) */
	WMColor *color;		/* the color */

	Section *sections;	/* the region for layouts (a growable array) */
	/* an _array_! of size _nsections_ */

	unsigned short s_begin;	/* where the selection begins */
	unsigned short s_end;	/* where it ends */

	unsigned int first:1;	/* first TextBlock in paragraph */
	unsigned int blank:1;	/* ie. blank paragraph */
	unsigned int kanji:1;	/* is of 16-bit characters or not */
	unsigned int graphic:1;	/* graphic or text: text=0 */
	unsigned int object:1;	/* embedded object or pixmap */
	unsigned int underlined:1;	/* underlined or not */
	unsigned int selected:1;	/* selected or not */
	unsigned int nsections:8;	/* over how many "lines" a TextBlock wraps */
	int script:8;		/* script in points: negative for subscript */
	unsigned int marginN:8;	/* which of the margins in the tPtr to use */
	unsigned int nClicks:2;	/* single, double, triple clicks */
	unsigned int RESERVED:7;
} TextBlock;

/* I'm lazy: visible.h vs. visible.size.height :-) */
typedef struct {
	int y, x, h, w;
} myRect;

typedef struct W_Text {
	W_Class widgetClass;	/* the class number of this widget */
	W_View *view;		/* the view referring to this instance */

	WMRuler *ruler;		/* the ruler widget to manipulate paragraphs */

	WMScroller *vS;		/* the vertical scroller */
	unsigned int vpos;	/* the current vertical position */
	unsigned int prevVpos;	/* the previous vertical position */

	WMScroller *hS;		/* the horizontal scroller */
	unsigned int hpos;	/* the current horizontal position */
	unsigned int prevHpos;	/* the previous horizontal position */

	WMFont *dFont;		/* the default font */
	WMColor *dColor;	/* the default color */
	WMPixmap *dBulletPix;	/* the default pixmap for bullets */

	WMColor *fgColor;	/* The current foreground color */
	WMColor *bgColor;	/* The background color */

	GC stippledGC;		/* the GC to overlay selected graphics with */
	Pixmap db;		/* the buffer on which to draw */
	WMPixmap *bgPixmap;	/* the background pixmap */

	myRect visible;		/* the actual rectangle that can be drawn into */
	myRect cursor;		/* the position and (height) of cursor */
	myRect sel;		/* the selection rectangle */

	WMPoint clicked;	/* where in the _document_ was clicked */

	unsigned short tpos;	/* the position in the currentTextBlock */
	unsigned short docWidth;	/* the width of the entire document */
	unsigned int docHeight;	/* the height of the entire document */

	TextBlock *firstTextBlock;
	TextBlock *lastTextBlock;
	TextBlock *currentTextBlock;

	WMArray *gfxItems;	/* a nice array of graphic items */

#if DO_BLINK
	WMHandlerID timerID;	/* for nice twinky-winky */
#endif

	WMAction *parser;
	WMAction *writer;
	WMTextDelegate *delegate;
	Time lastClickTime;

	WMRulerMargins *margins;	/* an array of margins */

	unsigned int nMargins:7;	/* the total number of margins in use */
	struct {
		unsigned int monoFont:1;	/* whether to ignore formats and graphic  */
		unsigned int focused:1;	/* whether this instance has input focus */
		unsigned int editable:1;	/* "silly user, you can't edit me" */
		unsigned int ownsSelection:1;	/* "I ownz the current selection!" */
		unsigned int pointerGrabbed:1;	/* "heh, gib me pointer" */
		unsigned int extendSelection:1;	/* shift-drag to select more regions */

		unsigned int rulerShown:1;	/* whether the ruler is shown or not */
		unsigned int frozen:1;	/* whether screen updates are to be made */
		unsigned int cursorShown:1;	/* whether to show the cursor */
		unsigned int acceptsGraphic:1;	/* accept graphic when dropped */
		unsigned int horizOnDemand:1;	/* if a large image should appear */
		unsigned int needsLayOut:1;	/* in case of Append/Deletes */
		unsigned int ignoreNewLine:1;	/* turn it into a ' ' in streams > 1 */
		unsigned int indentNewLine:1;	/* add "    " for a newline typed */
		unsigned int laidOut:1;	/* have the TextBlocks all been laid out */
		unsigned int waitingForSelection:1;	/* I don't wanna wait in vain... */
		unsigned int prepend:1;	/* prepend=1, append=0 (for parsers) */
		WMAlignment alignment:2;	/* the alignment for text */
		WMReliefType relief:3;	/* the relief to display with */
		unsigned int isOverGraphic:2;	/* the mouse is over a graphic */
		unsigned int first:1;	/* for plain text parsing, newline? */
		/* unsigned int RESERVED:1; */
	} flags;

	WMArray *xdndSourceTypes;
	WMArray *xdndDestinationTypes;
} Text;

#define NOTIFY(T,C,N,A) {\
    WMNotification *notif = WMCreateNotification(N,T,A);\
    if ((T)->delegate && (T)->delegate->C)\
        (*(T)->delegate->C)((T)->delegate,notif);\
    WMPostNotification(notif);\
    WMReleaseNotification(notif);}

#define TYPETEXT 0

#if 0
/* just to print blocks of text not terminated by \0 */
static void output(char *ptr, int len)
{
	char *s;

	s = wmalloc(len + 1);
	memcpy(s, ptr, len);
	s[len] = 0;
	/* printf(" s is [%s] (%d)\n",  s, strlen(s)); */
	printf("[%s]\n", s);
	wfree(s);
}
#endif

#if DO_BLINK
#define CURSOR_BLINK_ON_DELAY   600
#define CURSOR_BLINK_OFF_DELAY  400
#endif

#define STIPPLE_WIDTH 8
#define STIPPLE_HEIGHT 8
static char STIPPLE_BITS[] = {
	0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa
};

static char *default_bullet[] = {
	"6 6 4 1",
	"   c None s None",
	".  c black",
	"X  c white",
	"o  c #808080",
	" ...  ",
	".XX.. ",
	".XX..o",
	".....o",
	" ...oo",
	"  ooo "
};

static void handleEvents(XEvent * event, void *data);
static void layOutDocument(Text * tPtr);
static void updateScrollers(Text * tPtr);

static int getMarginNumber(Text * tPtr, WMRulerMargins * margins)
{
	unsigned int i = 0;

	for (i = 0; i < tPtr->nMargins; i++) {

		if (WMIsMarginEqualToMargin(&tPtr->margins[i], margins))
			return i;
	}

	return -1;
}

static int newMargin(Text * tPtr, WMRulerMargins * margins)
{
	int n;

	if (!margins) {
		tPtr->margins[0].retainCount++;
		return 0;
	}

	n = getMarginNumber(tPtr, margins);

	if (n == -1) {

		if (tPtr->nMargins >= 127) {
			n = tPtr->nMargins - 1;
			return n;
		}

		tPtr->margins = wrealloc(tPtr->margins, (++tPtr->nMargins) * sizeof(WMRulerMargins));

		n = tPtr->nMargins - 1;
		tPtr->margins[n].left = margins->left;
		tPtr->margins[n].first = margins->first;
		tPtr->margins[n].body = margins->body;
		tPtr->margins[n].right = margins->right;
		/* for each tab... */
		tPtr->margins[n].retainCount = 1;
	} else {
		tPtr->margins[n].retainCount++;
	}

	return n;
}

static Bool sectionWasSelected(Text * tPtr, TextBlock * tb, XRectangle * rect, int s)
{
	unsigned short i, w, lw, selected = False, extend = False;
	myRect sel;

	/* if selection rectangle completely encloses the section */
	if ((tb->sections[s]._y >= tPtr->visible.y + tPtr->sel.y)
	    && (tb->sections[s]._y + tb->sections[s].h <= tPtr->visible.y + tPtr->sel.y + tPtr->sel.h)) {
		sel.x = 0;
		sel.w = tPtr->visible.w;
		selected = extend = True;

		/* or if it starts on a line and then goes further down */
	} else if ((tb->sections[s]._y <= tPtr->visible.y + tPtr->sel.y)
		   && (tb->sections[s]._y + tb->sections[s].h <= tPtr->visible.y + tPtr->sel.y + tPtr->sel.h)
		   && (tb->sections[s]._y + tb->sections[s].h >= tPtr->visible.y + tPtr->sel.y)) {
		sel.x = WMAX(tPtr->sel.x, tPtr->clicked.x);
		sel.w = tPtr->visible.w;
		selected = extend = True;

		/* or if it begins before a line, but ends on it */
	} else if ((tb->sections[s]._y >= tPtr->visible.y + tPtr->sel.y)
		   && (tb->sections[s]._y + tb->sections[s].h >= tPtr->visible.y + tPtr->sel.y + tPtr->sel.h)
		   && (tb->sections[s]._y <= tPtr->visible.y + tPtr->sel.y + tPtr->sel.h)) {

		if (1 || tPtr->sel.x + tPtr->sel.w > tPtr->clicked.x)
			sel.w = tPtr->sel.x + tPtr->sel.w;
		else
			sel.w = tPtr->sel.x;

		sel.x = 0;
		selected = True;

		/* or if the selection rectangle lies entirely within a line */
	} else if ((tb->sections[s]._y <= tPtr->visible.y + tPtr->sel.y)
		   && (tPtr->sel.w >= 2)
		   && (tb->sections[s]._y + tb->sections[s].h >= tPtr->visible.y + tPtr->sel.y + tPtr->sel.h)) {
		sel.x = tPtr->sel.x;
		sel.w = tPtr->sel.w;
		selected = True;
	}

	if (selected) {
		selected = False;

		/* if not within (modified) selection rectangle */
		if (tb->sections[s].x > sel.x + sel.w || tb->sections[s].x + tb->sections[s].w < sel.x)
			return False;

		if (tb->graphic) {
			if (tb->sections[s].x + tb->sections[s].w <= sel.x + sel.w && tb->sections[s].x >= sel.x) {
				rect->width = tb->sections[s].w;
				rect->x = tb->sections[s].x;
				selected = True;
			}
		} else {

			i = tb->sections[s].begin;
			lw = 0;

			if (0 && tb->sections[s].x >= sel.x) {
				tb->s_begin = tb->sections[s].begin;
				goto _selEnd;
			}

			while (++i <= tb->sections[s].end) {

				w = WMWidthOfString(tb->d.font, &(tb->text[i - 1]), 1);
				lw += w;

				if (lw + tb->sections[s].x >= sel.x || i == tb->sections[s].end) {
					lw -= w;
					i--;
					tb->s_begin = (tb->selected ? WMIN(tb->s_begin, i) : i);
					break;
				}
			}

			if (i > tb->sections[s].end) {
				printf("WasSelected: (i > tb->sections[s].end) \n");
				return False;
			}

 _selEnd:		rect->x = tb->sections[s].x + lw;
			lw = 0;
			while (++i <= tb->sections[s].end) {

				w = WMWidthOfString(tb->d.font, &(tb->text[i - 1]), 1);
				lw += w;

				if (lw + rect->x >= sel.x + sel.w || i == tb->sections[s].end) {

					if (i != tb->sections[s].end) {
						lw -= w;
						i--;
					}

					rect->width = lw;
					if (tb->sections[s].last && sel.x + sel.w
					    >= tb->sections[s].x + tb->sections[s].w && extend) {
						rect->width += (tPtr->visible.w - rect->x - lw);
					}

					tb->s_end = (tb->selected ? WMAX(tb->s_end, i) : i);
					selected = True;
					break;
				}
			}
		}
	}

	if (selected) {
		rect->y = tb->sections[s]._y - tPtr->vpos;
		rect->height = tb->sections[s].h;
		if (tb->graphic) {
			printf("DEBUG: graphic s%d h%d\n", s, tb->sections[s].h);
		}
	}
	return selected;

}

static void setSelectionProperty(WMText * tPtr, WMFont * font, WMColor * color, int underlined)
{
	TextBlock *tb;
	int isFont = False;

	tb = tPtr->firstTextBlock;
	if (!tb || !tPtr->flags.ownsSelection)
		return;

	if (font && (!color || underlined == -1))
		isFont = True;

	while (tb) {
		if (tPtr->flags.monoFont || tb->selected) {

			if (tPtr->flags.monoFont || (tb->s_end - tb->s_begin == tb->used)
			    || tb->graphic) {

				if (isFont) {
					if (!tb->graphic) {
						WMReleaseFont(tb->d.font);
						tb->d.font = WMRetainFont(font);
					}
				} else if (underlined != -1) {
					tb->underlined = underlined;
				} else {
					WMReleaseColor(tb->color);
					tb->color = WMRetainColor(color);
				}

			} else if (tb->s_end <= tb->used && tb->s_begin < tb->s_end) {

				TextBlock *midtb, *otb = tb;

				if (underlined != -1) {
					midtb = (TextBlock *) WMCreateTextBlockWithText(tPtr,
											&(tb->text[tb->s_begin]),
											tb->d.font, tb->color,
											False,
											(tb->s_end - tb->s_begin));
				} else {
					midtb = (TextBlock *) WMCreateTextBlockWithText(tPtr,
											&(tb->text[tb->s_begin]),
											(isFont ? font : tb->d.
											 font),
											(isFont ? tb->
											 color : color), False,
											(tb->s_end - tb->s_begin));
				}

				if (midtb) {
					if (underlined != -1) {
						midtb->underlined = underlined;
					} else {
						midtb->underlined = otb->underlined;
					}

					midtb->selected = !True;
					midtb->s_begin = 0;
					midtb->s_end = midtb->used;
					tPtr->currentTextBlock = tb;
					WMAppendTextBlock(tPtr, midtb);
					tb = tPtr->currentTextBlock;
				}

				if (otb->used - otb->s_end > 0) {
					TextBlock *ntb;
					ntb = (TextBlock *)
					    WMCreateTextBlockWithText(tPtr,
								      &(otb->text[otb->s_end]), otb->d.font,
								      otb->color, False, otb->used - otb->s_end);

					if (ntb) {
						ntb->underlined = otb->underlined;
						ntb->selected = False;
						WMAppendTextBlock(tPtr, ntb);
						tb = tPtr->currentTextBlock;
					}
				}

				if (midtb) {
					tPtr->currentTextBlock = midtb;
				}

				otb->selected = False;
				otb->used = otb->s_begin;
			}
		}

		tb = tb->next;
	}

	tPtr->flags.needsLayOut = True;
	WMThawText(tPtr);

	/* in case the size changed... */
	if (isFont && tPtr->currentTextBlock) {
		TextBlock *tb = tPtr->currentTextBlock;

		printf("%d %d %d\n", tPtr->sel.y, tPtr->sel.h, tPtr->sel.w);
		tPtr->sel.y = 3 + tb->sections[0]._y;
		tPtr->sel.h = tb->sections[tb->nsections - 1]._y - tb->sections[0]._y;
		tPtr->sel.w = tb->sections[tb->nsections - 1].w;
		if (tb->sections[tb->nsections - 1]._y != tb->sections[0]._y) {
			tPtr->sel.x = 0;
		}
		printf("%d %d %d\n\n\n", tPtr->sel.y, tPtr->sel.h, tPtr->sel.w);
	}

}

static Bool removeSelection(Text * tPtr)
{
	TextBlock *tb = NULL;
	Bool first = False;

	if (!(tb = tPtr->firstTextBlock))
		return False;

	while (tb) {
		if (tb->selected) {
			if (!first && !tb->graphic) {
				WMReleaseFont(tPtr->dFont);
				tPtr->dFont = WMRetainFont(tb->d.font);
				first = True;
			}

			if ((tb->s_end - tb->s_begin == tb->used) || tb->graphic) {
				tPtr->currentTextBlock = tb;
				if (tb->next) {
					tPtr->tpos = 0;
				} else if (tb->prior) {
					if (tb->prior->graphic)
						tPtr->tpos = 1;
					else
						tPtr->tpos = tb->prior->used;
				} else
					tPtr->tpos = 0;

				WMDestroyTextBlock(tPtr, WMRemoveTextBlock(tPtr));
				tb = tPtr->currentTextBlock;
				continue;

			} else if (tb->s_end <= tb->used) {
				memmove(&(tb->text[tb->s_begin]), &(tb->text[tb->s_end]), tb->used - tb->s_end);
				tb->used -= (tb->s_end - tb->s_begin);
				tb->selected = False;
				tPtr->tpos = tb->s_begin;
			}

		}

		tb = tb->next;
	}
	return True;
}

static TextBlock *getFirstNonGraphicBlockFor(TextBlock * tb, short dir)
{
	TextBlock *hold = tb;

	if (!tb)
		return NULL;

	while (tb) {
		if (!tb->graphic)
			break;
		tb = (dir ? tb->next : tb->prior);
	}

	if (!tb) {
		tb = hold;
		while (tb) {
			if (!tb->graphic)
				break;
			tb = (dir ? tb->prior : tb->next);
		}
	}

	if (!tb)
		return NULL;

	return tb;
}

static Bool updateStartForCurrentTextBlock(Text * tPtr, int x, int y, int *dir, TextBlock * tb)
{
	if (tPtr->flags.monoFont && tb->graphic) {
		tb = getFirstNonGraphicBlockFor(tb, *dir);
		if (!tb)
			return 0;

		if (tb->graphic) {
			tPtr->currentTextBlock = (*dir ? tPtr->lastTextBlock : tPtr->firstTextBlock);
			tPtr->tpos = 0;
			return 0;
		}
	}

	if (!tb->sections) {
		layOutDocument(tPtr);
		return 0;
	}

	*dir = !(y <= tb->sections[0].y);
	if (*dir) {
		if ((y <= tb->sections[0]._y + tb->sections[0].h)
		    && (y >= tb->sections[0]._y)) {
			/* if it's on the same line */
			if (x < tb->sections[0].x)
				*dir = 0;
		}
	} else {
		if ((y <= tb->sections[tb->nsections - 1]._y + tb->sections[tb->nsections - 1].h)
		    && (y >= tb->sections[tb->nsections - 1]._y)) {
			/* if it's on the same line */
			if (x > tb->sections[tb->nsections - 1].x)
				*dir = 1;
		}
	}

	return 1;
}

static void paintText(Text * tPtr)
{
	TextBlock *tb;
	WMFont *font;
	const char *text;
	int len, y, c, s, done = False, dir /* 1 = down */ ;
	WMScreen *scr = tPtr->view->screen;
	Display *dpy = tPtr->view->screen->display;
	Window win = tPtr->view->window;
	WMColor *color;

	if (!tPtr->view->flags.realized || !tPtr->db || tPtr->flags.frozen)
		return;

	XFillRectangle(dpy, tPtr->db, WMColorGC(tPtr->bgColor), 0, 0, tPtr->visible.w, tPtr->visible.h);

	if (tPtr->bgPixmap) {
		WMDrawPixmap(tPtr->bgPixmap, tPtr->db,
			     (tPtr->visible.w - tPtr->visible.x - tPtr->bgPixmap->width) / 2,
			     (tPtr->visible.h - tPtr->visible.y - tPtr->bgPixmap->height) / 2);
	}

	if (!(tb = tPtr->currentTextBlock)) {
		if (!(tb = tPtr->firstTextBlock)) {
			goto _copy_area;
		}
	}

	done = False;

	/* first, which direction? Don't waste time looking all over,
	   since the parts to be drawn will most likely be near what
	   was previously drawn */
	if (!updateStartForCurrentTextBlock(tPtr, 0, tPtr->vpos, &dir, tb))
		goto _copy_area;

	while (tb) {

		if (tb->graphic && tPtr->flags.monoFont)
			goto _getSibling;

		if (dir) {
			if (tPtr->vpos <= tb->sections[tb->nsections - 1]._y + tb->sections[tb->nsections - 1].h)
				break;
		} else {
			if (tPtr->vpos >= tb->sections[tb->nsections - 1]._y + tb->sections[tb->nsections - 1].h)
				break;
		}

 _getSibling:
		if (dir) {
			if (tb->next)
				tb = tb->next;
			else
				break;
		} else {
			if (tb->prior)
				tb = tb->prior;
			else
				break;
		}
	}

	/* first, place all text that can be viewed */
	while (!done && tb) {
		if (tb->graphic) {
			tb = tb->next;
			continue;
		}

		tb->selected = False;

		for (s = 0; s < tb->nsections && !done; s++) {

			if (tb->sections[s]._y > tPtr->vpos + tPtr->visible.h) {
				done = True;
				break;
			}

			if (tb->sections[s].y + tb->sections[s].h < tPtr->vpos)
				continue;

			if (tPtr->flags.monoFont) {
				font = tPtr->dFont;
				color = tPtr->fgColor;
			} else {
				font = tb->d.font;
				color = tb->color;
			}

			if (tPtr->flags.ownsSelection) {
				XRectangle rect;

				if (sectionWasSelected(tPtr, tb, &rect, s)) {
					tb->selected = True;
					XFillRectangle(dpy, tPtr->db, WMColorGC(scr->gray),
						       rect.x, rect.y, rect.width, rect.height);
				}
			}

			len = tb->sections[s].end - tb->sections[s].begin;
			text = &(tb->text[tb->sections[s].begin]);
			y = tb->sections[s].y - tPtr->vpos;
			WMDrawString(scr, tPtr->db, color, font, tb->sections[s].x - tPtr->hpos, y, text, len);

			if (!tPtr->flags.monoFont && tb->underlined) {
				XDrawLine(dpy, tPtr->db, WMColorGC(color),
					  tb->sections[s].x - tPtr->hpos,
					  y + font->y + 1,
					  tb->sections[s].x + tb->sections[s].w - tPtr->hpos, y + font->y + 1);
			}
		}
		tb = (!done ? tb->next : NULL);
	}

	/* now , show all graphic items that can be viewed */
	c = WMGetArrayItemCount(tPtr->gfxItems);
	if (c > 0 && !tPtr->flags.monoFont) {
		int j, h;

		for (j = 0; j < c; j++) {
			tb = (TextBlock *) WMGetFromArray(tPtr->gfxItems, j);

			/* if it's not viewable, and mapped, unmap it */
			if (tb->sections[0]._y + tb->sections[0].h <= tPtr->vpos
			    || tb->sections[0]._y >= tPtr->vpos + tPtr->visible.h) {

				if (tb->object) {
					if ((W_VIEW(tb->d.widget))->flags.mapped) {
						WMUnmapWidget(tb->d.widget);
					}
				}
			} else {
				/* if it's viewable, and not mapped, map it */
				if (tb->object) {
					W_View *view = W_VIEW(tb->d.widget);

					if (!view->flags.realized)
						WMRealizeWidget(tb->d.widget);
					if (!view->flags.mapped) {
						XMapWindow(view->screen->display, view->window);
						XFlush(view->screen->display);
						view->flags.mapped = 1;
					}
				}

				if (tb->object) {
					WMMoveWidget(tb->d.widget,
						     tb->sections[0].x + tPtr->visible.x - tPtr->hpos,
						     tb->sections[0].y + tPtr->visible.y - tPtr->vpos);
					h = WMWidgetHeight(tb->d.widget) + 1;

				} else {
					WMDrawPixmap(tb->d.pixmap, tPtr->db,
						     tb->sections[0].x - tPtr->hpos,
						     tb->sections[0].y - tPtr->vpos);
					h = tb->d.pixmap->height + 1;

				}

				if (tPtr->flags.ownsSelection) {
					XRectangle rect;

					if (sectionWasSelected(tPtr, tb, &rect, 0)) {
						Drawable d = (0 && tb->object ?
							      (WMWidgetView(tb->d.widget))->window : tPtr->db);

						tb->selected = True;
						XFillRectangle(dpy, d, tPtr->stippledGC,
							       /*XFillRectangle(dpy, tPtr->db, tPtr->stippledGC, */
							       rect.x, rect.y, rect.width, rect.height);
					}
				}

				if (!tPtr->flags.monoFont && tb->underlined) {
					XDrawLine(dpy, tPtr->db, WMColorGC(tb->color),
						  tb->sections[0].x - tPtr->hpos,
						  tb->sections[0].y + h - tPtr->vpos,
						  tb->sections[0].x + tb->sections[0].w - tPtr->hpos,
						  tb->sections[0].y + h - tPtr->vpos);
				}
			}
		}
	}

 _copy_area:
	if (tPtr->flags.editable && tPtr->flags.cursorShown && tPtr->cursor.x != -23 && tPtr->flags.focused) {
		int y = tPtr->cursor.y - tPtr->vpos;
		XDrawLine(dpy, tPtr->db, WMColorGC(tPtr->fgColor),
			  tPtr->cursor.x, y, tPtr->cursor.x, y + tPtr->cursor.h);
	}

	XCopyArea(dpy, tPtr->db, win, WMColorGC(tPtr->bgColor), 0, 0,
		  tPtr->visible.w, tPtr->visible.h, tPtr->visible.x, tPtr->visible.y);

	W_DrawRelief(scr, win, 0, 0, tPtr->view->size.width, tPtr->view->size.height, tPtr->flags.relief);

	if (tPtr->ruler && tPtr->flags.rulerShown)
		XDrawLine(dpy, win, WMColorGC(tPtr->fgColor), 2, 42, tPtr->view->size.width - 4, 42);

}

static void mouseOverObject(Text * tPtr, int x, int y)
{
	TextBlock *tb;
	Bool result = False;

	x -= tPtr->visible.x;
	x += tPtr->hpos;
	y -= tPtr->visible.y;
	y += tPtr->vpos;

	if (tPtr->flags.ownsSelection) {
		if (tPtr->sel.x <= x
		    && tPtr->sel.y <= y && tPtr->sel.x + tPtr->sel.w >= x && tPtr->sel.y + tPtr->sel.h >= y) {
			tPtr->flags.isOverGraphic = 1;
			result = True;
		}
	}

	if (!result) {
		int j, c = WMGetArrayItemCount(tPtr->gfxItems);

		if (c < 1)
			tPtr->flags.isOverGraphic = 0;

		for (j = 0; j < c; j++) {
			tb = (TextBlock *) WMGetFromArray(tPtr->gfxItems, j);

			if (!tb || !tb->sections) {
				tPtr->flags.isOverGraphic = 0;
				return;
			}

			if (!tb->object) {
				if (tb->sections[0].x <= x
				    && tb->sections[0].y <= y
				    && tb->sections[0].x + tb->sections[0].w >= x
				    && tb->sections[0].y + tb->d.pixmap->height >= y) {
					tPtr->flags.isOverGraphic = 3;
					result = True;
					break;
				}
			}
		}

	}

	if (!result)
		tPtr->flags.isOverGraphic = 0;

	tPtr->view->attribs.cursor = (result ? tPtr->view->screen->defaultCursor : tPtr->view->screen->textCursor);
	{
		XSetWindowAttributes attribs;
		attribs.cursor = tPtr->view->attribs.cursor;
		XChangeWindowAttributes(tPtr->view->screen->display, tPtr->view->window, CWCursor, &attribs);
	}
}

#if DO_BLINK

static void blinkCursor(void *data)
{
	Text *tPtr = (Text *) data;

	if (tPtr->flags.cursorShown) {
		tPtr->timerID = WMAddTimerHandler(CURSOR_BLINK_OFF_DELAY, blinkCursor, data);
	} else {
		tPtr->timerID = WMAddTimerHandler(CURSOR_BLINK_ON_DELAY, blinkCursor, data);
	}
	paintText(tPtr);
	tPtr->flags.cursorShown = !tPtr->flags.cursorShown;
}
#endif

static void updateCursorPosition(Text * tPtr)
{
	TextBlock *tb = NULL;
	int x, y, h, s;

	if (tPtr->flags.needsLayOut)
		layOutDocument(tPtr);

	if (!(tb = tPtr->currentTextBlock)) {
		if (!(tb = tPtr->firstTextBlock)) {
			WMFont *font = tPtr->dFont;
			tPtr->tpos = 0;
			tPtr->cursor.h = font->height + abs(font->height - font->y);

			tPtr->cursor.y = 2;
			tPtr->cursor.x = 2;
			return;
		}
	}

	if (tb->blank) {
		tPtr->tpos = 0;
		y = tb->sections[0].y;
		h = tb->sections[0].h;
		x = tb->sections[0].x;

	} else if (tb->graphic) {
		y = tb->sections[0].y;
		h = tb->sections[0].h;
		x = tb->sections[0].x;
		if (tPtr->tpos == 1)
			x += tb->sections[0].w;

	} else {
		if (tPtr->tpos > tb->used)
			tPtr->tpos = tb->used;

		for (s = 0; s < tb->nsections - 1; s++) {

			if (tPtr->tpos >= tb->sections[s].begin && tPtr->tpos <= tb->sections[s].end)
				break;
		}

		y = tb->sections[s]._y;
		h = tb->sections[s].h;
		x = tb->sections[s].x + WMWidthOfString((tPtr->flags.monoFont ? tPtr->dFont : tb->d.font),
							&tb->text[tb->sections[s].begin],
							tPtr->tpos - tb->sections[s].begin);
	}

	tPtr->cursor.y = y;
	tPtr->cursor.h = h;
	tPtr->cursor.x = x;

	/* scroll the bars if the cursor is not visible */
	if (tPtr->flags.editable && tPtr->cursor.x != -23) {
		if (tPtr->cursor.y + tPtr->cursor.h > tPtr->vpos + tPtr->visible.y + tPtr->visible.h) {
			tPtr->vpos +=
			    (tPtr->cursor.y + tPtr->cursor.h + 10
			     - (tPtr->vpos + tPtr->visible.y + tPtr->visible.h));
		} else if (tPtr->cursor.y < tPtr->vpos + tPtr->visible.y) {
			tPtr->vpos -= (tPtr->vpos + tPtr->visible.y - tPtr->cursor.y);
		}

	}

	updateScrollers(tPtr);
}

static void cursorToTextPosition(Text * tPtr, int x, int y)
{
	TextBlock *tb = NULL;
	int done = False, s, pos, len, _w, _y, dir = 1;	/* 1 == "down" */
	const char *text;

	if (tPtr->flags.needsLayOut)
		layOutDocument(tPtr);

	y += (tPtr->vpos - tPtr->visible.y);
	if (y < 0)
		y = 0;

	x -= (tPtr->visible.x - 2);
	if (x < 0)
		x = 0;

	/* clicked is relative to document, not window... */
	tPtr->clicked.x = x;
	tPtr->clicked.y = y;

	if (!(tb = tPtr->currentTextBlock)) {
		if (!(tb = tPtr->firstTextBlock)) {
			WMFont *font = tPtr->dFont;
			tPtr->tpos = 0;
			tPtr->cursor.h = font->height + abs(font->height - font->y);
			tPtr->cursor.y = 2;
			tPtr->cursor.x = 2;
			return;
		}
	}

	/* first, which direction? Most likely, newly clicked
	   position will be close to previous */
	if (!updateStartForCurrentTextBlock(tPtr, x, y, &dir, tb))
		return;

	s = (dir ? 0 : tb->nsections - 1);
	if (y >= tb->sections[s]._y && y <= tb->sections[s]._y + tb->sections[s].h) {
		goto _doneV;
	}

	/* get the first (or last) section of the TextBlock that
	   lies about the vertical click point */
	done = False;
	while (!done && tb) {

		if (tPtr->flags.monoFont && tb->graphic) {
			if ((dir ? tb->next : tb->prior))
				tb = (dir ? tb->next : tb->prior);
			continue;
		}

		s = (dir ? 0 : tb->nsections - 1);
		while (!done && (dir ? (s < tb->nsections) : (s >= 0))) {

			if ((dir ? (y <= tb->sections[s]._y + tb->sections[s].h) : (y >= tb->sections[s]._y))) {
				done = True;
			} else {
				dir ? s++ : s--;
			}
		}

		if (!done) {
			if ((dir ? tb->next : tb->prior)) {
				tb = (dir ? tb->next : tb->prior);
			} else {
				break;	/* goto _doneH; */
			}
		}
	}

	if (s < 0 || s >= tb->nsections) {
		s = (dir ? tb->nsections - 1 : 0);
	}

 _doneV:
	/* we have the line, which TextBlock on that line is it? */
	pos = (dir ? 0 : tb->sections[s].begin);
	if (tPtr->flags.monoFont && tb->graphic) {
		TextBlock *hold = tb;
		tb = getFirstNonGraphicBlockFor(hold, dir);

		if (!tb) {
			tPtr->tpos = 0;
			tb = hold;
			s = 0;
			goto _doNothing;
		}
	}

	_y = tb->sections[s]._y;

	while (tb) {

		if (tPtr->flags.monoFont && tb->graphic) {
			tb = (dir ? tb->next : tb->prior);
			continue;
		}

		if (dir) {
			if (tb->graphic) {
				if (tb->object)
					_w = WMWidgetWidth(tb->d.widget) - 5;
				else
					_w = tb->d.pixmap->width - 5;

				if (tb->sections[0].x + _w >= x)
					break;
			} else {
				text = &(tb->text[tb->sections[s].begin]);
				len = tb->sections[s].end - tb->sections[s].begin;
				_w = WMWidthOfString(tb->d.font, text, len);
				if (tb->sections[s].x + _w >= x)
					break;

			}
		} else {
			if (tb->sections[s].x <= x)
				break;
		}

		if ((dir ? tb->next : tb->prior)) {
			TextBlock *nxt = (dir ? tb->next : tb->prior);
			if (tPtr->flags.monoFont && nxt->graphic) {
				nxt = getFirstNonGraphicBlockFor(nxt, dir);
				if (!nxt) {
					pos = (dir ? 0 : tb->sections[s].begin);
					tPtr->cursor.x = tb->sections[s].x;
					goto _doneH;
				}
			}

			if (_y != nxt->sections[dir ? 0 : nxt->nsections - 1]._y) {
				/* this must be the last/first on this line. stop */
				pos = (dir ? tb->sections[s].end : 0);
				tPtr->cursor.x = tb->sections[s].x;
				if (!tb->blank) {
					if (tb->graphic) {
						if (tb->object)
							tPtr->cursor.x += WMWidgetWidth(tb->d.widget);
						else
							tPtr->cursor.x += tb->d.pixmap->width;
					} else if (pos > tb->sections[s].begin) {
						tPtr->cursor.x +=
						    WMWidthOfString(tb->d.font,
								    &(tb->text[tb->sections[s].begin]),
								    pos - tb->sections[s].begin);
					}
				}
				goto _doneH;
			}
		}

		if ((dir ? tb->next : tb->prior)) {
			tb = (dir ? tb->next : tb->prior);
		} else {
			break;
		}

		if (tb)
			s = (dir ? 0 : tb->nsections - 1);
	}

	/* we have said TextBlock, now where within it? */
	if (tb) {
		if (tb->graphic) {
			int gw = (tb->object ? WMWidgetWidth(tb->d.widget) : tb->d.pixmap->width);

			tPtr->cursor.x = tb->sections[0].x;

			if (x > tPtr->cursor.x + gw / 2) {
				pos = 1;
				tPtr->cursor.x += gw;
			} else {
				printf("first %d\n", tb->first);
				if (tb->prior) {
					if (tb->prior->graphic)
						pos = 1;
					else
						pos = tb->prior->used;
					tb = tb->prior;
				} else
					pos = 0;

			}

			s = 0;
			goto _doneH;

		} else {
			WMFont *f = tb->d.font;
			len = tb->sections[s].end - tb->sections[s].begin;
			text = &(tb->text[tb->sections[s].begin]);

			_w = x - tb->sections[s].x;
			pos = 0;

			while (pos < len && WMWidthOfString(f, text, pos + 1) < _w)
				pos++;

			tPtr->cursor.x = tb->sections[s].x + (pos ? WMWidthOfString(f, text, pos) : 0);

			pos += tb->sections[s].begin;
		}
	}

 _doneH:
	if (tb->graphic) {
		tPtr->tpos = (pos <= 1) ? pos : 0;
	} else {
		tPtr->tpos = (pos < tb->used) ? pos : tb->used;
	}
 _doNothing:
	if (!tb)
		printf("...for this app will surely crash :-)\n");

	tPtr->currentTextBlock = tb;
	tPtr->cursor.h = tb->sections[s].h;
	tPtr->cursor.y = tb->sections[s]._y;

	/* scroll the bars if the cursor is not visible */
	if (tPtr->flags.editable && tPtr->cursor.x != -23) {
		if (tPtr->cursor.y + tPtr->cursor.h > tPtr->vpos + tPtr->visible.y + tPtr->visible.h) {
			tPtr->vpos +=
			    (tPtr->cursor.y + tPtr->cursor.h + 10
			     - (tPtr->vpos + tPtr->visible.y + tPtr->visible.h));
			updateScrollers(tPtr);
		} else if (tPtr->cursor.y < tPtr->vpos + tPtr->visible.y) {
			tPtr->vpos -= (tPtr->vpos + tPtr->visible.y - tPtr->cursor.y);
			updateScrollers(tPtr);
		}

	}

}

static void updateScrollers(Text * tPtr)
{

	if (tPtr->flags.frozen)
		return;

	if (tPtr->vS) {
		if (tPtr->docHeight <= tPtr->visible.h) {
			WMSetScrollerParameters(tPtr->vS, 0, 1);
			tPtr->vpos = 0;
		} else {
			float hmax = (float)(tPtr->docHeight);
			WMSetScrollerParameters(tPtr->vS,
						((float)tPtr->vpos) / (hmax - (float)tPtr->visible.h),
						(float)tPtr->visible.h / hmax);
		}
	} else
		tPtr->vpos = 0;

	if (tPtr->hS) {
		if (tPtr->docWidth <= tPtr->visible.w) {
			WMSetScrollerParameters(tPtr->hS, 0, 1);
			tPtr->hpos = 0;
		} else {
			float wmax = (float)(tPtr->docWidth);
			WMSetScrollerParameters(tPtr->hS,
						((float)tPtr->hpos) / (wmax - (float)tPtr->visible.w),
						(float)tPtr->visible.w / wmax);
		}
	} else
		tPtr->hpos = 0;
}

static void scrollersCallBack(WMWidget * w, void *self)
{
	Text *tPtr = (Text *) self;
	Bool scroll = False;
	int which;

	if (!tPtr->view->flags.realized || tPtr->flags.frozen)
		return;

	if (w == tPtr->vS) {
		int height;
		height = tPtr->visible.h;

		which = WMGetScrollerHitPart(tPtr->vS);
		switch (which) {

		case WSDecrementLine:
			if (tPtr->vpos > 0) {
				if (tPtr->vpos > 16)
					tPtr->vpos -= 16;
				else
					tPtr->vpos = 0;
			}
			break;

		case WSIncrementLine:{
				int limit = tPtr->docHeight - height;
				if (tPtr->vpos < limit) {
					if (tPtr->vpos < limit - 16)
						tPtr->vpos += 16;
					else
						tPtr->vpos = limit;
				}
			}
			break;

		case WSDecrementPage:
			if (((int)tPtr->vpos - (int)height) >= 0)
				tPtr->vpos -= height;
			else
				tPtr->vpos = 0;
			break;

		case WSIncrementPage:
			tPtr->vpos += height;
			if (tPtr->vpos > (tPtr->docHeight - height))
				tPtr->vpos = tPtr->docHeight - height;
			break;

		case WSKnob:
			tPtr->vpos = WMGetScrollerValue(tPtr->vS)
			    * (float)(tPtr->docHeight - height);
			break;

		case WSKnobSlot:
		case WSNoPart:
			break;
		}
		scroll = (tPtr->vpos != tPtr->prevVpos);
		tPtr->prevVpos = tPtr->vpos;
	}

	if (w == tPtr->hS) {
		int width = tPtr->visible.w;

		which = WMGetScrollerHitPart(tPtr->hS);
		switch (which) {

		case WSDecrementLine:
			if (tPtr->hpos > 0) {
				if (tPtr->hpos > 16)
					tPtr->hpos -= 16;
				else
					tPtr->hpos = 0;
			}
			break;

		case WSIncrementLine:{
				int limit = tPtr->docWidth - width;
				if (tPtr->hpos < limit) {
					if (tPtr->hpos < limit - 16)
						tPtr->hpos += 16;
					else
						tPtr->hpos = limit;
				}
			}
			break;

		case WSDecrementPage:
			if (((int)tPtr->hpos - (int)width) >= 0)
				tPtr->hpos -= width;
			else
				tPtr->hpos = 0;
			break;

		case WSIncrementPage:
			tPtr->hpos += width;
			if (tPtr->hpos > (tPtr->docWidth - width))
				tPtr->hpos = tPtr->docWidth - width;
			break;

		case WSKnob:
			tPtr->hpos = WMGetScrollerValue(tPtr->hS)
			    * (float)(tPtr->docWidth - width);
			break;

		case WSKnobSlot:
		case WSNoPart:
			break;
		}
		scroll = (tPtr->hpos != tPtr->prevHpos);
		tPtr->prevHpos = tPtr->hpos;
	}

	if (scroll) {
		updateScrollers(tPtr);
		paintText(tPtr);
	}
}

typedef struct {
	TextBlock *tb;
	unsigned short begin, end;	/* what part of the text block */
} myLineItems;

static int layOutLine(Text * tPtr, myLineItems * items, int nitems, int x, int y)
{
	int i, j = 0, lw = 0, line_height = 0, max_d = 0, len, n;
	WMFont *font;
	const char *text;
	TextBlock *tb, *tbsame = NULL;

	if (!items || nitems == 0)
		return 0;

	for (i = 0; i < nitems; i++) {
		tb = items[i].tb;

		if (tb->graphic) {
			if (!tPtr->flags.monoFont) {
				if (tb->object) {
					WMWidget *wdt = tb->d.widget;
					line_height = WMAX(line_height, WMWidgetHeight(wdt));
					if (tPtr->flags.alignment != WALeft)
						lw += WMWidgetWidth(wdt);
				} else {
					line_height = WMAX(line_height, tb->d.pixmap->height + max_d);
					if (tPtr->flags.alignment != WALeft)
						lw += tb->d.pixmap->width;
				}
			}

		} else {
			font = (tPtr->flags.monoFont) ? tPtr->dFont : tb->d.font;
			/*max_d = WMAX(max_d, abs(font->height-font->y)); */
			max_d = 2;
			line_height = WMAX(line_height, font->height + max_d);
			text = &(tb->text[items[i].begin]);
			len = items[i].end - items[i].begin;
			if (tPtr->flags.alignment != WALeft)
				lw += WMWidthOfString(font, text, len);
		}
	}

	if (tPtr->flags.alignment == WARight) {
		j = tPtr->visible.w - lw;
	} else if (tPtr->flags.alignment == WACenter) {
		j = (int)((float)(tPtr->visible.w - lw)) / 2.0;
	}

	for (i = 0; i < nitems; i++) {
		tb = items[i].tb;

		if (tbsame == tb) {	/* extend it, since it's on same line */
			tb->sections[tb->nsections - 1].end = items[i].end;
			n = tb->nsections - 1;
		} else {
			tb->sections = wrealloc(tb->sections, (++tb->nsections) * sizeof(Section));
			n = tb->nsections - 1;
			tb->sections[n]._y = y + max_d;
			tb->sections[n].max_d = max_d;
			tb->sections[n].x = x + j;
			tb->sections[n].h = line_height;
			tb->sections[n].begin = items[i].begin;
			tb->sections[n].end = items[i].end;
		}

		tb->sections[n].last = (i + 1 == nitems);

		if (tb->graphic) {
			if (!tPtr->flags.monoFont) {
				if (tb->object) {
					WMWidget *wdt = tb->d.widget;
					tb->sections[n].y = max_d + y + line_height - WMWidgetHeight(wdt);
					tb->sections[n].w = WMWidgetWidth(wdt);
				} else {
					tb->sections[n].y = y + line_height + max_d - tb->d.pixmap->height;
					tb->sections[n].w = tb->d.pixmap->width;
				}
				x += tb->sections[n].w;
			}
		} else {
			font = (tPtr->flags.monoFont) ? tPtr->dFont : tb->d.font;
			len = items[i].end - items[i].begin;
			text = &(tb->text[items[i].begin]);

			tb->sections[n].y = y + line_height - font->y;
			tb->sections[n].w =
			    WMWidthOfString(font,
					    &(tb->text[tb->sections[n].begin]),
					    tb->sections[n].end - tb->sections[n].begin);

			x += WMWidthOfString(font, text, len);
		}

		tbsame = tb;
	}

	return line_height;

}

static void layOutDocument(Text * tPtr)
{
	TextBlock *tb;
	myLineItems *items = NULL;
	unsigned int itemsSize = 0, nitems = 0, begin, end;
	WMFont *font;
	unsigned int x, y = 0, lw = 0, width = 0, bmargin;
	const char *start = NULL, *mark = NULL;

	if (tPtr->flags.frozen || (!(tb = tPtr->firstTextBlock)))
		return;

	assert(tPtr->visible.w > 20);

	tPtr->docWidth = tPtr->visible.w;
	x = tPtr->margins[tb->marginN].first;
	bmargin = tPtr->margins[tb->marginN].body;

	/* only partial layOut needed: re-Lay only affected textblocks  */
	if (tPtr->flags.laidOut) {
		tb = tPtr->currentTextBlock;

		/* search backwards for textblocks on same line */
		while (tb->prior) {
			if (!tb->sections || tb->nsections < 1) {
				tb = tPtr->firstTextBlock;
				tPtr->flags.laidOut = False;
				y = 0;
				goto _layOut;
			}

			if (!tb->prior->sections || tb->prior->nsections < 1) {
				tb = tPtr->firstTextBlock;
				tPtr->flags.laidOut = False;
				y = 0;
				goto _layOut;
			}

			if (tb->sections[0]._y != tb->prior->sections[tb->prior->nsections - 1]._y) {
				break;
			}
			tb = tb->prior;
		}

		if (tb->prior && tb->prior->sections && tb->prior->nsections > 0) {
			y = tb->prior->sections[tb->prior->nsections - 1]._y +
			    tb->prior->sections[tb->prior->nsections - 1].h -
			    tb->prior->sections[tb->prior->nsections - 1].max_d;
		} else {
			y = 0;
		}
	}

 _layOut:
	while (tb) {

		if (tb->sections && tb->nsections > 0) {
			wfree(tb->sections);
			tb->sections = NULL;
			tb->nsections = 0;
		}

		if (tb->first && tb->blank && tb->next && !tb->next->first) {
			TextBlock *next = tb->next;
			tPtr->currentTextBlock = tb;
			WMDestroyTextBlock(tPtr, WMRemoveTextBlock(tPtr));
			tb = next;
			tb->first = True;
			continue;
		}

		if (tb->first && tb != tPtr->firstTextBlock) {
			y += layOutLine(tPtr, items, nitems, x, y);
			x = tPtr->margins[tb->marginN].first;
			bmargin = tPtr->margins[tb->marginN].body;
			nitems = 0;
			lw = 0;
		}

		if (tb->graphic) {
			if (!tPtr->flags.monoFont) {
				if (tb->object)
					width = WMWidgetWidth(tb->d.widget);
				else
					width = tb->d.pixmap->width;

				if (width > tPtr->docWidth)
					tPtr->docWidth = width;

				lw += width;
				if (lw >= tPtr->visible.w - x) {
					y += layOutLine(tPtr, items, nitems, x, y);
					nitems = 0;
					x = bmargin;
					lw = width;
				}

				if (nitems + 1 > itemsSize) {
					items = wrealloc(items, (++itemsSize) * sizeof(myLineItems));
				}

				items[nitems].tb = tb;
				items[nitems].begin = 0;
				items[nitems].end = 0;
				nitems++;
			}

		} else if ((start = tb->text)) {
			begin = end = 0;
			font = tPtr->flags.monoFont ? tPtr->dFont : tb->d.font;

			while (start) {
				mark = strchr(start, ' ');
				if (mark) {
					end += (int)(mark - start) + 1;
					start = mark + 1;
				} else {
					end += strlen(start);
					start = mark;
				}

				if (end > tb->used)
					end = tb->used;

				if (end - begin > 0) {

					width = WMWidthOfString(font, &tb->text[begin], end - begin);

					/* if it won't fit, char wrap it */
					if (width >= tPtr->visible.w) {
						char *t = &tb->text[begin];
						int l = end - begin, i = 0;
						do {
							width = WMWidthOfString(font, t, ++i);
						} while (width < tPtr->visible.w && i < l);
						if (i > 2)
							i--;
						end = begin + i;
						start = &tb->text[end];
					}

					lw += width;
				}

				if (lw >= tPtr->visible.w - x) {
					y += layOutLine(tPtr, items, nitems, x, y);
					lw = width;
					x = bmargin;
					nitems = 0;
				}

				if (nitems + 1 > itemsSize) {
					items = wrealloc(items, (++itemsSize) * sizeof(myLineItems));
				}

				items[nitems].tb = tb;
				items[nitems].begin = begin;
				items[nitems].end = end;
				nitems++;

				begin = end;
			}
		}

		/* not yet fully ready. but is already VERY FAST for a 3Mbyte file ;-) */
		if (0 && tPtr->flags.laidOut
		    && tb->next && tb->next->sections && tb->next->nsections > 0
		    && (tPtr->vpos + tPtr->visible.h < tb->next->sections[0]._y)) {
			if (tPtr->lastTextBlock->sections && tPtr->lastTextBlock->nsections > 0) {
				TextBlock *ltb = tPtr->lastTextBlock;
				int ly = ltb->sections[ltb->nsections - 1]._y;
				int lh = ltb->sections[ltb->nsections - 1].h;
				int ss, sd;

				lh += 1 + tPtr->visible.y + ltb->sections[ltb->nsections - 1].max_d;
				printf("it's %d\n", tPtr->visible.y + ltb->sections[ltb->nsections - 1].max_d);

				y += layOutLine(tPtr, items, nitems, x, y);
				ss = ly + lh - y;
				sd = tPtr->docHeight - y;

				printf("dif %d-%d: %d\n", ss, sd, ss - sd);
				y += tb->next->sections[0]._y - y;
				nitems = 0;
				printf("nitems%d\n", nitems);
				if (ss - sd != 0)
					y = tPtr->docHeight + ss - sd;

				break;
			} else {
				tPtr->flags.laidOut = False;
			}
		}

		tb = tb->next;
	}

	if (nitems > 0)
		y += layOutLine(tPtr, items, nitems, x, y);

	if (tPtr->docHeight != y + 10) {
		tPtr->docHeight = y + 10;
		updateScrollers(tPtr);
	}

	if (tPtr->docWidth > tPtr->visible.w && !tPtr->hS) {
		XEvent event;

		tPtr->flags.horizOnDemand = True;
		WMSetTextHasHorizontalScroller((WMText *) tPtr, True);
		event.type = Expose;
		handleEvents(&event, (void *)tPtr);

	} else if (tPtr->docWidth <= tPtr->visible.w && tPtr->hS && tPtr->flags.horizOnDemand) {
		tPtr->flags.horizOnDemand = False;
		WMSetTextHasHorizontalScroller((WMText *) tPtr, False);
	}

	tPtr->flags.laidOut = True;

	if (items && itemsSize > 0)
		wfree(items);

}

static void textDidResize(W_ViewDelegate * self, WMView * view)
{
	Text *tPtr = (Text *) view->self;
	unsigned short w = tPtr->view->size.width;
	unsigned short h = tPtr->view->size.height;
	unsigned short rh = 0, vw = 0, rel;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;

	rel = (tPtr->flags.relief == WRFlat);

	if (tPtr->ruler && tPtr->flags.rulerShown) {
		WMMoveWidget(tPtr->ruler, 2, 2);
		WMResizeWidget(tPtr->ruler, w - 4, 40);
		rh = 40;
	}

	if (tPtr->vS) {
		WMMoveWidget(tPtr->vS, 1 - (rel ? 1 : 0), rh + 1 - (rel ? 1 : 0));
		WMResizeWidget(tPtr->vS, 20, h - rh - 2 + (rel ? 2 : 0));
		vw = 20;
		WMSetRulerOffset(tPtr->ruler, 22);
	} else
		WMSetRulerOffset(tPtr->ruler, 2);

	if (tPtr->hS) {
		if (tPtr->vS) {
			WMMoveWidget(tPtr->hS, vw, h - 21);
			WMResizeWidget(tPtr->hS, w - vw - 1, 20);
		} else {
			WMMoveWidget(tPtr->hS, vw + 1, h - 21);
			WMResizeWidget(tPtr->hS, w - vw - 2, 20);
		}
	}

	tPtr->visible.x = (tPtr->vS) ? 24 : 4;
	tPtr->visible.y = (tPtr->ruler && tPtr->flags.rulerShown) ? 43 : 3;
	tPtr->visible.w = tPtr->view->size.width - tPtr->visible.x - 8;
	tPtr->visible.h = tPtr->view->size.height - tPtr->visible.y;
	tPtr->visible.h -= (tPtr->hS) ? 20 : 0;
	tPtr->margins[0].right = tPtr->visible.w;

	if (tPtr->view->flags.realized) {

		if (tPtr->db) {
			XFreePixmap(tPtr->view->screen->display, tPtr->db);
			tPtr->db = (Pixmap) NULL;
		}

		if (tPtr->visible.w < 40)
			tPtr->visible.w = 40;
		if (tPtr->visible.h < 20)
			tPtr->visible.h = 20;

		if (!tPtr->db) {
			tPtr->db = XCreatePixmap(tPtr->view->screen->display,
						 tPtr->view->window, tPtr->visible.w,
						 tPtr->visible.h, tPtr->view->screen->depth);
		}
	}

	WMThawText(tPtr);
}

W_ViewDelegate _TextViewDelegate = {
	NULL,
	NULL,
	textDidResize,
	NULL,
	NULL
};

#define TEXT_BUFFER_INCR 8
#define reqBlockSize(requested)  (requested + TEXT_BUFFER_INCR)

static void clearText(Text * tPtr)
{
	tPtr->vpos = tPtr->hpos = 0;
	tPtr->docHeight = tPtr->docWidth = 0;
	tPtr->cursor.x = -23;

	if (!tPtr->firstTextBlock)
		return;

	while (tPtr->currentTextBlock)
		WMDestroyTextBlock(tPtr, WMRemoveTextBlock(tPtr));

	tPtr->firstTextBlock = NULL;
	tPtr->currentTextBlock = NULL;
	tPtr->lastTextBlock = NULL;
	WMEmptyArray(tPtr->gfxItems);
}

/* possibly remove a single character from the currentTextBlock,
 or if there's a selection, remove it...
 note that Delete and Backspace are treated differently */
static void deleteTextInteractively(Text * tPtr, KeySym ksym)
{
	TextBlock *tb;
	Bool back = (Bool) (ksym == XK_BackSpace);
	Bool done = 1, wasFirst = 0;

	if (!tPtr->flags.editable)
		return;

	if (!(tb = tPtr->currentTextBlock))
		return;

	if (tPtr->flags.ownsSelection) {
		if (removeSelection(tPtr))
			layOutDocument(tPtr);
		return;
	}

	wasFirst = tb->first;
	if (back && tPtr->tpos < 1) {
		if (tb->prior) {
			if (tb->prior->blank) {
				tPtr->currentTextBlock = tb->prior;
				WMRemoveTextBlock(tPtr);
				tPtr->currentTextBlock = tb;
				tb->first = True;
				layOutDocument(tPtr);
				return;
			} else {
				if (tb->blank) {
					TextBlock *prior = tb->prior;
					tPtr->currentTextBlock = tb;
					WMRemoveTextBlock(tPtr);
					tb = prior;
				} else {
					tb = tb->prior;
				}

				if (tb->graphic)
					tPtr->tpos = 1;
				else
					tPtr->tpos = tb->used;

				tPtr->currentTextBlock = tb;
				done = 1;
				if (wasFirst) {
					if (tb->next)
						tb->next->first = False;
					layOutDocument(tPtr);
					return;
				}
			}
		}
	}

	if ((tb->used > 0) && ((back ? tPtr->tpos > 0 : 1))
	    && (tPtr->tpos <= tb->used) && !tb->graphic) {
		if (back)
			tPtr->tpos--;
		memmove(&(tb->text[tPtr->tpos]), &(tb->text[tPtr->tpos + 1]), tb->used - tPtr->tpos);
		tb->used--;
		done = 0;
	}

	/* if there are no characters left to back over in the textblock,
	   but it still has characters to the right of the cursor: */
	if ((back ? (tPtr->tpos == 0 && !done) : (tPtr->tpos >= tb->used))
	    || tb->graphic) {

		/* no more chars, and it's marked as blank? */
		if (tb->blank) {
			TextBlock *sibling = (back ? tb->prior : tb->next);

			if (tb->used == 0 || tb->graphic)
				WMDestroyTextBlock(tPtr, WMRemoveTextBlock(tPtr));

			if (sibling) {
				tPtr->currentTextBlock = sibling;
				if (tb->graphic)
					tPtr->tpos = (back ? 1 : 0);
				else
					tPtr->tpos = (back ? sibling->used : 0);
			}
			/* no more chars, so mark it as blank */
		} else if (tb->used == 0) {
			tb->blank = 1;
		} else if (tb->graphic) {
			Bool hasNext = (tb->next != NULL);

			WMDestroyTextBlock(tPtr, WMRemoveTextBlock(tPtr));
			if (hasNext) {
				tPtr->tpos = 0;
			} else if (tPtr->currentTextBlock) {
				tPtr->tpos = (tPtr->currentTextBlock->graphic ? 1 : tPtr->currentTextBlock->used);
			}
		} else
			printf("DEBUG: unaccounted for... catch this!\n");
	}

	layOutDocument(tPtr);
}

static void insertTextInteractively(Text * tPtr, char *text, int len)
{
	TextBlock *tb;
	char *newline = NULL;

	if (!tPtr->flags.editable) {
		return;
	}

	if (len < 1 || !text)
		return;

	if (tPtr->flags.ignoreNewLine && *text == '\n' && len == 1)
		return;

	if (tPtr->flags.ownsSelection)
		removeSelection(tPtr);

	if (tPtr->flags.ignoreNewLine) {
		int i;
		for (i = 0; i < len; i++) {
			if (text[i] == '\n')
				text[i] = ' ';
		}
	}

	tb = tPtr->currentTextBlock;
	if (!tb || tb->graphic) {
		tPtr->tpos = 0;
		WMAppendTextStream(tPtr, text);
		layOutDocument(tPtr);
		return;
	}

	if ((newline = strchr(text, '\n'))) {
		int nlen = (int)(newline - text);
		int s = tb->used - tPtr->tpos;

		if (!tb->blank && nlen > 0) {
			char *save = NULL;

			if (s > 0) {
				save = wmalloc(s);
				memcpy(save, &tb->text[tPtr->tpos], s);
				tb->used -= (tb->used - tPtr->tpos);
			}
			insertTextInteractively(tPtr, text, nlen);
			newline++;
			WMAppendTextStream(tPtr, newline);
			if (s > 0) {
				insertTextInteractively(tPtr, save, s);
				wfree(save);
			}
		} else {
			if (tPtr->tpos > 0 && tPtr->tpos < tb->used && !tb->graphic && tb->text) {

				unsigned short savePos = tPtr->tpos;
				void *ntb = WMCreateTextBlockWithText(tPtr, &tb->text[tPtr->tpos],
								      tb->d.font, tb->color, True,
								      tb->used - tPtr->tpos);

				if (tb->sections[0].end == tPtr->tpos)
					WMAppendTextBlock(tPtr, WMCreateTextBlockWithText(tPtr,
											  NULL, tb->d.font,
											  tb->color, True, 0));

				tb->used = savePos;
				WMAppendTextBlock(tPtr, ntb);
				tPtr->tpos = 0;

			} else if (tPtr->tpos == tb->used) {
				if (tPtr->flags.indentNewLine) {
					WMAppendTextBlock(tPtr, WMCreateTextBlockWithText(tPtr,
											  "    ", tb->d.font,
											  tb->color, True, 4));
					tPtr->tpos = 4;
				} else {
					WMAppendTextBlock(tPtr, WMCreateTextBlockWithText(tPtr,
											  NULL, tb->d.font,
											  tb->color, True, 0));
					tPtr->tpos = 0;
				}
			} else if (tPtr->tpos == 0) {
				if (tPtr->flags.indentNewLine) {
					WMPrependTextBlock(tPtr, WMCreateTextBlockWithText(tPtr,
											   "    ", tb->d.font,
											   tb->color, True, 4));
				} else {
					WMPrependTextBlock(tPtr, WMCreateTextBlockWithText(tPtr,
											   NULL, tb->d.font,
											   tb->color, True, 0));
				}
				tPtr->tpos = 0;
				if (tPtr->currentTextBlock->next)
					tPtr->currentTextBlock = tPtr->currentTextBlock->next;
			}
		}
	} else {
		if (tb->used + len >= tb->allocated) {
			tb->allocated = reqBlockSize(tb->used + len);
			tb->text = wrealloc(tb->text, tb->allocated);
		}

		if (tb->blank) {
			memcpy(tb->text, text, len);
			tb->used = len;
			tPtr->tpos = len;
			tb->text[tb->used] = 0;
			tb->blank = False;

		} else {
			memmove(&(tb->text[tPtr->tpos + len]), &tb->text[tPtr->tpos], tb->used - tPtr->tpos + 1);
			memmove(&tb->text[tPtr->tpos], text, len);
			tb->used += len;
			tPtr->tpos += len;
			tb->text[tb->used] = 0;
		}

	}

	layOutDocument(tPtr);
}

static void selectRegion(Text * tPtr, int x, int y)
{

	if (x < 0 || y < 0)
		return;

	y += (tPtr->flags.rulerShown ? 40 : 0);
	y += tPtr->vpos;
	if (y > 10)
		y -= 10;	/* the original offset */

	x -= tPtr->visible.x - 2;
	if (x < 0)
		x = 0;

	tPtr->sel.x = WMAX(0, WMIN(tPtr->clicked.x, x));
	tPtr->sel.w = abs(tPtr->clicked.x - x);
	tPtr->sel.y = WMAX(0, WMIN(tPtr->clicked.y, y));
	tPtr->sel.h = abs(tPtr->clicked.y - y);

	tPtr->flags.ownsSelection = True;
	paintText(tPtr);
}

static void releaseSelection(Text * tPtr)
{
	TextBlock *tb = tPtr->firstTextBlock;

	while (tb) {
		tb->selected = False;
		tb = tb->next;
	}
	tPtr->flags.ownsSelection = False;
	WMDeleteSelectionHandler(tPtr->view, XA_PRIMARY, CurrentTime);

	paintText(tPtr);
}

static WMData *requestHandler(WMView * view, Atom selection, Atom target, void *cdata, Atom * type)
{
	Text *tPtr = view->self;
	Display *dpy = tPtr->view->screen->display;
	Atom _TARGETS;
	Atom TEXT = XInternAtom(dpy, "TEXT", False);
	Atom COMPOUND_TEXT = XInternAtom(dpy, "COMPOUND_TEXT", False);
	WMData *data = NULL;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) selection;
	(void) cdata;

	if (target == XA_STRING || target == TEXT || target == COMPOUND_TEXT) {
		char *text = WMGetTextSelectedStream(tPtr);

		if (text) {
			data = WMCreateDataWithBytes(text, strlen(text));
			WMSetDataFormat(data, TYPETEXT);
			wfree(text);
		}
		*type = target;
		return data;
	} else
		printf("didn't get it\n");

	_TARGETS = XInternAtom(dpy, "TARGETS", False);
	if (target == _TARGETS) {
		Atom array[4];

		array[0] = _TARGETS;
		array[1] = XA_STRING;
		array[2] = TEXT;
		array[3] = COMPOUND_TEXT;

		data = WMCreateDataWithBytes(&array, sizeof(array));
		WMSetDataFormat(data, 32);

		*type = target;
		return data;
	}

	return NULL;
}

static void lostHandler(WMView * view, Atom selection, void *cdata)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) selection;
	(void) cdata;

	releaseSelection((WMText *) view->self);
}

static WMSelectionProcs selectionHandler = {
	requestHandler, lostHandler, NULL
};

static void ownershipObserver(void *observerData, WMNotification * notification)
{
	if (observerData != WMGetNotificationClientData(notification))
		lostHandler(WMWidgetView(observerData), XA_PRIMARY, NULL);
}

static void autoSelectText(Text * tPtr, int clicks)
{
	int x, start;
	TextBlock *tb;
	char *mark = NULL, behind, ahead;

	if (!(tb = tPtr->currentTextBlock))
		return;

	if (clicks == 2) {

		switch (tb->text[tPtr->tpos]) {
		case ' ':
			return;
			/*
			   case '<': case '>': behind = '<'; ahead = '>'; break;
			   case '{': case '}': behind = '{'; ahead = '}'; break;
			   case '[': case ']': behind = '['; ahead = ']'; break;
			 */
		default:
			behind = ahead = ' ';
		}

		tPtr->sel.y = tPtr->cursor.y + 5;
		tPtr->sel.h = 6;	/*tPtr->cursor.h-10; */

		if (tb->graphic) {
			tPtr->sel.x = tb->sections[0].x;
			tPtr->sel.w = tb->sections[0].w;
		} else {
			WMFont *font = tPtr->flags.monoFont ? tPtr->dFont : tb->d.font;

			start = tPtr->tpos;
			while (start > 0 && tb->text[start - 1] != behind)
				start--;

			x = tPtr->cursor.x;
			if (tPtr->tpos > start) {
				x -= WMWidthOfString(font, &tb->text[start], tPtr->tpos - start);
			}
			tPtr->sel.x = (x < 0 ? 0 : x) + 1;

			if ((mark = strchr(&tb->text[start], ahead))) {
				tPtr->sel.w = WMWidthOfString(font, &tb->text[start],
							      (int)(mark - &tb->text[start]));
			} else if (tb->used > start) {
				tPtr->sel.w = WMWidthOfString(font, &tb->text[start], tb->used - start);
			}
		}

	} else if (clicks == 3) {
		TextBlock *cur = tb;

		while (!tb->first) {
			tb = tb->prior;
			if (tb == NULL) {
#ifndef NDEBUG
				wwarning("corrupted list of text blocks in WMText, while searching for first block");
#endif
				goto error_select_3clicks;
			}
		}
		tPtr->sel.y = tb->sections[0]._y;

		tb = cur;
		while (tb->next && !tb->next->first) {
			tb = tb->next;
		}
		tPtr->sel.h = tb->sections[tb->nsections - 1]._y + 5 - tPtr->sel.y;

	error_select_3clicks:
		tPtr->sel.x = 0;
		tPtr->sel.w = tPtr->docWidth;
		tPtr->clicked.x = 0;	/* only for now, fix sel. code */
	}

	if (!tPtr->flags.ownsSelection) {
		WMCreateSelectionHandler(tPtr->view, XA_PRIMARY, tPtr->lastClickTime, &selectionHandler, NULL);
		tPtr->flags.ownsSelection = True;
	}
	paintText(tPtr);

}

# if 0
static void fontChanged(void *observerData, WMNotification * notification)
{
	WMText *tPtr = (WMText *) observerData;
	WMFont *font = (WMFont *) WMGetNotificationClientData(notification);
	printf("fontChanged\n");

	if (!tPtr || !font)
		return;

	if (tPtr->flags.ownsSelection)
		WMSetTextSelectionFont(tPtr, font);
}
#endif

static void handleTextKeyPress(Text * tPtr, XEvent * event)
{
	char buffer[64];
	KeySym ksym;
	int control_pressed = False;
	TextBlock *tb = NULL;

	if (((XKeyEvent *) event)->state & ControlMask)
		control_pressed = True;
	buffer[XLookupString(&event->xkey, buffer, 63, &ksym, NULL)] = 0;

	switch (ksym) {

	case XK_Home:
		if ((tPtr->currentTextBlock = tPtr->firstTextBlock))
			tPtr->tpos = 0;
		updateCursorPosition(tPtr);
		paintText(tPtr);
		break;

	case XK_End:
		if ((tPtr->currentTextBlock = tPtr->lastTextBlock)) {
			if (tPtr->currentTextBlock->graphic)
				tPtr->tpos = 1;
			else
				tPtr->tpos = tPtr->currentTextBlock->used;
		}
		updateCursorPosition(tPtr);
		paintText(tPtr);
		break;

	case XK_Left:
		if (!(tb = tPtr->currentTextBlock))
			break;

		if (tb->graphic || tPtr->tpos == 0) {
			if (tb->prior) {
				tPtr->currentTextBlock = tb->prior;
				if (tPtr->currentTextBlock->graphic)
					tPtr->tpos = 1;
				else
					tPtr->tpos = tPtr->currentTextBlock->used;

				if (!tb->first && tPtr->tpos > 0)
					tPtr->tpos--;
			} else
				tPtr->tpos = 0;
		} else
			tPtr->tpos--;
		updateCursorPosition(tPtr);
		paintText(tPtr);
		break;

	case XK_Right:
		if (!(tb = tPtr->currentTextBlock))
			break;
		if (tb->graphic || tPtr->tpos == tb->used) {
			if (tb->next) {
				tPtr->currentTextBlock = tb->next;
				tPtr->tpos = 0;
				if (!tb->next->first && tb->next->used > 0)
					tPtr->tpos++;
			} else {
				if (tb->graphic)
					tPtr->tpos = 1;
				else
					tPtr->tpos = tb->used;
			}
		} else
			tPtr->tpos++;
		updateCursorPosition(tPtr);
		paintText(tPtr);
		break;

	case XK_Down:
		cursorToTextPosition(tPtr, tPtr->cursor.x + tPtr->visible.x,
				     tPtr->clicked.y + tPtr->cursor.h - tPtr->vpos);
		paintText(tPtr);
		break;

	case XK_Up:
		cursorToTextPosition(tPtr, tPtr->cursor.x + tPtr->visible.x,
				     tPtr->visible.y + tPtr->cursor.y - tPtr->vpos - 3);
		paintText(tPtr);
		break;

	case XK_BackSpace:
	case XK_Delete:
#ifdef XK_KP_Delete
	case XK_KP_Delete:
#endif
		deleteTextInteractively(tPtr, ksym);
		updateCursorPosition(tPtr);
		paintText(tPtr);
		break;

	case XK_Control_R:
	case XK_Control_L:
		control_pressed = True;
		break;

	case XK_Tab:
		insertTextInteractively(tPtr, "    ", 4);
		updateCursorPosition(tPtr);
		paintText(tPtr);
		break;

	case XK_Return:
		*buffer = '\n';
	default:
		if (*buffer != 0 && !control_pressed) {
			insertTextInteractively(tPtr, buffer, strlen(buffer));
			updateCursorPosition(tPtr);
			paintText(tPtr);

		} else if (control_pressed && ksym == XK_r) {
			Bool i = !tPtr->flags.rulerShown;
			WMShowTextRuler(tPtr, i);
			tPtr->flags.rulerShown = i;
		} else if (control_pressed && *buffer == '\a') {
			XBell(tPtr->view->screen->display, 0);
		} else {
			WMRelayToNextResponder(tPtr->view, event);
		}
	}

	if (!control_pressed && tPtr->flags.ownsSelection) {
		releaseSelection(tPtr);
	}
}

static void pasteText(WMView * view, Atom selection, Atom target, Time timestamp, void *cdata, WMData * data)
{
	Text *tPtr = (Text *) view->self;
	char *text;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) selection;
	(void) target;
	(void) timestamp;
	(void) cdata;

	tPtr->flags.waitingForSelection = 0;

	if (data) {
		text = (char *)WMDataBytes(data);

		if (tPtr->parser) {
			(tPtr->parser) (tPtr, (void *)text);
			layOutDocument(tPtr);
		} else
			insertTextInteractively(tPtr, text, strlen(text));
		updateCursorPosition(tPtr);
		paintText(tPtr);

	} else {
		int n;

		text = XFetchBuffer(tPtr->view->screen->display, &n, 0);

		if (text) {
			text[n] = 0;
			if (tPtr->parser) {
				(tPtr->parser) (tPtr, (void *)text);
				layOutDocument(tPtr);
			} else
				insertTextInteractively(tPtr, text, n);
			updateCursorPosition(tPtr);
			paintText(tPtr);

			XFree(text);
		}
	}

}

static void handleActionEvents(XEvent * event, void *data)
{
	Text *tPtr = (Text *) data;
	Display *dpy = event->xany.display;
	KeySym ksym;

	switch (event->type) {
	case KeyPress:
		ksym = XLookupKeysym((XKeyEvent *) event, 0);
		if (ksym == XK_Shift_R || ksym == XK_Shift_L) {
			tPtr->flags.extendSelection = True;
			return;
		}

		if (tPtr->flags.focused) {
			XGrabPointer(dpy, W_VIEW(tPtr)->window, False,
				     PointerMotionMask | ButtonPressMask | ButtonReleaseMask,
				     GrabModeAsync, GrabModeAsync, None,
				     tPtr->view->screen->invisibleCursor, CurrentTime);
			tPtr->flags.pointerGrabbed = True;
			handleTextKeyPress(tPtr, event);

		}
		break;

	case KeyRelease:
		ksym = XLookupKeysym((XKeyEvent *) event, 0);
		if (ksym == XK_Shift_R || ksym == XK_Shift_L) {
			tPtr->flags.extendSelection = False;
			return;
			/* end modify flag so selection can be extended */
		}
		break;

	case MotionNotify:

		if (tPtr->flags.pointerGrabbed) {
			tPtr->flags.pointerGrabbed = False;
			XUngrabPointer(dpy, CurrentTime);
		}

		if (tPtr->flags.waitingForSelection)
			break;

		if ((event->xmotion.state & Button1Mask)) {

			if (WMIsDraggingFromView(tPtr->view)) {
				WMDragImageFromView(tPtr->view, event);
				break;
			}

			if (!tPtr->flags.ownsSelection) {
				WMCreateSelectionHandler(tPtr->view,
							 XA_PRIMARY, event->xbutton.time, &selectionHandler, NULL);
				tPtr->flags.ownsSelection = True;
			}
			selectRegion(tPtr, event->xmotion.x, event->xmotion.y);
			break;
		}

		mouseOverObject(tPtr, event->xmotion.x, event->xmotion.y);
		break;

	case ButtonPress:

		if (tPtr->flags.pointerGrabbed) {
			tPtr->flags.pointerGrabbed = False;
			XUngrabPointer(dpy, CurrentTime);
			break;
		}

		if (tPtr->flags.waitingForSelection)
			break;

		if (tPtr->flags.extendSelection && tPtr->flags.ownsSelection) {
			selectRegion(tPtr, event->xmotion.x, event->xmotion.y);
			return;
		}

		if (tPtr->flags.ownsSelection)
			releaseSelection(tPtr);

		if (event->xbutton.button == Button1) {
			TextBlock *tb = tPtr->currentTextBlock;

			if (WMIsDoubleClick(event)) {

				tPtr->lastClickTime = event->xbutton.time;
				if (tb && tb->graphic && !tb->object) {
					if (tPtr->delegate && tPtr->delegate->didDoubleClickOnPicture) {
						char *desc;

						desc = wmalloc(tb->used + 1);
						memcpy(desc, tb->text, tb->used);
						desc[tb->used] = 0;
						(*tPtr->delegate->didDoubleClickOnPicture) (tPtr->delegate, desc);
						wfree(desc);
					}
				} else {
					autoSelectText(tPtr, 2);
				}
				break;
			} else if (event->xbutton.time - tPtr->lastClickTime < WINGsConfiguration.doubleClickDelay) {
				tPtr->lastClickTime = event->xbutton.time;
				autoSelectText(tPtr, 3);
				break;
			}

			if (!tPtr->flags.focused) {
				WMSetFocusToWidget(tPtr);
				tPtr->flags.focused = True;
			} else if (tb && tPtr->flags.isOverGraphic && tb->graphic && !tb->object && tb->d.pixmap) {

				WMSetViewDragImage(tPtr->view, tb->d.pixmap);
				WMDragImageFromView(tPtr->view, event);
				break;
			}

			tPtr->lastClickTime = event->xbutton.time;
			cursorToTextPosition(tPtr, event->xmotion.x, event->xmotion.y);
			paintText(tPtr);
		}

		if (event->xbutton.button == WINGsConfiguration.mouseWheelDown) {
			WMScrollText(tPtr, 16);
			break;
		}

		if (event->xbutton.button == WINGsConfiguration.mouseWheelUp) {
			WMScrollText(tPtr, -16);
			break;
		}

		if (event->xbutton.button == Button2) {
			char *text = NULL;
			int n;

			if (!tPtr->flags.editable) {
				XBell(dpy, 0);
				break;
			}

			if (!WMRequestSelection(tPtr->view, XA_PRIMARY, XA_STRING,
						event->xbutton.time, pasteText, NULL)) {

				text = XFetchBuffer(tPtr->view->screen->display, &n, 0);
				tPtr->flags.waitingForSelection = 0;

				if (text) {
					text[n] = 0;

					if (tPtr->parser) {
						(tPtr->parser) (tPtr, (void *)text);
						layOutDocument(tPtr);
					} else
						insertTextInteractively(tPtr, text, n);

					XFree(text);
#if 0
					NOTIFY(tPtr, didChange, WMTextDidChangeNotification,
					       (void *)WMInsertTextEvent);
#endif
					updateCursorPosition(tPtr);
					paintText(tPtr);

				} else {
					tPtr->flags.waitingForSelection = True;
				}
			}
			break;
		}

	case ButtonRelease:
		if (tPtr->flags.pointerGrabbed) {
			tPtr->flags.pointerGrabbed = False;
			XUngrabPointer(dpy, CurrentTime);
			break;
		}

		if (tPtr->flags.waitingForSelection)
			break;

		if (WMIsDraggingFromView(tPtr->view))
			WMDragImageFromView(tPtr->view, event);
	}

}

static void handleEvents(XEvent * event, void *data)
{
	Text *tPtr = (Text *) data;

	switch (event->type) {
	case Expose:

		if (event->xexpose.count != 0)
			break;

		if (tPtr->hS) {
			if (!(W_VIEW(tPtr->hS))->flags.realized)
				WMRealizeWidget(tPtr->hS);
		}

		if (tPtr->vS) {
			if (!(W_VIEW(tPtr->vS))->flags.realized)
				WMRealizeWidget(tPtr->vS);
		}

		if (tPtr->ruler) {
			if (!(W_VIEW(tPtr->ruler))->flags.realized)
				WMRealizeWidget(tPtr->ruler);

		}

		if (!tPtr->db)
			textDidResize(tPtr->view->delegate, tPtr->view);

		paintText(tPtr);
		break;

	case FocusIn:
		if (W_FocusedViewOfToplevel(W_TopLevelOfView(tPtr->view))
		    != tPtr->view)
			return;
		tPtr->flags.focused = True;
#if DO_BLINK
		if (tPtr->flags.editable && !tPtr->timerID) {
			tPtr->timerID = WMAddTimerHandler(12 + 0 * CURSOR_BLINK_ON_DELAY, blinkCursor, tPtr);
		}
#endif

		break;

	case FocusOut:
		tPtr->flags.focused = False;
		paintText(tPtr);
#if DO_BLINK
		if (tPtr->timerID) {
			WMDeleteTimerHandler(tPtr->timerID);
			tPtr->timerID = NULL;
		}
#endif
		break;

	case DestroyNotify:
		clearText(tPtr);
		if (tPtr->db)
			XFreePixmap(tPtr->view->screen->display, tPtr->db);
		if (tPtr->gfxItems)
			WMEmptyArray(tPtr->gfxItems);
#if DO_BLINK
		if (tPtr->timerID)
			WMDeleteTimerHandler(tPtr->timerID);
#endif
		WMReleaseFont(tPtr->dFont);
		WMReleaseColor(tPtr->dColor);
		WMDeleteSelectionHandler(tPtr->view, XA_PRIMARY, CurrentTime);
		WMRemoveNotificationObserver(tPtr);

		WMFreeArray(tPtr->xdndSourceTypes);
		WMFreeArray(tPtr->xdndDestinationTypes);

		wfree(tPtr);

		break;

	}
}

static void insertPlainText(Text * tPtr, const char *text)
{
	const char *start, *mark;
	void *tb = NULL;

	start = text;
	while (start) {
		mark = strchr(start, '\n');
		if (mark) {
			tb = WMCreateTextBlockWithText(tPtr,
						       start, tPtr->dFont,
						       tPtr->dColor, tPtr->flags.first, (int)(mark - start));
			start = mark + 1;
			tPtr->flags.first = True;
		} else {
			if (start && strlen(start)) {
				tb = WMCreateTextBlockWithText(tPtr, start, tPtr->dFont,
							       tPtr->dColor, tPtr->flags.first, strlen(start));
			} else
				tb = NULL;
			tPtr->flags.first = False;
			start = mark;
		}

		if (tPtr->flags.prepend)
			WMPrependTextBlock(tPtr, tb);
		else
			WMAppendTextBlock(tPtr, tb);
	}
}

static void rulerMoveCallBack(WMWidget * w, void *self)
{
	Text *tPtr = (Text *) self;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	if (!tPtr)
		return;
	if (W_CLASS(tPtr) != WC_Text)
		return;

	paintText(tPtr);
}

static void rulerReleaseCallBack(WMWidget * w, void *self)
{
	Text *tPtr = (Text *) self;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	if (!tPtr)
		return;
	if (W_CLASS(tPtr) != WC_Text)
		return;

	WMThawText(tPtr);
	return;
}

static WMArray *dropDataTypes(WMView * self)
{
	return ((Text *) self->self)->xdndSourceTypes;
}

static WMDragOperationType wantedDropOperation(WMView * self)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;

	return WDOperationCopy;
}

static Bool acceptDropOperation(WMView * self, WMDragOperationType allowedOperation)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;

	return (allowedOperation == WDOperationCopy);
}

static WMData *fetchDragData(WMView * self, char *type)
{
	TextBlock *tb = ((WMText *) self->self)->currentTextBlock;
	char *desc;
	WMData *data;

	if (strcmp(type, "text/plain")) {
		if (!tb)
			return NULL;

		desc = wmalloc(tb->used + 1);
		memcpy(desc, tb->text, tb->used);
		desc[tb->used] = 0;
		data = WMCreateDataWithBytes(desc, strlen(desc) + 1);

		wfree(desc);

		return data;
	}

	return NULL;
}

static WMDragSourceProcs _DragSourceProcs = {
	dropDataTypes,
	wantedDropOperation,
	NULL,
	acceptDropOperation,
	NULL,
	NULL,
	fetchDragData
};

static WMArray *requiredDataTypes(WMView * self, WMDragOperationType request, WMArray * sourceDataTypes)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) request;
	(void) sourceDataTypes;

	return ((Text *) self->self)->xdndDestinationTypes;
}

static WMDragOperationType allowedOperation(WMView * self, WMDragOperationType request, WMArray * sourceDataTypes)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) self;
	(void) request;
	(void) sourceDataTypes;

	return WDOperationCopy;
}

static void performDragOperation(WMView * self, WMArray * dropData, WMArray * operations, WMPoint * dropLocation)
{
	WMText *tPtr = (WMText *) self->self;
	WMData *data;
	char *colorName;
	WMColor *color;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) operations;
	(void) dropLocation;

	if (tPtr) {

		/* only one required type, implies only one drop data */

		/* get application/X-color if any */
		data = (WMData *) WMPopFromArray(dropData);
		if (data != NULL) {
			colorName = (char *)WMDataBytes(data);
			color = WMCreateNamedColor(W_VIEW_SCREEN(self), colorName, True);

			if (color) {
				WMSetTextSelectionColor(tPtr, color);
				WMReleaseColor(color);
			}
		}
	}
}

static WMDragDestinationProcs _DragDestinationProcs = {
	NULL,
	requiredDataTypes,
	allowedOperation,
	NULL,
	performDragOperation,
	NULL
};

static char *getStream(WMText * tPtr, int sel, int array)
{
	TextBlock *tb = NULL;
	char *text = NULL;
	unsigned long where = 0;

	if (!tPtr)
		return NULL;

	if (!(tb = tPtr->firstTextBlock))
		return NULL;

	if (tPtr->writer) {
		(tPtr->writer) (tPtr, (void *)text);
		return text;
	}

	tb = tPtr->firstTextBlock;
	while (tb) {

		if (!tb->graphic || (tb->graphic && !tPtr->flags.monoFont)) {

			if (!sel || (tb->graphic && tb->selected)) {

				if (!tPtr->flags.ignoreNewLine && (tb->first || tb->blank)
				    && tb != tPtr->firstTextBlock) {
					text = wrealloc(text, where + 1);
					text[where++] = '\n';
				}

				if (tb->blank)
					goto _gSnext;

				if (tb->graphic && array) {
					text = wrealloc(text, where + 4);
					text[where++] = 0xFA;
					text[where++] = (tb->used >> 8) & 0x0ff;
					text[where++] = tb->used & 0x0ff;
					text[where++] = tb->allocated;	/* extra info */
				}
				text = wrealloc(text, where + tb->used);
				memcpy(&text[where], tb->text, tb->used);
				where += tb->used;

			} else if (sel && tb->selected) {

				if (!tPtr->flags.ignoreNewLine && tb->blank) {
					text = wrealloc(text, where + 1);
					text[where++] = '\n';
				}

				if (tb->blank)
					goto _gSnext;

				text = wrealloc(text, where + (tb->s_end - tb->s_begin));
				memcpy(&text[where], &tb->text[tb->s_begin], tb->s_end - tb->s_begin);
				where += tb->s_end - tb->s_begin;

			}

		}
 _gSnext:	tb = tb->next;
	}

	/* +1 for the end of string, let's be nice */
	text = wrealloc(text, where + 1);
	text[where] = 0;
	return text;
}

static void releaseStreamObjects(void *data)
{
	if (data)
		wfree(data);
}

static WMArray *getStreamObjects(WMText * tPtr, int sel)
{
	WMArray *array;
	WMData *data;
	char *stream;
	unsigned short len;
	char *start, *fa, *desc;

	stream = getStream(tPtr, sel, 1);
	if (!stream)
		return NULL;

	array = WMCreateArrayWithDestructor(4, releaseStreamObjects);

	start = stream;
	while (start) {

		fa = strchr(start, 0xFA);
		if (fa) {
			if ((int)(fa - start) > 0) {
				desc = start;
				desc[(int)(fa - start)] = 0;
				data = WMCreateDataWithBytes((void *)desc, (int)(fa - start));
				WMSetDataFormat(data, TYPETEXT);
				WMAddToArray(array, (void *)data);
			}

			len = *(fa + 1) * 0xff + *(fa + 2);
			data = WMCreateDataWithBytes((void *)(fa + 4), len);
			WMSetDataFormat(data, *(fa + 3));
			WMAddToArray(array, (void *)data);
			start = fa + len + 4;

		} else {
			if (start && strlen(start)) {
				data = WMCreateDataWithBytes((void *)start, strlen(start));
				WMSetDataFormat(data, TYPETEXT);
				WMAddToArray(array, (void *)data);
			}
			start = fa;
		}
	}

	wfree(stream);
	return array;
}

#define XDND_TEXT_DATA_TYPE "text/plain"
#define XDND_COLOR_DATA_TYPE "application/X-color"
static WMArray *getXdndSourceTypeArray(void)
{
	WMArray *types = WMCreateArray(1);
	WMAddToArray(types, XDND_TEXT_DATA_TYPE);
	return types;
}

static WMArray *getXdndDestinationTypeArray(void)
{
	WMArray *types = WMCreateArray(1);
	WMAddToArray(types, XDND_COLOR_DATA_TYPE);
	return types;
}

WMText *WMCreateTextForDocumentType(WMWidget * parent, WMAction * parser, WMAction * writer)
{
	Text *tPtr;
	Display *dpy;
	WMScreen *scr;
	XGCValues gcv;

	tPtr = wmalloc(sizeof(Text));
	tPtr->widgetClass = WC_Text;
	tPtr->view = W_CreateView(W_VIEW(parent));
	if (!tPtr->view) {
		perror("could not create text's view\n");
		wfree(tPtr);
		return NULL;
	}

	dpy = tPtr->view->screen->display;
	scr = tPtr->view->screen;

	tPtr->view->self = tPtr;
	tPtr->view->attribs.cursor = scr->textCursor;
	tPtr->view->attribFlags |= CWOverrideRedirect | CWCursor;
	W_ResizeView(tPtr->view, 250, 200);

	tPtr->dColor = WMBlackColor(scr);
	tPtr->fgColor = WMBlackColor(scr);
	tPtr->bgColor = WMWhiteColor(scr);
	W_SetViewBackgroundColor(tPtr->view, tPtr->bgColor);

	gcv.graphics_exposures = False;
	gcv.foreground = W_PIXEL(scr->gray);
	gcv.background = W_PIXEL(scr->darkGray);
	gcv.fill_style = FillStippled;
	/* why not use scr->stipple here? */
	gcv.stipple = XCreateBitmapFromData(dpy, W_DRAWABLE(scr), STIPPLE_BITS, STIPPLE_WIDTH, STIPPLE_HEIGHT);
	tPtr->stippledGC = XCreateGC(dpy, W_DRAWABLE(scr),
				     GCForeground | GCBackground | GCStipple
				     | GCFillStyle | GCGraphicsExposures, &gcv);

	tPtr->ruler = NULL;
	tPtr->vS = NULL;
	tPtr->hS = NULL;

	tPtr->dFont = WMSystemFontOfSize(scr, 12);

	tPtr->view->delegate = &_TextViewDelegate;

	tPtr->delegate = NULL;

#if DO_BLINK
	tPtr->timerID = NULL;
#endif

	WMCreateEventHandler(tPtr->view, ExposureMask | StructureNotifyMask
			     | EnterWindowMask | LeaveWindowMask | FocusChangeMask, handleEvents, tPtr);

	WMCreateEventHandler(tPtr->view, ButtonReleaseMask | ButtonPressMask
			     | KeyReleaseMask | KeyPressMask | Button1MotionMask, handleActionEvents, tPtr);

	WMAddNotificationObserver(ownershipObserver, tPtr, WMSelectionOwnerDidChangeNotification, tPtr);

	WMSetViewDragSourceProcs(tPtr->view, &_DragSourceProcs);
	WMSetViewDragDestinationProcs(tPtr->view, &_DragDestinationProcs);

	{
		WMArray *types = WMCreateArray(2);
		WMAddToArray(types, "application/X-color");
		WMAddToArray(types, "application/X-image");
		WMRegisterViewForDraggedTypes(tPtr->view, types);
		WMFreeArray(types);
	}

	/*WMAddNotificationObserver(fontChanged, tPtr,
	   WMFontPanelDidChangeNotification, tPtr); */

	tPtr->firstTextBlock = NULL;
	tPtr->lastTextBlock = NULL;
	tPtr->currentTextBlock = NULL;
	tPtr->tpos = 0;

	tPtr->gfxItems = WMCreateArray(4);

	tPtr->parser = parser;
	tPtr->writer = writer;

	tPtr->sel.x = tPtr->sel.y = 2;
	tPtr->sel.w = tPtr->sel.h = 0;

	tPtr->clicked.x = tPtr->clicked.y = 2;

	tPtr->visible.x = tPtr->visible.y = 2;
	tPtr->visible.h = tPtr->view->size.height;
	tPtr->visible.w = tPtr->view->size.width - 4;

	tPtr->cursor.x = -23;

	tPtr->docWidth = 0;
	tPtr->docHeight = 0;
	tPtr->dBulletPix = WMCreatePixmapFromXPMData(tPtr->view->screen, default_bullet);
	tPtr->db = (Pixmap) NULL;
	tPtr->bgPixmap = NULL;

	tPtr->margins = WMGetRulerMargins(NULL);
	tPtr->margins->right = tPtr->visible.w;
	tPtr->nMargins = 1;

	tPtr->flags.rulerShown = False;
	tPtr->flags.monoFont = False;
	tPtr->flags.focused = False;
	tPtr->flags.editable = True;
	tPtr->flags.ownsSelection = False;
	tPtr->flags.pointerGrabbed = False;
	tPtr->flags.extendSelection = False;
	tPtr->flags.frozen = False;
	tPtr->flags.cursorShown = True;
	tPtr->flags.acceptsGraphic = False;
	tPtr->flags.horizOnDemand = False;
	tPtr->flags.needsLayOut = False;
	tPtr->flags.ignoreNewLine = False;
	tPtr->flags.indentNewLine = False;
	tPtr->flags.laidOut = False;
	tPtr->flags.ownsSelection = False;
	tPtr->flags.waitingForSelection = False;
	tPtr->flags.prepend = False;
	tPtr->flags.isOverGraphic = False;
	tPtr->flags.relief = WRSunken;
	tPtr->flags.isOverGraphic = 0;
	tPtr->flags.alignment = WALeft;
	tPtr->flags.first = True;

	tPtr->xdndSourceTypes = getXdndSourceTypeArray();
	tPtr->xdndDestinationTypes = getXdndDestinationTypeArray();

	return tPtr;
}

void WMPrependTextStream(WMText * tPtr, const char *text)
{
	CHECK_CLASS(tPtr, WC_Text);

	if (!text) {
		if (tPtr->flags.ownsSelection)
			releaseSelection(tPtr);
		clearText(tPtr);
		updateScrollers(tPtr);
		return;
	}

	tPtr->flags.prepend = True;
	if (text && tPtr->parser)
		(tPtr->parser) (tPtr, (void *)text);
	else
		insertPlainText(tPtr, text);

	tPtr->flags.needsLayOut = True;
	tPtr->tpos = 0;
	if (!tPtr->flags.frozen) {
		layOutDocument(tPtr);
	}
}

void WMAppendTextStream(WMText * tPtr, const char *text)
{
	CHECK_CLASS(tPtr, WC_Text);

	if (!text) {
		if (tPtr->flags.ownsSelection)
			releaseSelection(tPtr);
		clearText(tPtr);
		updateScrollers(tPtr);
		return;
	}

	tPtr->flags.prepend = False;
	if (text && tPtr->parser)
		(tPtr->parser) (tPtr, (void *)text);
	else
		insertPlainText(tPtr, text);

	tPtr->flags.needsLayOut = True;
	if (tPtr->currentTextBlock) {
		if (tPtr->currentTextBlock->graphic)
			tPtr->tpos = 1;
		else
			tPtr->tpos = tPtr->currentTextBlock->used;
	}

	if (!tPtr->flags.frozen) {
		layOutDocument(tPtr);
	}
}

char *WMGetTextStream(WMText * tPtr)
{
	CHECK_CLASS(tPtr, WC_Text);

	return getStream(tPtr, 0, 0);
}

char *WMGetTextSelectedStream(WMText * tPtr)
{
	CHECK_CLASS(tPtr, WC_Text);

	return getStream(tPtr, 1, 0);
}

WMArray *WMGetTextObjects(WMText * tPtr)
{
	CHECK_CLASS(tPtr, WC_Text);

	return getStreamObjects(tPtr, 0);
}

WMArray *WMGetTextSelectedObjects(WMText * tPtr)
{
	CHECK_CLASS(tPtr, WC_Text);

	return getStreamObjects(tPtr, 1);
}

void WMSetTextDelegate(WMText * tPtr, WMTextDelegate * delegate)
{
	CHECK_CLASS(tPtr, WC_Text);

	tPtr->delegate = delegate;
}

void *WMCreateTextBlockWithObject(WMText * tPtr, WMWidget * w,
				  const char *description, WMColor * color,
				  unsigned short first, unsigned short extraInfo)
{
	TextBlock *tb;

	if (!w || !description || !color)
		return NULL;

	tb = wmalloc(sizeof(TextBlock));

	tb->text = wstrdup(description);
	tb->used = strlen(description);
	tb->blank = False;
	tb->d.widget = w;
	tb->color = WMRetainColor(color);
	tb->marginN = newMargin(tPtr, NULL);
	tb->allocated = extraInfo;
	tb->first = first;
	tb->kanji = False;
	tb->graphic = True;
	tb->object = True;
	tb->underlined = False;
	tb->selected = False;
	tb->script = 0;
	tb->sections = NULL;
	tb->nsections = 0;
	tb->prior = NULL;
	tb->next = NULL;

	return tb;
}

void *WMCreateTextBlockWithPixmap(WMText * tPtr, WMPixmap * p,
				  const char *description, WMColor * color,
				  unsigned short first, unsigned short extraInfo)
{
	TextBlock *tb;

	if (!p || !description || !color)
		return NULL;

	tb = wmalloc(sizeof(TextBlock));

	tb->text = wstrdup(description);
	tb->used = strlen(description);
	tb->blank = False;
	tb->d.pixmap = WMRetainPixmap(p);
	tb->color = WMRetainColor(color);
	tb->marginN = newMargin(tPtr, NULL);
	tb->allocated = extraInfo;
	tb->first = first;
	tb->kanji = False;
	tb->graphic = True;
	tb->object = False;
	tb->underlined = False;
	tb->selected = False;
	tb->script = 0;
	tb->sections = NULL;
	tb->nsections = 0;
	tb->prior = NULL;
	tb->next = NULL;

	return tb;
}

void *WMCreateTextBlockWithText(WMText * tPtr, const char *text, WMFont * font, WMColor * color,
				unsigned short first, unsigned short len)
{
	TextBlock *tb;

	if (!font || !color)
		return NULL;

	tb = wmalloc(sizeof(TextBlock));

	tb->allocated = reqBlockSize(len);
	tb->text = (char *)wmalloc(tb->allocated);

	if (len < 1 || !text || (*text == '\n' && len == 1)) {
		*tb->text = ' ';
		tb->used = 1;
		tb->blank = True;
	} else {
		memcpy(tb->text, text, len);
		tb->used = len;
		tb->blank = False;
	}
	tb->text[tb->used] = 0;

	tb->d.font = WMRetainFont(font);
	tb->color = WMRetainColor(color);
	tb->marginN = newMargin(tPtr, NULL);
	tb->first = first;
	tb->kanji = False;
	tb->graphic = False;
	tb->underlined = False;
	tb->selected = False;
	tb->script = 0;
	tb->sections = NULL;
	tb->nsections = 0;
	tb->prior = NULL;
	tb->next = NULL;
	return tb;
}

void
WMSetTextBlockProperties(WMText * tPtr, void *vtb, unsigned int first,
			 unsigned int kanji, unsigned int underlined, int script, WMRulerMargins * margins)
{
	TextBlock *tb = (TextBlock *) vtb;
	if (!tb)
		return;

	tb->first = first;
	tb->kanji = kanji;
	tb->underlined = underlined;
	tb->script = script;
	tb->marginN = newMargin(tPtr, margins);
}

void
WMGetTextBlockProperties(WMText * tPtr, void *vtb, unsigned int *first,
			 unsigned int *kanji, unsigned int *underlined, int *script, WMRulerMargins *margins)
{
	TextBlock *tb = (TextBlock *) vtb;
	if (!tb)
		return;

	if (first)
		*first = tb->first;
	if (kanji)
		*kanji = tb->kanji;
	if (underlined)
		*underlined = tb->underlined;
	if (script)
		*script = tb->script;
	if (margins)
		*margins = tPtr->margins[tb->marginN];
}

static int prepareTextBlock(WMText *tPtr, TextBlock *tb)
{
	if (tb->graphic) {
		if (tb->object) {
			WMWidget *w = tb->d.widget;
			if (W_CLASS(w) != WC_TextField && W_CLASS(w) != WC_Text) {
				(W_VIEW(w))->attribs.cursor = tPtr->view->screen->defaultCursor;
				(W_VIEW(w))->attribFlags |= CWOverrideRedirect | CWCursor;
			}
		}
		WMAddToArray(tPtr->gfxItems, (void *)tb);
		tPtr->tpos = 1;

	} else {
		tPtr->tpos = tb->used;
	}

	if (!tPtr->lastTextBlock || !tPtr->firstTextBlock) {
		tb->next = tb->prior = NULL;
		tb->first = True;
		tPtr->lastTextBlock = tPtr->firstTextBlock = tPtr->currentTextBlock = tb;
		return 0;
	}

	if (!tb->first) {
		tb->marginN = tPtr->currentTextBlock->marginN;
	}

	return 1;
}


void WMPrependTextBlock(WMText *tPtr, void *vtb)
{
	TextBlock *tb = (TextBlock *) vtb;

	if (!tb || !prepareTextBlock(tPtr, tb))
		return;

	tb->next = tPtr->currentTextBlock;
	tb->prior = tPtr->currentTextBlock->prior;
	if (tPtr->currentTextBlock->prior)
		tPtr->currentTextBlock->prior->next = tb;

	tPtr->currentTextBlock->prior = tb;
	if (!tb->prior)
		tPtr->firstTextBlock = tb;

	tPtr->currentTextBlock = tb;
}

void WMAppendTextBlock(WMText *tPtr, void *vtb)
{
	TextBlock *tb = (TextBlock *) vtb;

	if (!tb || !prepareTextBlock(tPtr, tb))
		return;

	tb->next = tPtr->currentTextBlock->next;
	tb->prior = tPtr->currentTextBlock;
	if (tPtr->currentTextBlock->next)
		tPtr->currentTextBlock->next->prior = tb;

	tPtr->currentTextBlock->next = tb;

	if (!tb->next)
		tPtr->lastTextBlock = tb;

	tPtr->currentTextBlock = tb;
}

void *WMRemoveTextBlock(WMText * tPtr)
{
	TextBlock *tb = NULL;

	if (!tPtr->firstTextBlock || !tPtr->lastTextBlock || !tPtr->currentTextBlock) {
		return NULL;
	}

	tb = tPtr->currentTextBlock;
	if (tb->graphic) {
		WMRemoveFromArray(tPtr->gfxItems, (void *)tb);

		if (tb->object) {
			WMUnmapWidget(tb->d.widget);
		}
	}

	if (tPtr->currentTextBlock == tPtr->firstTextBlock) {
		if (tPtr->currentTextBlock->next)
			tPtr->currentTextBlock->next->prior = NULL;

		tPtr->firstTextBlock = tPtr->currentTextBlock->next;
		tPtr->currentTextBlock = tPtr->firstTextBlock;

	} else if (tPtr->currentTextBlock == tPtr->lastTextBlock) {
		tPtr->currentTextBlock->prior->next = NULL;
		tPtr->lastTextBlock = tPtr->currentTextBlock->prior;
		tPtr->currentTextBlock = tPtr->lastTextBlock;
	} else {
		tPtr->currentTextBlock->prior->next = tPtr->currentTextBlock->next;
		tPtr->currentTextBlock->next->prior = tPtr->currentTextBlock->prior;
		tPtr->currentTextBlock = tPtr->currentTextBlock->next;
	}

	return (void *)tb;
}

#if 0
static void destroyWidget(WMWidget * widget)
{
	WMDestroyWidget(widget);
	// -- never do this -- wfree(widget);
}
#endif

void WMDestroyTextBlock(WMText * tPtr, void *vtb)
{
	TextBlock *tb = (TextBlock *) vtb;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) tPtr;

	if (!tb)
		return;

	if (tb->graphic) {
		if (tb->object) {
			/* naturally, there's a danger to destroying widgets whose action
			 * brings us here: ie. press a button to destroy it...
			 * need to find a safer way. till then... this stays commented out */
			/* 5 months later... destroy it 10 seconds after now which should
			 * be enough time for the widget's action to be completed... :-) */
			/* This is a bad assumption. Just destroy the widget here.
			 * if the caller needs it, it can protect it with W_RetainView()
			 * WMAddTimerHandler(10000, destroyWidget, (void *)tb->d.widget);*/
			WMDestroyWidget(tb->d.widget);
		} else {
			WMReleasePixmap(tb->d.pixmap);
		}
	} else {
		WMReleaseFont(tb->d.font);
	}

	WMReleaseColor(tb->color);
	/* isn't this going to memleak if nsections==0? if (tb->sections && tb->nsections > 0) */
	if (tb->sections)
		wfree(tb->sections);
	wfree(tb->text);
	wfree(tb);
}

void WMSetTextForegroundColor(WMText * tPtr, WMColor * color)
{
	if (tPtr->fgColor)
		WMReleaseColor(tPtr->fgColor);

	tPtr->fgColor = WMRetainColor(color ? color : tPtr->view->screen->black);

	paintText(tPtr);
}

void WMSetTextBackgroundColor(WMText * tPtr, WMColor * color)
{
	if (tPtr->bgColor)
		WMReleaseColor(tPtr->bgColor);

	tPtr->bgColor = WMRetainColor(color ? color : tPtr->view->screen->white);
	W_SetViewBackgroundColor(tPtr->view, tPtr->bgColor);

	paintText(tPtr);
}

void WMSetTextBackgroundPixmap(WMText * tPtr, WMPixmap * pixmap)
{
	if (tPtr->bgPixmap)
		WMReleasePixmap(tPtr->bgPixmap);

	if (pixmap)
		tPtr->bgPixmap = WMRetainPixmap(pixmap);
	else
		tPtr->bgPixmap = NULL;
}

void WMSetTextRelief(WMText * tPtr, WMReliefType relief)
{
	tPtr->flags.relief = relief;
	textDidResize(tPtr->view->delegate, tPtr->view);
}

void WMSetTextHasHorizontalScroller(WMText * tPtr, Bool shouldhave)
{
	if (shouldhave && !tPtr->hS) {
		tPtr->hS = WMCreateScroller(tPtr);
		(W_VIEW(tPtr->hS))->attribs.cursor = tPtr->view->screen->defaultCursor;
		(W_VIEW(tPtr->hS))->attribFlags |= CWOverrideRedirect | CWCursor;
		WMSetScrollerArrowsPosition(tPtr->hS, WSAMinEnd);
		WMSetScrollerAction(tPtr->hS, scrollersCallBack, tPtr);
		WMMapWidget(tPtr->hS);
	} else if (!shouldhave && tPtr->hS) {
		WMUnmapWidget(tPtr->hS);
		WMDestroyWidget(tPtr->hS);
		tPtr->hS = NULL;
	}

	tPtr->hpos = 0;
	tPtr->prevHpos = 0;
	textDidResize(tPtr->view->delegate, tPtr->view);
}

void WMSetTextHasRuler(WMText * tPtr, Bool shouldhave)
{
	if (shouldhave && !tPtr->ruler) {
		tPtr->ruler = WMCreateRuler(tPtr);
		(W_VIEW(tPtr->ruler))->attribs.cursor = tPtr->view->screen->defaultCursor;
		(W_VIEW(tPtr->ruler))->attribFlags |= CWOverrideRedirect | CWCursor;
		WMSetRulerReleaseAction(tPtr->ruler, rulerReleaseCallBack, tPtr);
		WMSetRulerMoveAction(tPtr->ruler, rulerMoveCallBack, tPtr);
	} else if (!shouldhave && tPtr->ruler) {
		WMShowTextRuler(tPtr, False);
		WMDestroyWidget(tPtr->ruler);
		tPtr->ruler = NULL;
	}
	textDidResize(tPtr->view->delegate, tPtr->view);
}

void WMShowTextRuler(WMText * tPtr, Bool show)
{
	if (!tPtr->ruler)
		return;

	if (tPtr->flags.monoFont)
		show = False;

	tPtr->flags.rulerShown = show;
	if (show) {
		WMMapWidget(tPtr->ruler);
	} else {
		WMUnmapWidget(tPtr->ruler);
	}

	textDidResize(tPtr->view->delegate, tPtr->view);
}

Bool WMGetTextRulerShown(WMText * tPtr)
{
	if (!tPtr->ruler)
		return False;

	return tPtr->flags.rulerShown;
}

void WMSetTextHasVerticalScroller(WMText * tPtr, Bool shouldhave)
{
	if (shouldhave && !tPtr->vS) {
		tPtr->vS = WMCreateScroller(tPtr);
		(W_VIEW(tPtr->vS))->attribs.cursor = tPtr->view->screen->defaultCursor;
		(W_VIEW(tPtr->vS))->attribFlags |= CWOverrideRedirect | CWCursor;
		WMSetScrollerArrowsPosition(tPtr->vS, WSAMaxEnd);
		WMSetScrollerAction(tPtr->vS, scrollersCallBack, tPtr);
		WMMapWidget(tPtr->vS);
	} else if (!shouldhave && tPtr->vS) {
		WMUnmapWidget(tPtr->vS);
		WMDestroyWidget(tPtr->vS);
		tPtr->vS = NULL;
	}

	tPtr->vpos = 0;
	tPtr->prevVpos = 0;
	textDidResize(tPtr->view->delegate, tPtr->view);
}

Bool WMScrollText(WMText * tPtr, int amount)
{
	Bool scroll = False;

	if (amount == 0 || !tPtr->view->flags.realized)
		return False;

	if (amount < 0) {
		if (tPtr->vpos > 0) {
			if (tPtr->vpos > abs(amount))
				tPtr->vpos += amount;
			else
				tPtr->vpos = 0;
			scroll = True;
		}
	} else {
		int limit = tPtr->docHeight - tPtr->visible.h;
		if (tPtr->vpos < limit) {
			if (tPtr->vpos < limit - amount)
				tPtr->vpos += amount;
			else
				tPtr->vpos = limit;
			scroll = True;
		}
	}

	if (scroll && tPtr->vpos != tPtr->prevVpos) {
		updateScrollers(tPtr);
		paintText(tPtr);
	}
	tPtr->prevVpos = tPtr->vpos;
	return scroll;
}

Bool WMPageText(WMText * tPtr, Bool direction)
{
	if (!tPtr->view->flags.realized)
		return False;

	return WMScrollText(tPtr, direction ? tPtr->visible.h : -tPtr->visible.h);
}

void WMSetTextEditable(WMText * tPtr, Bool editable)
{
	tPtr->flags.editable = editable;
}

int WMGetTextEditable(WMText * tPtr)
{
	return tPtr->flags.editable;
}

void WMSetTextIndentNewLines(WMText * tPtr, Bool indent)
{
	tPtr->flags.indentNewLine = indent;
}

void WMSetTextIgnoresNewline(WMText * tPtr, Bool ignore)
{
	tPtr->flags.ignoreNewLine = ignore;
}

Bool WMGetTextIgnoresNewline(WMText * tPtr)
{
	return tPtr->flags.ignoreNewLine;
}

void WMSetTextUsesMonoFont(WMText * tPtr, Bool mono)
{
	if (mono) {
		if (tPtr->flags.rulerShown)
			WMShowTextRuler(tPtr, False);
		if (tPtr->flags.alignment != WALeft)
			tPtr->flags.alignment = WALeft;
	}

	tPtr->flags.monoFont = mono;
	textDidResize(tPtr->view->delegate, tPtr->view);
}

Bool WMGetTextUsesMonoFont(WMText * tPtr)
{
	return tPtr->flags.monoFont;
}

void WMSetTextDefaultFont(WMText * tPtr, WMFont * font)
{
	if (tPtr->dFont)
		WMReleaseFont(tPtr->dFont);

	if (font) {
		tPtr->dFont = WMRetainFont(font);
	} else {
		tPtr->dFont = WMSystemFontOfSize(tPtr->view->screen, 12);
	}
}

WMFont *WMGetTextDefaultFont(WMText * tPtr)
{
	return WMRetainFont(tPtr->dFont);
}

void WMSetTextDefaultColor(WMText * tPtr, WMColor * color)
{
	if (tPtr->dColor)
		WMReleaseColor(tPtr->dColor);

	if (color) {
		tPtr->dColor = WMRetainColor(color);
	} else {
		tPtr->dColor = WMBlackColor(tPtr->view->screen);
	}
}

WMColor *WMGetTextDefaultColor(WMText * tPtr)
{
	return tPtr->dColor;
}

void WMSetTextAlignment(WMText * tPtr, WMAlignment alignment)
{
	if (tPtr->flags.monoFont)
		tPtr->flags.alignment = WALeft;
	else
		tPtr->flags.alignment = alignment;
	WMThawText(tPtr);
}

int WMGetTextInsertType(WMText * tPtr)
{
	return tPtr->flags.prepend;
}

void WMSetTextSelectionColor(WMText * tPtr, WMColor * color)
{
	setSelectionProperty(tPtr, NULL, color, -1);
}

WMColor *WMGetTextSelectionColor(WMText * tPtr)
{
	TextBlock *tb;

	tb = tPtr->currentTextBlock;

	if (!tb || !tPtr->flags.ownsSelection)
		return NULL;

	if (!tb->selected)
		return NULL;

	return tb->color;
}

void WMSetTextSelectionFont(WMText * tPtr, WMFont * font)
{
	setSelectionProperty(tPtr, font, NULL, -1);
}

WMFont *WMGetTextSelectionFont(WMText * tPtr)
{
	TextBlock *tb;

	tb = tPtr->currentTextBlock;

	if (!tb || !tPtr->flags.ownsSelection)
		return NULL;

	if (!tb->selected)
		return NULL;

	if (tb->graphic) {
		tb = getFirstNonGraphicBlockFor(tb, 1);
		if (!tb)
			return NULL;
	}
	return (tb->selected ? tb->d.font : NULL);
}

void WMSetTextSelectionUnderlined(WMText * tPtr, int underlined)
{
	/* // check this */
	if (underlined != 0 && underlined != 1)
		return;

	setSelectionProperty(tPtr, NULL, NULL, underlined);
}

int WMGetTextSelectionUnderlined(WMText * tPtr)
{
	TextBlock *tb;

	tb = tPtr->currentTextBlock;

	if (!tb || !tPtr->flags.ownsSelection)
		return 0;

	if (!tb->selected)
		return 0;

	return tb->underlined;
}

void WMFreezeText(WMText * tPtr)
{
	tPtr->flags.frozen = True;
}

void WMThawText(WMText * tPtr)
{
	tPtr->flags.frozen = False;

	if (tPtr->flags.monoFont) {
		int j, c = WMGetArrayItemCount(tPtr->gfxItems);
		TextBlock *tb;

		/* make sure to unmap widgets no matter where they are */
		/* they'll be later remapped if needed by paintText */
		for (j = 0; j < c; j++) {
			if ((tb = (TextBlock *) WMGetFromArray(tPtr->gfxItems, j))) {
				if (tb->object && ((W_VIEW(tb->d.widget))->flags.mapped))
					WMUnmapWidget(tb->d.widget);
			}
		}
	}

	tPtr->flags.laidOut = False;
	layOutDocument(tPtr);
	updateScrollers(tPtr);
	paintText(tPtr);
	tPtr->flags.needsLayOut = False;

}

/* find first occurence of a string */
static const char *mystrstr(const char *haystack, const char *needle, unsigned short len, const char *end, Bool caseSensitive)
{
	const char *ptr;

	if (!haystack || !needle || !end)
		return NULL;

	for (ptr = haystack; ptr < end; ptr++) {
		if (caseSensitive) {
			if (*ptr == *needle && !strncmp(ptr, needle, len))
				return ptr;

		} else {
			if (tolower(*ptr) == tolower(*needle) && !strncasecmp(ptr, needle, len))
				return ptr;

		}
	}
	return NULL;
}

/* find last occurence of a string */
static const char *mystrrstr(const char *haystack, const char *needle, unsigned short len, const char *end, Bool caseSensitive)
{
	const char *ptr;

	if (!haystack || !needle || !end)
		return NULL;

	for (ptr = haystack - 2; ptr > end; ptr--) {
		if (caseSensitive) {
			if (*ptr == *needle && !strncmp(ptr, needle, len))
				return ptr;
		} else {
			if (tolower(*ptr) == tolower(*needle) && !strncasecmp(ptr, needle, len))
				return ptr;

		}
	}
	return NULL;
}

Bool WMFindInTextStream(WMText * tPtr, const char *needle, Bool direction, Bool caseSensitive)
{
	TextBlock *tb;
	const char *mark = NULL;
	unsigned short pos;

#if 0
	if (!(tb = tPtr->currentTextBlock)) {
		if (!(tb = ((direction > 0) ? tPtr->firstTextBlock : tPtr->lastTextBlock))) {
			return False;
		}
	} else {
		/*  if(tb != ((direction>0) ?tPtr->firstTextBlock : tPtr->lastTextBlock))
		   tb = (direction>0) ? tb->next : tb->prior; */
		if (tb != tPtr->lastTextBlock)
			tb = tb->prior;
	}
#endif
	tb = tPtr->currentTextBlock;
	pos = tPtr->tpos;

	while (tb) {
		if (!tb->graphic) {

			if (direction > 0) {
				if (pos + 1 < tb->used)
					pos++;

				if (tb->used - pos > 0 && pos > 0) {
					mark = mystrstr(&tb->text[pos], needle,
							strlen(needle), &tb->text[tb->used], caseSensitive);

				} else {
					tb = tb->next;
					pos = 0;
					continue;
				}

			} else {
				if (pos - 1 > 0)
					pos--;

				if (pos > 0) {
					mark = mystrrstr(&tb->text[pos], needle,
							 strlen(needle), tb->text, caseSensitive);
				} else {
					tb = tb->prior;
					if (!tb)
						return False;
					pos = tb->used;
					continue;
				}
			}

			if (mark) {
				WMFont *font = tPtr->flags.monoFont ? tPtr->dFont : tb->d.font;

				tPtr->tpos = (int)(mark - tb->text);
				tPtr->currentTextBlock = tb;
				updateCursorPosition(tPtr);
				tPtr->sel.y = tPtr->cursor.y + 5;
				tPtr->sel.h = tPtr->cursor.h - 10;
				tPtr->sel.x = tPtr->cursor.x + 1;
				tPtr->sel.w = WMIN(WMWidthOfString(font,
								   &tb->text[tPtr->tpos], strlen(needle)),
						   tPtr->docWidth - tPtr->sel.x);
				tPtr->flags.ownsSelection = True;
				paintText(tPtr);

				return True;
			}

		}
		tb = (direction > 0) ? tb->next : tb->prior;
		if (tb) {
			pos = (direction > 0) ? 0 : tb->used;
		}
	}

	return False;
}

Bool WMReplaceTextSelection(WMText * tPtr, char *replacement)
{
	if (!tPtr->flags.ownsSelection)
		return False;

	removeSelection(tPtr);

	if (replacement) {
		insertTextInteractively(tPtr, replacement, strlen(replacement));
		updateCursorPosition(tPtr);
		paintText(tPtr);
	}

	return True;

}
