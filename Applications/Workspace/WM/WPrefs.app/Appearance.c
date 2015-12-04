/* Apperance.c- color/texture for titlebar etc.
 *
 *  WPrefs - Window Maker Preferences Program
 *
 *  Copyright (c) 1999-2003 Alfredo K. Kojima
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include "WPrefs.h"

#include <unistd.h>
#include <errno.h>
#include <ctype.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <math.h>

#include "TexturePanel.h"


static const struct {
	const char *key;
	const char *default_value;
	const char *label;
	WMRect      preview;	/* The rectangle where the corresponding object is displayed */
	WMPoint     hand;	/* The coordinate where the hand is drawn when pointing this item */
} colorOptions[] = {
	/* Related to Window titles */
	{ "FTitleColor", "white", N_("Focused Window Title"),
	  { { 30, 10 }, { 190, 20 } }, { 5, 10 } },
	{ "UTitleColor", "black", N_("Unfocused Window Title"),
	  { { 30, 40 }, { 190, 20 } }, { 5, 40 } },
	{ "PTitleColor", "white", N_("Owner of Focused Window Title"),
	  { { 30, 70 }, { 190, 20 } }, { 5, 70 } },

	/* Related to Menus */
	{ "MenuTitleColor", "white", N_("Menu Title") ,
	  { { 30, 120 }, { 90, 20 } }, { 5, 120 } },
	{ "MenuTextColor", "black", N_("Menu Item Text") ,
	  { { 30, 140 }, { 90, 20 } }, { 5, 140 } },
	{ "MenuDisabledColor", "#616161", N_("Disabled Menu Item Text") ,
	  { { 30, 160 }, { 90, 20 } }, { 5, 160 } },
	{ "HighlightColor", "white", N_("Menu Highlight Color") ,
	  { { 30, 180 }, { 90, 20 } }, { 5, 180 } },
	{ "HighlightTextColor", "black", N_("Highlighted Menu Text Color") ,
	  { { 30, 200 }, { 90, 20 } }, { 5, 180 } },
	/*
	 * yuck kluge: the coordinate for HighlightTextColor are actually those of the last "Normal item"
	 * at the bottom when user clicks it, the "yuck kluge" in the function 'previewClick' will swap it
	 * for the MenuTextColor selection as user would expect
	 *
	 * Note that the entries are reffered by their index for performance
	 */

	/* Related to Window's border */
	{ "FrameFocusedBorderColor", "black", N_("Focused Window Border Color") ,
	  { { 0, 0 }, { 0, 0 } }, { -22, -21 } },
	{ "FrameBorderColor", "black", N_("Window Border Color") ,
	  { { 0, 0 }, { 0, 0 } }, { -22, -21 } },
	{ "FrameSelectedBorderColor", "white", N_("Selected Window Border Color") ,
	  { { 0, 0 }, { 0, 0 } }, { -22, -21 } },

	/* Related to Icons and Clip */
	{ "IconTitleColor", "white", N_("Miniwindow Title") ,
	  { { 155, 130 }, { 64, 64 } }, { 130, 132 } },
	{ "IconTitleBack", "black", N_("Miniwindow Title Back") ,
	  { { 155, 130 }, { 64, 64 } }, { 130, 132 } },
	{ "ClipTitleColor", "black", N_("Clip Title") ,
	  { { 155, 130 }, { 64, 64 } }, { 130, 132 } },
	{ "CClipTitleColor", "#454045", N_("Collapsed Clip Title") ,
	  { { 155, 130 }, { 64, 64 } }, { 130, 132 } }
};

/********************************************************************/
typedef enum {
	MSTYLE_NORMAL = 0,
	MSTYLE_SINGLE = 1,
	MSTYLE_FLAT   = 2
} menu_style_index;

static const struct {
	const char *db_value;
	const char *file_name;
} menu_style[] = {
	[MSTYLE_NORMAL] = { "normal",        "msty1" },
	[MSTYLE_SINGLE] = { "singletexture", "msty2" },
	[MSTYLE_FLAT]   = { "flat",          "msty3" }
};

/********************************************************************/
static const struct {
	const char *label;
	const char *db_value;
} wintitle_align[] = {
	[WALeft]   = { N_("Left"),   "left"   },
	[WACenter] = { N_("Center"), "center" },
	[WARight]  = { N_("Right"),  "right"  }
};

/********************************************************************/
static const char *const sample_colors[] = {
	"black",
	"#292929",
	"#525252",
	"#848484",
	"#adadad",
	"#d6d6d6",
	"white",
	"#d6d68c",
	"#d6a57b",
	"#8cd68c",
	"#8cd6ce",
	"#d68c8c",
	"#8c9cd6",
	"#bd86d6",
	"#d68cbd",
	"#d64a4a",
	"#4a5ad6",
	"#4ad6ce",
	"#4ad65a",
	"#ced64a",
	"#d6844a",
	"#8ad631",
	"#ce29c6",
	"#ce2973"
};

/********************************************************************/
typedef struct _Panel {
	WMBox *box;
	char *sectionName;

	char *description;

	CallbackRec callbacks;

	WMWidget *parent;

	WMLabel *prevL;

	WMTabView *tabv;

	/* texture list */
	WMFrame *texF;
	WMList *texLs;

	WMPopUpButton *secP;

	WMButton *newB;
	WMButton *editB;
	WMButton *ripB;
	WMButton *delB;

	/* text color */
	WMFrame *colF;

	WMPopUpButton *colP;
	WMColor *colors[wlengthof_nocheck(colorOptions)];

	WMColorWell *colW;

	WMColorWell *sampW[wlengthof_nocheck(sample_colors)];

	/* options */
	WMFrame *optF;

	WMFrame *mstyF;
	WMButton *mstyB[wlengthof_nocheck(menu_style)];

	WMFrame *taliF;
	WMButton *taliB[wlengthof_nocheck(wintitle_align)];

	/* */

	int textureIndex[8];

	WMFont *smallFont;
	WMFont *normalFont;
	WMFont *boldFont;

	TexturePanel *texturePanel;

	WMPixmap *onLed;
	WMPixmap *offLed;
	WMPixmap *hand;

	int oldsection;
	int oldcsection;

	char oldTabItem;

	menu_style_index menuStyle;

	WMAlignment titleAlignment;

	Pixmap preview;
	Pixmap previewNoText;
	Pixmap previewBack;

	char *fprefix;
} _Panel;

typedef struct {
	char *title;
	char *texture;
	WMPropList *prop;
	Pixmap preview;

	char *path;

	char selectedFor;
	unsigned current:1;
	unsigned ispixmap:1;
} TextureListItem;

enum {
	TAB_TEXTURE,
	TAB_COLOR,
	TAB_OPTIONS
};

static void updateColorPreviewBox(_Panel * panel, int elements);

static void showData(_Panel * panel);

static void changePage(WMWidget * w, void *data);

static void changeColorPage(WMWidget * w, void *data);

static void OpenExtractPanelFor(_Panel *panel);

static void changedTabItem(struct WMTabViewDelegate *self, WMTabView * tabView, WMTabViewItem * item);

static WMTabViewDelegate tabviewDelegate = {
	NULL,
	NULL,			/* didChangeNumberOfItems */
	changedTabItem,		/* didSelectItem */
	NULL,			/* shouldSelectItem */
	NULL			/* willSelectItem */
};

#define ICON_FILE	"appearance"

#define TNEW_FILE 	"tnew"
#define TDEL_FILE	"tdel"
#define TEDIT_FILE	"tedit"
#define TEXTR_FILE 	"textr"

/* XPM */
static char *blueled_xpm[] = {
	"8 8 17 1",
	" 	c None",
	".	c #020204",
	"+	c #16B6FC",
	"@	c #176AFC",
	"#	c #163AFC",
	"$	c #72D2FC",
	"%	c #224CF4",
	"&	c #76D6FC",
	"*	c #16AAFC",
	"=	c #CEE9FC",
	"-	c #229EFC",
	";	c #164CFC",
	">	c #FAFEFC",
	",	c #2482FC",
	"'	c #1652FC",
	")	c #1E76FC",
	"!	c #1A60FC",
	"  ....  ",
	" .=>-@. ",
	".=>$@@'.",
	".=$@!;;.",
	".!@*+!#.",
	".#'*+*,.",
	" .@)@,. ",
	"  ....  "
};

/* XPM */
static char *blueled2_xpm[] = {
	/* width height num_colors chars_per_pixel */
	"     8     8       17            1",
	/* colors */
	". c None",
	"# c #090909",
	"a c #4b63a4",
	"b c #011578",
	"c c #264194",
	"d c #04338c",
	"e c #989dac",
	"f c #011a7c",
	"g c #465c9c",
	"h c #03278a",
	"i c #6175ac",
	"j c #011e74",
	"k c #043a90",
	"l c #042f94",
	"m c #0933a4",
	"n c #022184",
	"o c #012998",
	/* pixels */
	"..####..",
	".#aimn#.",
	"#aechnf#",
	"#gchnjf#",
	"#jndknb#",
	"#bjdddl#",
	".#nono#.",
	"..####.."
};

/* XPM */
static char *hand_xpm[] = {
	"22 21 19 1",
	"       c None",
	".      c #030305",
	"+      c #7F7F7E",
	"@      c #B5B5B6",
	"#      c #C5C5C6",
	"$      c #969697",
	"%      c #FDFDFB",
	"&      c #F2F2F4",
	"*      c #E5E5E4",
	"=      c #ECECEC",
	"-      c #DCDCDC",
	";      c #D2D2D0",
	">      c #101010",
	",      c #767674",
	"'      c #676767",
	")      c #535355",
	"!      c #323234",
	"~      c #3E3C56",
	"{      c #333147",
	"                      ",
	"       .....          ",
	"     ..+@##$.         ",
	"    .%%%&@..........  ",
	"   .%*%%&#%%%%%%%%%$. ",
	"  .*#%%%%%%%%%&&&&==. ",
	" .-%%%%%%%%%=*-;;;#$. ",
	" .-%%%%%%%%&..>.....  ",
	" >-%%%%%%%%%*#+.      ",
	" >-%%%%%%%%%*@,.      ",
	" >#%%%%%%%%%*@'.      ",
	" >$&&%%%%%%=...       ",
	" .+@@;=&%%&;$,>       ",
	"  .',$@####$+).       ",
	"   .!',+$++,'.        ",
	"     ..>>>>>.         ",
	"                      ",
	"     ~~{{{~~          ",
	"   {{{{{{{{{{{        ",
	"     ~~{{{~~          ",
	"                      "
};

static const struct {
	const char *key;
	const char *default_value;
	const char *texture_label;	/* text used when displaying the list of textures */
	WMRect      preview;	/* The rectangle where the corresponding object is displayed */
	WMPoint     hand;	/* The coordinate where the hand is drawn when pointing this item */
	const char *popup_label;	/* text used for the popup button with the list of editable items */
} textureOptions[] = {

#define PFOCUSED      0
	{ "FTitleBack", "(solid, black)", N_("[Focused]"),
	  { { 30, 10 }, { 190, 20 } }, { 5, 10 }, N_("Titlebar of Focused Window") },

#define PUNFOCUSED    1
	{ "UTitleBack", "(solid, gray)", N_("[Unfocused]"),
	  { { 30, 40 }, { 190, 20 } }, { 5, 40 }, N_("Titlebar of Unfocused Windows") },

#define POWNER        2
	{ "PTitleBack", "(solid, \"#616161\")", N_("[Owner of Focused]"),
	  { { 30, 70 }, { 190, 20 } }, { 5, 70 }, N_("Titlebar of Focused Window's Owner") },

#define PRESIZEBAR    3
	{ "ResizebarBack", "(solid, gray)", N_("[Resizebar]"),
	  { { 30, 100 }, { 190, 9 } }, { 5, 100 }, N_("Window Resizebar") },

#define PMTITLE       4
	{ "MenuTitleBack", "(solid, black)", N_("[Menu Title]"),
	  { { 30, 120 }, { 90, 20 } }, { 5, 120 }, N_("Titlebar of Menus") },

#define PMITEM        5
	{ "MenuTextBack", "(solid, gray)", N_("[Menu Item]"),
	  { { 30, 140 }, { 90, 20 * 4 } }, { 5, 160 }, N_("Menu Items") },

#define PICON         6
	{ "IconBack", "(solid, gray)", N_("[Icon]"),
	  { { 155, 130 }, { 64, 64 } }, { 130, 150 }, N_("Icon Background") },

#define PBACKGROUND   7
	{ "WorkspaceBack", "(solid, black)", N_("[Background]"),
	  { { -1, -1}, { 0, 0 } }, { -22, -21 }, N_("Workspace Background") }
};
#define EVERYTHING    0xff


enum {
	RESIZEBAR_BEVEL	= -1,
	MENU_BEVEL = -2
};

enum {
	TEXPREV_WIDTH = 40,
	TEXPREV_HEIGHT = 24
};

enum {
	FTITLE_COL,
	UTITLE_COL,
	OTITLE_COL,
	MTITLE_COL,
	MITEM_COL,
	MDISAB_COL,
	MHIGH_COL,
	MHIGHT_COL,
	FFBORDER_COL,
	FBORDER_COL,
	FSBORDER_COL,
	ICONT_COL,
	ICONB_COL,
	CLIP_COL,
	CCLIP_COL
};


static void str2rcolor(RContext * rc, const char *name, RColor * color)
{
	XColor xcolor;

	XParseColor(rc->dpy, rc->cmap, name, &xcolor);

	color->alpha = 255;
	color->red = xcolor.red >> 8;
	color->green = xcolor.green >> 8;
	color->blue = xcolor.blue >> 8;
}

static void dumpRImage(const char *path, RImage * image)
{
	FILE *f;
	int channels = (image->format == RRGBAFormat ? 4 : 3);

	f = fopen(path, "wb");
	if (!f) {
		werror("%s", path);
		return;
	}
	fprintf(f, "%02x%02x%1x", image->width, image->height, channels);

	fwrite(image->data, 1, image->width * image->height * channels, f);

	fsync(fileno(f));
	if (fclose(f) < 0) {
		werror("%s", path);
	}
}

static int isPixmap(WMPropList * prop)
{
	WMPropList *p;
	char *s;

	p = WMGetFromPLArray(prop, 0);
	s = WMGetFromPLString(p);
	if (strcasecmp(&s[1], "pixmap") == 0)
		return 1;
	else
		return 0;
}

/**********************************************************************/

static void drawResizebarBevel(RImage * img)
{
	RColor light;
	RColor dark;
	int width = img->width;
	int height = img->height;
	int cwidth = 28;

	light.alpha = 0;
	light.red = light.green = light.blue = 80;

	dark.alpha = 0;
	dark.red = dark.green = dark.blue = 40;

	ROperateLine(img, RSubtractOperation, 0, 0, width - 1, 0, &dark);
	ROperateLine(img, RAddOperation, 0, 1, width - 1, 1, &light);

	ROperateLine(img, RSubtractOperation, cwidth, 2, cwidth, height - 1, &dark);
	ROperateLine(img, RAddOperation, cwidth + 1, 2, cwidth + 1, height - 1, &light);

	ROperateLine(img, RSubtractOperation, width - cwidth - 2, 2, width - cwidth - 2, height - 1, &dark);
	ROperateLine(img, RAddOperation, width - cwidth - 1, 2, width - cwidth - 1, height - 1, &light);

}

static void drawMenuBevel(RImage * img)
{
	RColor light, dark, mid;
	int i;
	int iheight = img->height / 4;

	light.alpha = 0;
	light.red = light.green = light.blue = 80;

	dark.alpha = 255;
	dark.red = dark.green = dark.blue = 0;

	mid.alpha = 0;
	mid.red = mid.green = mid.blue = 40;

	for (i = 1; i < 4; i++) {
		ROperateLine(img, RSubtractOperation, 0, i * iheight - 2, img->width - 1, i * iheight - 2, &mid);

		RDrawLine(img, 0, i * iheight - 1, img->width - 1, i * iheight - 1, &dark);

		ROperateLine(img, RAddOperation, 1, i * iheight, img->width - 2, i * iheight, &light);
	}
}

static Pixmap renderTexture(WMScreen * scr, WMPropList * texture, int width, int height, const char *path, int border)
{
	char *type;
	RImage *image = NULL;
	RImage *timage = NULL;
	Pixmap pixmap;
	RContext *rc = WMScreenRContext(scr);
	char *str;
	RColor rcolor;

	type = WMGetFromPLString(WMGetFromPLArray(texture, 0));

	if (strcasecmp(&type[1], "pixmap") == 0 ||
	    (strcasecmp(&type[2], "gradient") == 0 && toupper(type[0]) == 'T')) {
		char *path;

		str = WMGetFromPLString(WMGetFromPLArray(texture, 1));
		path = wfindfileinarray(GetObjectForKey("PixmapPath"), str);
		if (path) {
			timage = RLoadImage(rc, path, 0);
			if (!timage)
				wwarning(_("could not load file '%s': %s"), path, RMessageForError(RErrorCode));
			wfree(path);
		} else {
			wwarning(_("could not find file '%s' for texture type %s"), str, type);
			timage = NULL;
		}
		if (!timage) {
			texture = WMCreatePropListFromDescription("(solid, black)");
			type = "solid";
		}
	}

	if (strcasecmp(type, "solid") == 0) {

		str = WMGetFromPLString(WMGetFromPLArray(texture, 1));

		str2rcolor(rc, str, &rcolor);

		image = RCreateImage(width, height, False);
		RClearImage(image, &rcolor);
	} else if (strcasecmp(type, "igradient") == 0) {
		int t1, t2;
		RColor c1[2], c2[2];

		str = WMGetFromPLString(WMGetFromPLArray(texture, 1));
		str2rcolor(rc, str, &c1[0]);
		str = WMGetFromPLString(WMGetFromPLArray(texture, 2));
		str2rcolor(rc, str, &c1[1]);
		str = WMGetFromPLString(WMGetFromPLArray(texture, 3));
		t1 = atoi(str);

		str = WMGetFromPLString(WMGetFromPLArray(texture, 4));
		str2rcolor(rc, str, &c2[0]);
		str = WMGetFromPLString(WMGetFromPLArray(texture, 5));
		str2rcolor(rc, str, &c2[1]);
		str = WMGetFromPLString(WMGetFromPLArray(texture, 6));
		t2 = atoi(str);

		image = RRenderInterwovenGradient(width, height, c1, t1, c2, t2);
	} else if (strcasecmp(&type[1], "gradient") == 0) {
		RGradientStyle style;
		RColor rcolor2;

		switch (toupper(type[0])) {
		case 'V':
			style = RVerticalGradient;
			break;
		case 'H':
			style = RHorizontalGradient;
			break;
		default:
			wwarning(_("unknown direction in '%s', falling back to diagonal"), type);
		case 'D':
			style = RDiagonalGradient;
			break;
		}

		str = WMGetFromPLString(WMGetFromPLArray(texture, 1));
		str2rcolor(rc, str, &rcolor);
		str = WMGetFromPLString(WMGetFromPLArray(texture, 2));
		str2rcolor(rc, str, &rcolor2);

		image = RRenderGradient(width, height, &rcolor, &rcolor2, style);
	} else if (strcasecmp(&type[2], "gradient") == 0 && toupper(type[0]) == 'T') {
		RGradientStyle style;
		RColor rcolor2;
		int i;
		RImage *grad = NULL;

		switch (toupper(type[1])) {
		case 'V':
			style = RVerticalGradient;
			break;
		case 'H':
			style = RHorizontalGradient;
			break;
		default:
			wwarning(_("unknown direction in '%s', falling back to diagonal"), type);
		case 'D':
			style = RDiagonalGradient;
			break;
		}

		str = WMGetFromPLString(WMGetFromPLArray(texture, 3));
		str2rcolor(rc, str, &rcolor);
		str = WMGetFromPLString(WMGetFromPLArray(texture, 4));
		str2rcolor(rc, str, &rcolor2);

		grad = RRenderGradient(width, height, &rcolor, &rcolor2, style);

		image = RMakeTiledImage(timage, width, height);
		RReleaseImage(timage);

		i = atoi(WMGetFromPLString(WMGetFromPLArray(texture, 2)));

		RCombineImagesWithOpaqueness(image, grad, i);
		RReleaseImage(grad);

	} else if (strcasecmp(&type[2], "gradient") == 0 && toupper(type[0]) == 'M') {
		RGradientStyle style;
		RColor **colors;
		int i, j;

		switch (toupper(type[1])) {
		case 'V':
			style = RVerticalGradient;
			break;
		case 'H':
			style = RHorizontalGradient;
			break;
		default:
			wwarning(_("unknown direction in '%s', falling back to diagonal"), type);
		case 'D':
			style = RDiagonalGradient;
			break;
		}

		j = WMGetPropListItemCount(texture);

		if (j > 0) {
			colors = wmalloc(j * sizeof(RColor *));

			for (i = 2; i < j; i++) {
				str = WMGetFromPLString(WMGetFromPLArray(texture, i));
				colors[i - 2] = wmalloc(sizeof(RColor));
				str2rcolor(rc, str, colors[i - 2]);
			}
			colors[i - 2] = NULL;

			image = RRenderMultiGradient(width, height, colors, style);

			for (i = 0; colors[i] != NULL; i++)
				wfree(colors[i]);
			wfree(colors);
		}
	} else if (strcasecmp(&type[1], "pixmap") == 0) {
		RColor color;

		str = WMGetFromPLString(WMGetFromPLArray(texture, 2));
		str2rcolor(rc, str, &color);

		switch (toupper(type[0])) {
		case 'T':
			image = RMakeTiledImage(timage, width, height);
			RReleaseImage(timage);
			break;
		case 'C':
			image = RMakeCenteredImage(timage, width, height, &color);
			RReleaseImage(timage);
			break;
		case 'F':
		case 'S':
		case 'M':
			image = RScaleImage(timage, width, height);
			RReleaseImage(timage);
			break;

		default:
			wwarning(_("type '%s' is not a supported type for a texture"), type);
			RReleaseImage(timage);
			return None;
		}
	}

	if (!image)
		return None;

	if (path) {
		dumpRImage(path, image);
	}

	if (border < 0) {
		if (border == RESIZEBAR_BEVEL) {
			drawResizebarBevel(image);
		} else if (border == MENU_BEVEL) {
			drawMenuBevel(image);
			RBevelImage(image, RBEV_RAISED2);
		}
	} else if (border) {
		RBevelImage(image, border);
	}

	RConvertImage(rc, image, &pixmap);
	RReleaseImage(image);

	return pixmap;
}

static Pixmap renderMenu(_Panel * panel, WMPropList * texture, int width, int iheight)
{
	WMScreen *scr = WMWidgetScreen(panel->parent);
	Display *dpy = WMScreenDisplay(scr);
	Pixmap pix, tmp;
	GC gc = XCreateGC(dpy, WMWidgetXID(panel->parent), 0, NULL);
	int i;

	switch (panel->menuStyle) {
	case MSTYLE_NORMAL:
		tmp = renderTexture(scr, texture, width, iheight, NULL, RBEV_RAISED2);

		pix = XCreatePixmap(dpy, tmp, width, iheight * 4, WMScreenDepth(scr));
		for (i = 0; i < 4; i++) {
			XCopyArea(dpy, tmp, pix, gc, 0, 0, width, iheight, 0, iheight * i);
		}
		XFreePixmap(dpy, tmp);
		break;
	case MSTYLE_SINGLE:
		pix = renderTexture(scr, texture, width, iheight * 4, NULL, MENU_BEVEL);
		break;
	case MSTYLE_FLAT:
		pix = renderTexture(scr, texture, width, iheight * 4, NULL, RBEV_RAISED2);
		break;
	default:
		pix = None;
	}
	XFreeGC(dpy, gc);

	return pix;
}

static void renderPreview(_Panel * panel, GC gc, int part, int relief)
{
	WMListItem *item;
	TextureListItem *titem;
	Pixmap pix;
	WMScreen *scr = WMWidgetScreen(panel->box);

	item = WMGetListItem(panel->texLs, panel->textureIndex[part]);
	titem = (TextureListItem *) item->clientData;

	pix = renderTexture(scr, titem->prop,
	                    textureOptions[part].preview.size.width, textureOptions[part].preview.size.height,
	                    NULL, relief);

	XCopyArea(WMScreenDisplay(scr), pix, panel->preview, gc, 0, 0,
	          textureOptions[part].preview.size.width, textureOptions[part].preview.size.height,
	          textureOptions[part].preview.pos.x, textureOptions[part].preview.pos.y);

	XCopyArea(WMScreenDisplay(scr), pix, panel->previewNoText, gc, 0, 0,
	          textureOptions[part].preview.size.width, textureOptions[part].preview.size.height,
	          textureOptions[part].preview.pos.x, textureOptions[part].preview.pos.y);

	XFreePixmap(WMScreenDisplay(scr), pix);
}

static void updatePreviewBox(_Panel * panel, int elements)
{
	WMScreen *scr = WMWidgetScreen(panel->parent);
	Display *dpy = WMScreenDisplay(scr);
	Pixmap pix;
	GC gc;
	int colorUpdate = 0;

	gc = XCreateGC(dpy, WMWidgetXID(panel->parent), 0, NULL);

	if (panel->preview == None) {
		WMPixmap *p;

		panel->previewNoText = XCreatePixmap(dpy, WMWidgetXID(panel->parent),
						     240 - 4, 215 - 4, WMScreenDepth(scr));
		panel->previewBack = XCreatePixmap(dpy, WMWidgetXID(panel->parent),
						     240 - 4, 215 - 4, WMScreenDepth(scr));

		p = WMCreatePixmap(scr, 240 - 4, 215 - 4, WMScreenDepth(scr), False);
		panel->preview = WMGetPixmapXID(p);
		WMSetLabelImage(panel->prevL, p);
		WMReleasePixmap(p);
	}
	if  (elements & (1 << PBACKGROUND)) {
		Pixmap tmp;
		TextureListItem *titem;
		WMListItem *item;

		item = WMGetListItem(panel->texLs,
				     panel->textureIndex[PBACKGROUND]);
		titem = (TextureListItem *) item->clientData;
		tmp = renderTexture(scr, titem->prop, 240 - 4, 215 - 4, NULL, 0);

		XCopyArea(dpy, tmp, panel->preview, gc, 0, 0, 240 - 4, 215 -4 , 0, 0);
		XCopyArea(dpy, tmp, panel->previewNoText, gc, 0, 0, 240 - 4, 215 -4 , 0, 0);
		XCopyArea(dpy, tmp, panel->previewBack, gc, 0, 0, 240 - 4, 215 -4 , 0, 0);
		XFreePixmap(dpy, tmp);
	}

	if (elements & (1 << PFOCUSED)) {
		renderPreview(panel, gc, PFOCUSED, RBEV_RAISED2);
		colorUpdate |= 1 << FTITLE_COL | 1 << FFBORDER_COL;
	}
	if (elements & (1 << PUNFOCUSED)) {
		renderPreview(panel, gc, PUNFOCUSED, RBEV_RAISED2);
		colorUpdate |= 1 << UTITLE_COL | 1 << FBORDER_COL;
	}
	if (elements & (1 << POWNER)) {
		renderPreview(panel, gc, POWNER, RBEV_RAISED2);
		colorUpdate |= 1 << OTITLE_COL | 1 << FBORDER_COL;
	}
	if (elements & (1 << PRESIZEBAR)) {
		renderPreview(panel, gc, PRESIZEBAR, RESIZEBAR_BEVEL);
		colorUpdate |= 1 << FBORDER_COL;
	}
	if (elements & (1 << PMTITLE)) {
		renderPreview(panel, gc, PMTITLE, RBEV_RAISED2);
		colorUpdate |= 1 << MTITLE_COL | 1 << FBORDER_COL;
	}
	if (elements & (1 << PMITEM)) {
		WMListItem *item;
		TextureListItem *titem;

		item = WMGetListItem(panel->texLs, panel->textureIndex[5]);
		titem = (TextureListItem *) item->clientData;

		pix = renderMenu(panel, titem->prop,
		                 textureOptions[PMITEM].preview.size.width,
		                 textureOptions[PMITEM].preview.size.height / 4);

		XCopyArea(dpy, pix, panel->preview, gc, 0, 0,
		          textureOptions[PMITEM].preview.size.width, textureOptions[PMITEM].preview.size.height,
		          textureOptions[PMITEM].preview.pos.x, textureOptions[PMITEM].preview.pos.y);

		XCopyArea(dpy, pix, panel->previewNoText, gc, 0, 0,
			  textureOptions[PMITEM].preview.size.width, textureOptions[PMITEM].preview.size.height,
			  textureOptions[PMITEM].preview.pos.x, textureOptions[PMITEM].preview.pos.y);

		XFreePixmap(dpy, pix);

		colorUpdate |= 1 << MITEM_COL | 1 << MDISAB_COL |
			1 << MHIGH_COL | 1 << MHIGHT_COL |
			1 << FBORDER_COL;
	}
	if (elements & (1 << PICON)) {
		WMListItem *item;
		TextureListItem *titem;

		item = WMGetListItem(panel->texLs, panel->textureIndex[6]);
		titem = (TextureListItem *) item->clientData;

		renderPreview(panel, gc, PICON, titem->ispixmap ? 0 : RBEV_RAISED3);
	}

	if (colorUpdate)
		updateColorPreviewBox(panel, colorUpdate);
	else
		WMRedisplayWidget(panel->prevL);

	XFreeGC(dpy, gc);
}

static void cancelNewTexture(void *data)
{
	_Panel *panel = (_Panel *) data;

	HideTexturePanel(panel->texturePanel);
}

static char *makeFileName(const char *prefix)
{
	char *fname;

	fname = wstrdup(prefix);

	while (access(fname, F_OK) == 0) {
		char buf[30];

		wfree(fname);
		sprintf(buf, "%08lx.cache", time(NULL));
		fname = wstrconcat(prefix, buf);
	}

	return fname;
}

static void okNewTexture(void *data)
{
	_Panel *panel = (_Panel *) data;
	WMListItem *item;
	char *name;
	char *str;
	WMPropList *prop;
	TextureListItem *titem;
	WMScreen *scr = WMWidgetScreen(panel->parent);

	titem = wmalloc(sizeof(TextureListItem));

	HideTexturePanel(panel->texturePanel);

	name = GetTexturePanelTextureName(panel->texturePanel);

	prop = GetTexturePanelTexture(panel->texturePanel);

	str = WMGetPropListDescription(prop, False);

	titem->title = name;
	titem->prop = prop;
	titem->texture = str;
	titem->selectedFor = 0;

	titem->ispixmap = isPixmap(prop);

	titem->path = makeFileName(panel->fprefix);
	titem->preview = renderTexture(scr, prop, TEXPREV_WIDTH, TEXPREV_HEIGHT, titem->path, 0);

	item = WMAddListItem(panel->texLs, "");
	item->clientData = titem;

	WMSetListPosition(panel->texLs, WMGetListNumberOfRows(panel->texLs));
}

static void okEditTexture(void *data)
{
	_Panel *panel = (_Panel *) data;
	WMListItem *item;
	char *name;
	char *str;
	WMPropList *prop;
	TextureListItem *titem;

	item = WMGetListItem(panel->texLs, WMGetListSelectedItemRow(panel->texLs));
	titem = (TextureListItem *) item->clientData;

	HideTexturePanel(panel->texturePanel);

	if (titem->current) {
		name = GetTexturePanelTextureName(panel->texturePanel);

		wfree(titem->title);
		titem->title = name;
	}

	prop = GetTexturePanelTexture(panel->texturePanel);

	str = WMGetPropListDescription(prop, False);

	WMReleasePropList(titem->prop);
	titem->prop = prop;

	titem->ispixmap = isPixmap(prop);

	wfree(titem->texture);
	titem->texture = str;

	XFreePixmap(WMScreenDisplay(WMWidgetScreen(panel->texLs)), titem->preview);
	titem->preview = renderTexture(WMWidgetScreen(panel->texLs), titem->prop,
				       TEXPREV_WIDTH, TEXPREV_HEIGHT, titem->path, 0);

	WMRedisplayWidget(panel->texLs);

	if (titem->selectedFor) {
		if (titem->selectedFor & (1 << PBACKGROUND))
			updatePreviewBox(panel, EVERYTHING);
		else
			updatePreviewBox(panel, titem->selectedFor);
	}

	changePage(panel->secP, panel);
}

static void editTexture(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	WMListItem *item;
	TextureListItem *titem;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	item = WMGetListItem(panel->texLs, WMGetListSelectedItemRow(panel->texLs));
	titem = (TextureListItem *) item->clientData;

	SetTexturePanelPixmapPath(panel->texturePanel, GetObjectForKey("PixmapPath"));

	SetTexturePanelTexture(panel->texturePanel, titem->title, titem->prop);

	SetTexturePanelCancelAction(panel->texturePanel, cancelNewTexture, panel);
	SetTexturePanelOkAction(panel->texturePanel, okEditTexture, panel);

	ShowTexturePanel(panel->texturePanel);
}

static void newTexture(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	SetTexturePanelPixmapPath(panel->texturePanel, GetObjectForKey("PixmapPath"));

	SetTexturePanelTexture(panel->texturePanel, "New Texture", NULL);

	SetTexturePanelCancelAction(panel->texturePanel, cancelNewTexture, panel);

	SetTexturePanelOkAction(panel->texturePanel, okNewTexture, panel);

	ShowTexturePanel(panel->texturePanel);
}

static void deleteTexture(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	WMListItem *item;
	TextureListItem *titem;
	int row;
	int section;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	section = WMGetPopUpButtonSelectedItem(panel->secP);
	row = WMGetListSelectedItemRow(panel->texLs);
	item = WMGetListItem(panel->texLs, row);
	titem = (TextureListItem *) item->clientData;

	if (titem->selectedFor & (1 << section)) {
		TextureListItem *titem2;

		panel->textureIndex[section] = section;
		item = WMGetListItem(panel->texLs, section);
		titem2 = (TextureListItem *) item->clientData;
		titem2->selectedFor |= 1 << section;
	}

	wfree(titem->title);
	wfree(titem->texture);
	WMReleasePropList(titem->prop);
	if (titem->path) {
		if (remove(titem->path) < 0 && errno != ENOENT) {
			werror(_("could not remove file %s"), titem->path);
		}
		wfree(titem->path);
	}

	wfree(titem);

	WMRemoveListItem(panel->texLs, row);
	WMSetButtonEnabled(panel->delB, False);
}

static void extractTexture(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	char *path;
	WMOpenPanel *opanel;
	WMScreen *scr = WMWidgetScreen(w);

	opanel = WMGetOpenPanel(scr);
	WMSetFilePanelCanChooseDirectories(opanel, False);
	WMSetFilePanelCanChooseFiles(opanel, True);

	if (WMRunModalFilePanelForDirectory(opanel, panel->parent, wgethomedir(), _("Select File"), NULL)) {
		path = WMGetFilePanelFileName(opanel);

		OpenExtractPanelFor(panel);

		wfree(path);
	}
}

static void changePage(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	int section;
	WMScreen *scr = WMWidgetScreen(panel->box);
	RContext *rc = WMScreenRContext(scr);

	if (w) {
		section = WMGetPopUpButtonSelectedItem(panel->secP);

		WMSelectListItem(panel->texLs, panel->textureIndex[section]);

		WMSetListPosition(panel->texLs, panel->textureIndex[section] - 2);
	}
	{
		GC gc;

		gc = XCreateGC(rc->dpy, WMWidgetXID(panel->parent), 0, NULL);
		XCopyArea(rc->dpy, panel->previewBack, panel->preview, gc,
		          textureOptions[panel->oldsection].hand.x, textureOptions[panel->oldsection].hand.y, 22, 22,
		          textureOptions[panel->oldsection].hand.x, textureOptions[panel->oldsection].hand.y);
	}
	if (w) {
		panel->oldsection = section;
		WMDrawPixmap(panel->hand, panel->preview, textureOptions[section].hand.x, textureOptions[section].hand.y);
	}
	WMRedisplayWidget(panel->prevL);
}

static void previewClick(XEvent * event, void *clientData)
{
	_Panel *panel = (_Panel *) clientData;
	int i;

	switch (panel->oldTabItem) {
	case 0:
		for (i = 0; i < wlengthof(textureOptions); i++) {
			if (event->xbutton.x >= textureOptions[i].preview.pos.x &&
			    event->xbutton.y >= textureOptions[i].preview.pos.y &&
			    event->xbutton.x < textureOptions[i].preview.pos.x + textureOptions[i].preview.size.width &&
			    event->xbutton.y < textureOptions[i].preview.pos.y + textureOptions[i].preview.size.height) {

				WMSetPopUpButtonSelectedItem(panel->secP, i);
				changePage(panel->secP, panel);
				return;
			}
		}
		break;
	case 1:
		for (i = 0; i < WMGetPopUpButtonNumberOfItems(panel->colP); i++) {
			if (event->xbutton.x >= colorOptions[i].preview.pos.x &&
			    event->xbutton.y >= colorOptions[i].preview.pos.y &&
			    event->xbutton.x < colorOptions[i].preview.pos.x + colorOptions[i].preview.size.width &&
			    event->xbutton.y < colorOptions[i].preview.pos.y + colorOptions[i].preview.size.height) {

				/*
				 * yuck kluge: the entry #7 is HighlightTextColor which does not have actually a
				 * display area, but are reused to make the last "Normal Item" menu entry actually
				 * pick the same color item as the other similar item displayed, which corresponds
				 * to MenuTextColor
				 */
				if (i == 7)
					i = 4;

				WMSetPopUpButtonSelectedItem(panel->colP, i);
				changeColorPage(panel->colP, panel);
				return;
			}
		}
		break;
	}
}

static void textureClick(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	int i;
	WMListItem *item;
	TextureListItem *titem;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	i = WMGetListSelectedItemRow(panel->texLs);

	item = WMGetListItem(panel->texLs, i);

	titem = (TextureListItem *) item->clientData;

	if (titem->current) {
		WMSetButtonEnabled(panel->delB, False);
	} else {
		WMSetButtonEnabled(panel->delB, True);
	}
}

static void textureDoubleClick(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	int i, section;
	WMListItem *item;
	TextureListItem *titem;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) w;

	/* unselect old texture */
	section = WMGetPopUpButtonSelectedItem(panel->secP);

	item = WMGetListItem(panel->texLs, panel->textureIndex[section]);
	titem = (TextureListItem *) item->clientData;
	titem->selectedFor &= ~(1 << section);

	/* select new texture */
	i = WMGetListSelectedItemRow(panel->texLs);

	item = WMGetListItem(panel->texLs, i);

	titem = (TextureListItem *) item->clientData;

	titem->selectedFor |= 1 << section;

	panel->textureIndex[section] = i;

	WMRedisplayWidget(panel->texLs);

	if (section == PBACKGROUND)
		updatePreviewBox(panel, EVERYTHING);
	else
		updatePreviewBox(panel, 1 << section);
}

static void paintListItem(WMList * lPtr, int index, Drawable d, char *text, int state, WMRect * rect)
{
	_Panel *panel = (_Panel *) WMGetHangedData(lPtr);
	WMScreen *scr = WMWidgetScreen(lPtr);
	int width, height, x, y;
	Display *dpy = WMScreenDisplay(scr);
	WMColor *back = (state & WLDSSelected) ? WMWhiteColor(scr) : WMGrayColor(scr);
	WMListItem *item;
	WMColor *black = WMBlackColor(scr);
	TextureListItem *titem;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) text;

	item = WMGetListItem(lPtr, index);
	titem = (TextureListItem *) item->clientData;
	if (!titem) {
		WMReleaseColor(back);
		WMReleaseColor(black);
		return;
	}

	width = rect->size.width;
	height = rect->size.height;
	x = rect->pos.x;
	y = rect->pos.y;

	XFillRectangle(dpy, d, WMColorGC(back), x, y, width, height);

	if (titem->preview)
		XCopyArea(dpy, titem->preview, d, WMColorGC(black), 0, 0,
			  TEXPREV_WIDTH, TEXPREV_HEIGHT, x + 5, y + 5);

	if ((1 << WMGetPopUpButtonSelectedItem(panel->secP)) & titem->selectedFor)
		WMDrawPixmap(panel->onLed, d, x + TEXPREV_WIDTH + 10, y + 6);
	else if (titem->selectedFor)
		WMDrawPixmap(panel->offLed, d, x + TEXPREV_WIDTH + 10, y + 6);

	WMDrawString(scr, d, black, panel->boldFont,
		     x + TEXPREV_WIDTH + 22, y + 2, titem->title, strlen(titem->title));

	WMDrawString(scr, d, black, panel->smallFont,
		     x + TEXPREV_WIDTH + 14, y + 18, titem->texture, strlen(titem->texture));

	WMReleaseColor(back);
	WMReleaseColor(black);
}

static Pixmap loadRImage(WMScreen * scr, const char *path)
{
	FILE *f;
	RImage *image;
	int w, h, d, cnt;
	size_t read_size;
	Pixmap pixmap;

	f = fopen(path, "rb");
	if (!f)
		return None;

	cnt = fscanf(f, "%02x%02x%1x", &w, &h, &d);
	if (cnt != 3) {
		wwarning(_("could not read size of image from '%s', ignoring"), path);
		fclose(f);
		return None;
	}
	if (d < 3 || d > 4) {
		wwarning(_("image \"%s\" has an invalid depth of %d, ignoring"), path, d);
		fclose(f);
		return None;
	}
	image = RCreateImage(w, h, d == 4);
	if (image == NULL) {
		wwarning(_("could not create RImage for \"%s\": %s"),
		         path, RMessageForError(RErrorCode));
		fclose(f);
		return None;
	}
	read_size = w * h * d;
	if (fread(image->data, 1, read_size, f) == read_size)
		RConvertImage(WMScreenRContext(scr), image, &pixmap);
	else
		pixmap = None;

	fclose(f);

	RReleaseImage(image);

	return pixmap;
}

static void fillTextureList(WMList * lPtr)
{
	WMPropList *textureList;
	WMPropList *texture;
	WMUserDefaults *udb = WMGetStandardUserDefaults();
	TextureListItem *titem;
	WMScreen *scr = WMWidgetScreen(lPtr);
	int i;

	textureList = WMGetUDObjectForKey(udb, "TextureList");
	if (!textureList)
		return;

	for (i = 0; i < WMGetPropListItemCount(textureList); i++) {
		WMListItem *item;

		texture = WMGetFromPLArray(textureList, i);

		titem = wmalloc(sizeof(TextureListItem));

		titem->title = wstrdup(WMGetFromPLString(WMGetFromPLArray(texture, 0)));
		titem->prop = WMRetainPropList(WMGetFromPLArray(texture, 1));
		titem->texture = WMGetPropListDescription(titem->prop, False);
		titem->selectedFor = 0;
		titem->path = wstrdup(WMGetFromPLString(WMGetFromPLArray(texture, 2)));

		titem->preview = loadRImage(scr, titem->path);
		if (!titem->preview) {
			titem->preview = renderTexture(scr, titem->prop, TEXPREV_WIDTH, TEXPREV_HEIGHT, NULL, 0);
		}
		item = WMAddListItem(lPtr, "");
		item->clientData = titem;
	}
}

static void fillColorList(_Panel * panel)
{
	WMColor *color;
	WMPropList *list;
	WMUserDefaults *udb = WMGetStandardUserDefaults();
	WMScreen *scr = WMWidgetScreen(panel->box);
	int i;

	list = WMGetUDObjectForKey(udb, "ColorList");
	if (!list) {
		for (i = 0; i < wlengthof(sample_colors); i++) {
			color = WMCreateNamedColor(scr, sample_colors[i], False);
			if (!color)
				continue;
			WMSetColorWellColor(panel->sampW[i], color);
			WMReleaseColor(color);
		}
	} else {
		WMPropList *c;

		for (i = 0; i < WMIN(wlengthof(sample_colors), WMGetPropListItemCount(list)); i++) {
			c = WMGetFromPLArray(list, i);
			if (!c || !WMIsPLString(c))
				continue;
			color = WMCreateNamedColor(scr, WMGetFromPLString(c), False);
			if (!color)
				continue;
			WMSetColorWellColor(panel->sampW[i], color);
			WMReleaseColor(color);
		}
	}
}

/*************************************************************************/

static void changeColorPage(WMWidget * w, void *data)
{
	_Panel *panel = (_Panel *) data;
	int section;
	WMScreen *scr = WMWidgetScreen(panel->box);
	RContext *rc = WMScreenRContext(scr);

	if (panel->preview) {
		GC gc;

		gc = XCreateGC(rc->dpy, WMWidgetXID(panel->parent), 0, NULL);
		XCopyArea(rc->dpy, panel->previewBack, panel->preview, gc,
			  colorOptions[panel->oldcsection].hand.x,
			  colorOptions[panel->oldcsection].hand.y, 22, 22 ,
			  colorOptions[panel->oldcsection].hand.x,
			  colorOptions[panel->oldcsection].hand.y);
	}
	if (w) {
		section = WMGetPopUpButtonSelectedItem(panel->colP);

		panel->oldcsection = section;
		if (panel->preview)
			WMDrawPixmap(panel->hand, panel->preview,
			             colorOptions[section].hand.x, colorOptions[section].hand.y);

		if (section >= ICONT_COL)
			updateColorPreviewBox(panel, 1 << section);

		WMSetColorWellColor(panel->colW, panel->colors[section]);
	}
	WMRedisplayWidget(panel->prevL);
}

static void
paintText(WMScreen * scr, Drawable d, WMColor * color, WMFont * font,
	  int x, int y, int w, int h, WMAlignment align, char *text)
{
	int l = strlen(text);

	switch (align) {
	case WALeft:
		x += 5;
		break;
	case WARight:
		x += w - 5 - WMWidthOfString(font, text, l);
		break;
	default:
	case WACenter:
		x += (w - WMWidthOfString(font, text, l)) / 2;
		break;
	}
	WMDrawString(scr, d, color, font, x, y + (h - WMFontHeight(font)) / 2, text, l);
}

static void updateColorPreviewBox(_Panel * panel, int elements)
{
	WMScreen *scr = WMWidgetScreen(panel->box);
	Display *dpy = WMScreenDisplay(scr);
	Pixmap d, pnot;
	GC gc;

	d = panel->preview;
	pnot = panel->previewNoText;
	gc = WMColorGC(panel->colors[FTITLE_COL]);

	if (elements & (1 << FTITLE_COL)) {
		XCopyArea(dpy, pnot, d, gc, 30, 10, 190, 20, 30, 10);
		paintText(scr, d, panel->colors[FTITLE_COL],
			  panel->boldFont, 30, 10, 190, 20,
			  panel->titleAlignment, _("Focused Window"));
	}
	if (elements & (1 << UTITLE_COL)) {
		XCopyArea(dpy, pnot, d, gc, 30, 40, 190, 20, 30, 40);
		paintText(scr, d, panel->colors[UTITLE_COL],
			  panel->boldFont, 30, 40, 190, 20,
			  panel->titleAlignment,
			  _("Unfocused Window"));
	}
	if (elements & (1 << OTITLE_COL)) {
		XCopyArea(dpy, pnot, d, gc, 30, 70, 190, 20, 30, 70);
		paintText(scr, d, panel->colors[OTITLE_COL],
			  panel->boldFont, 30, 70, 190, 20,
			  panel->titleAlignment,
			  _("Owner of Focused Window"));
	}
	if (elements & (1 << MTITLE_COL)) {
		XCopyArea(dpy, pnot, d, gc, 30, 120, 90, 20, 30, 120);
		paintText(scr, d, panel->colors[MTITLE_COL],
			  panel->boldFont, 30, 120, 90, 20, WALeft,
			  _("Menu Title"));
	}
	if (elements & (1 << MITEM_COL)) {
		XCopyArea(dpy, pnot, d, gc, 30, 140, 90, 20, 30, 140);
		paintText(scr, d, panel->colors[MITEM_COL],
			  panel->normalFont, 30, 140, 90, 20, WALeft,
			  _("Normal Item"));
		XCopyArea(dpy, pnot, d, gc, 30, 200, 90, 20, 30, 200);
		paintText(scr, d, panel->colors[MITEM_COL],
			  panel->normalFont, 30, 200, 90, 20, WALeft,
			  _("Normal Item"));
	}
	if (elements & (1 << MDISAB_COL)) {
		XCopyArea(dpy, pnot, d, gc, 30, 160, 90, 20, 30, 160);
		paintText(scr, d, panel->colors[MDISAB_COL],
			  panel->normalFont, 30, 160, 90, 20, WALeft,
			  _("Disabled Item"));
	}
	if (elements & (1 << MHIGH_COL)) {
		XFillRectangle(WMScreenDisplay(scr), d,
			       WMColorGC(panel->colors[MHIGH_COL]),
			       31, 181, 87, 17);
		XFillRectangle(WMScreenDisplay(scr), pnot,
			       WMColorGC(panel->colors[MHIGH_COL]),
			       31, 181, 87, 17);
		elements |= 1 << MHIGHT_COL;
	}
	if (elements & (1 << MHIGHT_COL)) {
		XCopyArea(dpy, pnot, d, gc, 30, 180, 90, 20, 30, 180);
		paintText(scr, d, panel->colors[MHIGHT_COL],
			  panel->normalFont, 30, 180, 90, 20, WALeft,
			  _("Highlighted"));
	}
	if (elements & (1 << FBORDER_COL)) {
		XDrawRectangle(dpy, pnot,
			       WMColorGC(panel->colors[FBORDER_COL]),
			       29, 39, 190, 20);
		XDrawRectangle(dpy, d,
			       WMColorGC(panel->colors[FBORDER_COL]),
			       29, 39, 190, 20);
		XDrawRectangle(dpy, pnot,
			       WMColorGC(panel->colors[FBORDER_COL]),
			       29, 69, 190, 20);
		XDrawRectangle(dpy, d,
			       WMColorGC(panel->colors[FBORDER_COL]),
			       29, 69, 190, 20);
		XDrawLine(dpy, pnot,
			  WMColorGC(panel->colors[FBORDER_COL]),
			  30, 100, 30, 109);
		XDrawLine(dpy, d,
			  WMColorGC(panel->colors[FBORDER_COL]),
			  30, 100, 30, 109);
		XDrawLine(dpy, pnot,
			  WMColorGC(panel->colors[FBORDER_COL]),
			  31, 109, 219, 109);
		XDrawLine(dpy, d,
			  WMColorGC(panel->colors[FBORDER_COL]),
			  31, 109, 219, 109);
		XDrawLine(dpy, pnot,
			  WMColorGC(panel->colors[FBORDER_COL]),
			  220, 100, 220, 109);
		XDrawLine(dpy, d,
			  WMColorGC(panel->colors[FBORDER_COL]),
			  220, 100, 220, 109);
		XDrawLine(dpy, pnot,
			  WMColorGC(panel->colors[FBORDER_COL]),
			  29, 120, 29, 220);
		XDrawLine(dpy, d,
			  WMColorGC(panel->colors[FBORDER_COL]),
			  29, 120, 29, 220);
		XDrawLine(dpy, pnot,
			  WMColorGC(panel->colors[FBORDER_COL]),
			  29, 119, 119, 119);
		XDrawLine(dpy, d,
			  WMColorGC(panel->colors[FBORDER_COL]),
			  29, 119, 119, 119);
		XDrawLine(dpy, pnot,
			  WMColorGC(panel->colors[FBORDER_COL]),
			  119, 120, 119, 220);
		XDrawLine(dpy, d,
			  WMColorGC(panel->colors[FBORDER_COL]),
			  119, 120, 119, 220);
	}

	if (elements & (1 << FFBORDER_COL)) {
		XDrawRectangle(dpy, pnot,
			       WMColorGC(panel->colors[FFBORDER_COL]),
			       29, 9, 190, 20);
		XDrawRectangle(dpy, d,
			       WMColorGC(panel->colors[FFBORDER_COL]),
			       29, 9, 190, 20);
	}

	if (elements & (1 << ICONT_COL) || elements & (1 << ICONB_COL)) {
		RColor rgb;
		RHSVColor hsv, hsv2;
		int v;
		WMColor *light, *dim;

		updatePreviewBox(panel, 1 << PICON);

		rgb.red = WMRedComponentOfColor(panel->colors[ICONB_COL]) >> 8;
		rgb.green = WMGreenComponentOfColor(panel->colors[ICONB_COL]) >> 8;
		rgb.blue = WMBlueComponentOfColor(panel->colors[ICONB_COL]) >> 8;
		RRGBtoHSV(&rgb, &hsv);
		RHSVtoRGB(&hsv, &rgb);
		hsv2 = hsv;

		v = hsv.value * 16 / 10;
		hsv.value = (v > 255 ? 255 : v);
		RHSVtoRGB(&hsv, &rgb);
		light = WMCreateRGBColor(scr, rgb.red << 8, rgb.green << 8, rgb.blue << 8, False);

		hsv2.value = hsv2.value / 2;
		RHSVtoRGB(&hsv2, &rgb);
		dim = WMCreateRGBColor(scr, rgb.red << 8, rgb.green << 8, rgb.blue << 8, False);

		XFillRectangle(dpy, d, WMColorGC(panel->colors[ICONB_COL]), 156, 131, 62, 11);
		XDrawLine(dpy, d, WMColorGC(light), 155, 130, 155, 142);
		XDrawLine(dpy, d, WMColorGC(light), 156, 130, 217, 130);
		XDrawLine(dpy, d, WMColorGC(dim), 218, 130, 218, 142);

		paintText(scr, d, panel->colors[ICONT_COL],
			     panel->smallFont, 155, 130, 64, 13, WALeft,
			     _("Icon Text"));

		WMReleaseColor(light);
		WMReleaseColor(dim);
	}

	if (elements & (1 << CLIP_COL) || elements & (1 << CCLIP_COL)) {
		Pixmap pix;
		RColor black;
		RColor dark;
		RColor light;
		RImage *tile;
		TextureListItem *titem;
		WMListItem *item;
		XPoint p[4];

		item = WMGetListItem(panel->texLs, panel->textureIndex[PICON]);
		titem = (TextureListItem *) item->clientData;

		pix = renderTexture(scr, titem->prop, 64, 64, NULL, titem->ispixmap ? 0 : RBEV_RAISED3);
		tile = RCreateImageFromDrawable(WMScreenRContext(scr), pix, None);

		black.alpha = 255;
		black.red = black.green = black.blue = 0;

		dark.alpha = 0;
		dark.red = dark.green = dark.blue = 60;

		light.alpha = 0;
		light.red = light.green = light.blue = 80;

		/* top right */
		ROperateLine(tile, RSubtractOperation, 64 - 1 - 23, 0, 64 - 2, 23 - 1, &dark);
		RDrawLine(tile, 64 - 1 - 23 - 1, 0, 64 - 1, 23 + 1, &black);
		ROperateLine(tile, RAddOperation, 64 - 1 - 23, 2, 64 - 3, 23, &light);

		/* arrow bevel */
		ROperateLine(tile, RSubtractOperation, 64 - 7 - (23 - 15), 4, 64 - 5, 4, &dark);
		ROperateLine(tile, RSubtractOperation, 64 - 6 - (23 - 15), 5, 64 - 5, 6 + 23 - 15, &dark);
		ROperateLine(tile, RAddOperation, 64 - 5, 4, 64 - 5, 6 + 23 - 15, &light);

		/* bottom left */
		ROperateLine(tile, RAddOperation, 2, 64 - 1 - 23 + 2, 23 - 2, 64 - 3, &dark);
		RDrawLine(tile, 0, 64 - 1 - 23 - 1, 23 + 1, 64 - 1, &black);
		ROperateLine(tile, RSubtractOperation, 0, 64 - 1 - 23 - 2, 23 + 1, 64 - 2, &light);

		/* arrow bevel */
		ROperateLine(tile, RSubtractOperation, 4, 64 - 7 - (23 - 15), 4, 64 - 5, &dark);
		ROperateLine(tile, RSubtractOperation, 5, 64 - 6 - (23 - 15), 6 + 23 - 15, 64 - 5, &dark);
		ROperateLine(tile, RAddOperation, 4, 64 - 5, 6 + 23 - 15, 64 - 5, &light);

		RConvertImage(WMScreenRContext(scr), tile, &pix);
		RReleaseImage(tile);

		XCopyArea(dpy, pix, d, gc, 0, 0, 64, 64, 155, 130);
		XFreePixmap(dpy, pix);

		/* top right arrow */
		p[0].x = p[3].x = 155 + 64 - 5 - (23 - 15);
		p[0].y = p[3].y = 130 + 5;
		p[1].x = 155 + 64 - 6;
		p[1].y = 130 + 5;
		p[2].x = 155 + 64 - 6;
		p[2].y = 130 + 4 + 23 - 15;

		XFillPolygon(dpy, d, WMColorGC(panel->colors[CLIP_COL]), p, 3, Convex, CoordModeOrigin);
		XDrawLines(dpy, d, WMColorGC(panel->colors[CLIP_COL]), p, 4, CoordModeOrigin);

		/* bottom left arrow */
		p[0].x = p[3].x = 155 + 5;
		p[0].y = p[3].y = 130 + 64 - 5 - (23 - 15);
		p[1].x = 155 + 5;
		p[1].y = 130 + 64 - 6;
		p[2].x = 155 + 4 + 23 - 15;
		p[2].y = 130 + 64 - 6;

		XFillPolygon(dpy, d, WMColorGC(panel->colors[CLIP_COL]), p, 3, Convex, CoordModeOrigin);
		XDrawLines(dpy, d, WMColorGC(panel->colors[CLIP_COL]), p, 4, CoordModeOrigin);

	}

	if (elements & (1 << CLIP_COL))
		paintText(scr, d, panel->colors[CLIP_COL],
			  panel->boldFont, 155 + 23, 130 + 64 - 15 - 3, 22, 15, WALeft,
			  _("Clip"));

	if (elements & (1 << CCLIP_COL)) {
		paintText(scr, d, panel->colors[CCLIP_COL],
			  panel->boldFont, 155+2, 130 + 2, 26, 15, WALeft, _("Coll."));
		paintText(scr, d, panel->colors[CCLIP_COL],
			  panel->boldFont, 155 + 23, 130 + 64 - 15 - 3, 22, 15, WALeft,
			  _("Clip"));
	}

	WMRedisplayWidget(panel->prevL);
}

static void colorWellObserver(void *self, WMNotification * n)
{
	_Panel *panel = (_Panel *) self;
	int p;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) n;

	p = WMGetPopUpButtonSelectedItem(panel->colP);

	WMReleaseColor(panel->colors[p]);

	panel->colors[p] = WMRetainColor(WMGetColorWellColor(panel->colW));

	updateColorPreviewBox(panel, 1 << p);
}

static void changedTabItem(struct WMTabViewDelegate *self, WMTabView * tabView, WMTabViewItem * item)
{
	_Panel *panel = self->data;
	int i;

	/* Parameter not used, but tell the compiler that it is ok */
	(void) tabView;

	i = WMGetTabViewItemIdentifier(item);
	switch (i) {
	case TAB_TEXTURE:
		switch (panel->oldTabItem) {
		case TAB_COLOR:
			changeColorPage(NULL, panel);
			break;
		}
		changePage(panel->secP, panel);
		break;
	case TAB_COLOR:
		switch (panel->oldTabItem) {
		case TAB_TEXTURE:
			changePage(NULL, panel);
			break;
		}
		changeColorPage(panel->colP, panel);
		break;
	case TAB_OPTIONS:
		switch (panel->oldTabItem) {
		case TAB_TEXTURE:
			changePage(NULL, panel);
			break;
		case TAB_COLOR:
			changeColorPage(NULL, panel);
			break;
		}
		break;
	}

	panel->oldTabItem = i;
}

/*************************************************************************/

static void menuStyleCallback(WMWidget * self, void *data)
{
	_Panel *panel = (_Panel *) data;
	menu_style_index i;

	for (i = 0; i < wlengthof(menu_style); i++) {
		if (self == panel->mstyB[i]) {
			panel->menuStyle = i;
			break;
		}
	}

	updatePreviewBox(panel, 1 << PMITEM);
}

static void titleAlignCallback(WMWidget * self, void *data)
{
	_Panel *panel = (_Panel *) data;
	WMAlignment align;

	for (align = 0; align < wlengthof(wintitle_align); align++) {
		if (self == panel->taliB[align]) {
			panel->titleAlignment = align;
			break;
		}
	}

	updatePreviewBox(panel, 1 << PFOCUSED | 1 << PUNFOCUSED | 1 << POWNER);
}

static void createPanel(Panel * p)
{
	_Panel *panel = (_Panel *) p;
	WMFont *font;
	WMScreen *scr = WMWidgetScreen(panel->parent);
	WMTabViewItem *item;
	int i;
	char *tmp;
	Bool ok = True;

	panel->fprefix = wstrconcat(wusergnusteppath(), "/Library/WindowMaker");

	if (access(panel->fprefix, F_OK) != 0) {
		if (mkdir(panel->fprefix, 0755) < 0) {
			werror("%s", panel->fprefix);
			ok = False;
		}
	}
	if (ok) {
		tmp = wstrconcat(panel->fprefix, "/WPrefs/");
		wfree(panel->fprefix);
		panel->fprefix = tmp;
		if (access(panel->fprefix, F_OK) != 0) {
			if (mkdir(panel->fprefix, 0755) < 0) {
				werror("%s", panel->fprefix);
			}
		}
	}

	panel->smallFont = WMSystemFontOfSize(scr, 10);
	panel->normalFont = WMSystemFontOfSize(scr, 12);
	panel->boldFont = WMBoldSystemFontOfSize(scr, 12);

	panel->onLed = WMCreatePixmapFromXPMData(scr, blueled_xpm);
	panel->offLed = WMCreatePixmapFromXPMData(scr, blueled2_xpm);
	panel->hand = WMCreatePixmapFromXPMData(scr, hand_xpm);

	panel->box = WMCreateBox(panel->parent);
	WMSetViewExpandsToParent(WMWidgetView(panel->box), 2, 2, 2, 2);

	/* preview box */
	panel->prevL = WMCreateLabel(panel->box);
	WMResizeWidget(panel->prevL, 240, FRAME_HEIGHT - 20);
	WMMoveWidget(panel->prevL, 15, 10);
	WMSetLabelRelief(panel->prevL, WRSunken);
	WMSetLabelImagePosition(panel->prevL, WIPImageOnly);

	WMCreateEventHandler(WMWidgetView(panel->prevL), ButtonPressMask, previewClick, panel);

	/* tabview */

	tabviewDelegate.data = panel;

	panel->tabv = WMCreateTabView(panel->box);
	WMResizeWidget(panel->tabv, 245, FRAME_HEIGHT - 20);
	WMMoveWidget(panel->tabv, 265, 10);
	WMSetTabViewDelegate(panel->tabv, &tabviewDelegate);

    /*** texture list ***/

	panel->texF = WMCreateFrame(panel->box);
	WMSetFrameRelief(panel->texF, WRFlat);

	item = WMCreateTabViewItemWithIdentifier(TAB_TEXTURE);
	WMSetTabViewItemView(item, WMWidgetView(panel->texF));
	WMSetTabViewItemLabel(item, _("Texture"));

	WMAddItemInTabView(panel->tabv, item);

	panel->secP = WMCreatePopUpButton(panel->texF);
	WMResizeWidget(panel->secP, 228, 20);
	WMMoveWidget(panel->secP, 7, 7);

	for (i = 0; i < wlengthof(textureOptions); i++)
		WMAddPopUpButtonItem(panel->secP, _(textureOptions[i].popup_label));

	WMSetPopUpButtonSelectedItem(panel->secP, 0);
	WMSetPopUpButtonAction(panel->secP, changePage, panel);

	panel->texLs = WMCreateList(panel->texF);
	WMResizeWidget(panel->texLs, 165, 155);
	WMMoveWidget(panel->texLs, 70, 33);
	WMSetListUserDrawItemHeight(panel->texLs, 35);
	WMSetListUserDrawProc(panel->texLs, paintListItem);
	WMHangData(panel->texLs, panel);
	WMSetListAction(panel->texLs, textureClick, panel);
	WMSetListDoubleAction(panel->texLs, textureDoubleClick, panel);

	WMSetBalloonTextForView(_("Double click in the texture you want to use\n"
				  "for the selected item."), WMWidgetView(panel->texLs));

	/* command buttons */

	font = WMSystemFontOfSize(scr, 10);

	panel->newB = WMCreateCommandButton(panel->texF);
	WMResizeWidget(panel->newB, 57, 39);
	WMMoveWidget(panel->newB, 7, 33);
	WMSetButtonFont(panel->newB, font);
	WMSetButtonImagePosition(panel->newB, WIPAbove);
	WMSetButtonText(panel->newB, _("New"));
	WMSetButtonAction(panel->newB, newTexture, panel);
	SetButtonAlphaImage(scr, panel->newB, TNEW_FILE);

	WMSetBalloonTextForView(_("Create a new texture."), WMWidgetView(panel->newB));

	panel->ripB = WMCreateCommandButton(panel->texF);
	WMResizeWidget(panel->ripB, 57, 39);
	WMMoveWidget(panel->ripB, 7, 72);
	WMSetButtonFont(panel->ripB, font);
	WMSetButtonImagePosition(panel->ripB, WIPAbove);
	WMSetButtonText(panel->ripB, _("Extract..."));
	WMSetButtonAction(panel->ripB, extractTexture, panel);
	SetButtonAlphaImage(scr, panel->ripB, TEXTR_FILE);

	WMSetBalloonTextForView(_("Extract texture(s) from a theme or a style file."), WMWidgetView(panel->ripB));

	WMSetButtonEnabled(panel->ripB, False);

	panel->editB = WMCreateCommandButton(panel->texF);
	WMResizeWidget(panel->editB, 57, 39);
	WMMoveWidget(panel->editB, 7, 111);
	WMSetButtonFont(panel->editB, font);
	WMSetButtonImagePosition(panel->editB, WIPAbove);
	WMSetButtonText(panel->editB, _("Edit"));
	SetButtonAlphaImage(scr, panel->editB, TEDIT_FILE);
	WMSetButtonAction(panel->editB, editTexture, panel);
	WMSetBalloonTextForView(_("Edit the highlighted texture."), WMWidgetView(panel->editB));

	panel->delB = WMCreateCommandButton(panel->texF);
	WMResizeWidget(panel->delB, 57, 38);
	WMMoveWidget(panel->delB, 7, 150);
	WMSetButtonFont(panel->delB, font);
	WMSetButtonImagePosition(panel->delB, WIPAbove);
	WMSetButtonText(panel->delB, _("Delete"));
	SetButtonAlphaImage(scr, panel->delB, TDEL_FILE);
	WMSetButtonEnabled(panel->delB, False);
	WMSetButtonAction(panel->delB, deleteTexture, panel);
	WMSetBalloonTextForView(_("Delete the highlighted texture."), WMWidgetView(panel->delB));

	WMReleaseFont(font);

	WMMapSubwidgets(panel->texF);

    /*** colors ***/
	panel->colF = WMCreateFrame(panel->box);
	WMSetFrameRelief(panel->colF, WRFlat);

	item = WMCreateTabViewItemWithIdentifier(TAB_COLOR);
	WMSetTabViewItemView(item, WMWidgetView(panel->colF));
	WMSetTabViewItemLabel(item, _("Color"));

	WMAddItemInTabView(panel->tabv, item);

	panel->colP = WMCreatePopUpButton(panel->colF);
	WMResizeWidget(panel->colP, 228, 20);
	WMMoveWidget(panel->colP, 7, 7);

	for (i = 0; i < wlengthof(colorOptions); i++)
		WMAddPopUpButtonItem(panel->colP, _(colorOptions[i].label));

	WMSetPopUpButtonSelectedItem(panel->colP, 0);

	WMSetPopUpButtonAction(panel->colP, changeColorPage, panel);

	panel->colW = WMCreateColorWell(panel->colF);
	WMResizeWidget(panel->colW, 65, 50);
	WMMoveWidget(panel->colW, 30, 75);
	WMAddNotificationObserver(colorWellObserver, panel, WMColorWellDidChangeNotification, panel->colW);

	{ /* Distribute the color samples regularly in the right half */
		const int parent_width  = 242;
		const int parent_height = 195;
		const int available_width  = (parent_width / 2) - 7;
		const int available_height = parent_height - 7 - 20 - 7 - 7;
		const int widget_size = 22;

		const int nb_x = (int) round(sqrt(wlengthof(sample_colors) * available_width / available_height));
		const int nb_y = (wlengthof(sample_colors) + nb_x - 1) / nb_x;

		const int offset_x = (parent_width / 2) + (available_width - nb_x * widget_size) / 2;
		const int offset_y = (7 + 20 + 7) + (available_height - nb_y * widget_size) / 2;

		int x, y;

		x = 0; y = 0;
		for (i = 0; i < wlengthof(sample_colors); i++) {
			panel->sampW[i] = WMCreateColorWell(panel->colF);
			WMResizeWidget(panel->sampW[i], widget_size, widget_size);
			WMMoveWidget(panel->sampW[i], offset_x + x * widget_size, offset_y + y * widget_size);
			WSetColorWellBordered(panel->sampW[i], False);
			if (++x >= nb_x) {
				y++;
				x = 0;
			}
		}
	}

	WMMapSubwidgets(panel->colF);

    /*** options ***/
	panel->optF = WMCreateFrame(panel->box);
	WMSetFrameRelief(panel->optF, WRFlat);

	item = WMCreateTabViewItemWithIdentifier(TAB_OPTIONS);
	WMSetTabViewItemView(item, WMWidgetView(panel->optF));
	WMSetTabViewItemLabel(item, _("Options"));

	WMAddItemInTabView(panel->tabv, item);

	panel->mstyF = WMCreateFrame(panel->optF);
	WMResizeWidget(panel->mstyF, 215, 85);
	WMMoveWidget(panel->mstyF, 15, 10);
	WMSetFrameTitle(panel->mstyF, _("Menu Style"));

	for (i = 0; i < wlengthof(menu_style); i++) {
		WMPixmap *icon;
		char *path;

		panel->mstyB[i] = WMCreateButton(panel->mstyF, WBTOnOff);
		WMResizeWidget(panel->mstyB[i], 54, 54);
		WMMoveWidget(panel->mstyB[i], 15 + i * 65, 20);
		WMSetButtonImagePosition(panel->mstyB[i], WIPImageOnly);
		WMSetButtonAction(panel->mstyB[i], menuStyleCallback, panel);
		path = LocateImage(menu_style[i].file_name);
		if (path) {
			icon = WMCreatePixmapFromFile(scr, path);
			if (icon) {
				WMSetButtonImage(panel->mstyB[i], icon);
				WMReleasePixmap(icon);
			} else {
				wwarning(_("could not load icon file %s"), path);
			}
			wfree(path);
		}
	}
	WMGroupButtons(panel->mstyB[0], panel->mstyB[1]);
	WMGroupButtons(panel->mstyB[0], panel->mstyB[2]);

	WMMapSubwidgets(panel->mstyF);

	panel->taliF = WMCreateFrame(panel->optF);
	WMResizeWidget(panel->taliF, 110, 80);
	WMMoveWidget(panel->taliF, 15, 100);
	WMSetFrameTitle(panel->taliF, _("Title Alignment"));

	for (i = 0; i < wlengthof(wintitle_align); i++) {
		panel->taliB[i] = WMCreateRadioButton(panel->taliF);
		WMSetButtonAction(panel->taliB[i], titleAlignCallback, panel);
		WMSetButtonText(panel->taliB[i], _(wintitle_align[i].label));
		WMResizeWidget(panel->taliB[i], 90, 18);
		WMMoveWidget(panel->taliB[i], 10, 15 + 20 * i);
	}
	WMGroupButtons(panel->taliB[0], panel->taliB[1]);
	WMGroupButtons(panel->taliB[0], panel->taliB[2]);

	WMMapSubwidgets(panel->taliF);

	WMMapSubwidgets(panel->optF);

	 /**/ WMRealizeWidget(panel->box);
	WMMapSubwidgets(panel->box);

	WMSetPopUpButtonSelectedItem(panel->secP, 0);

	showData(panel);

	changePage(panel->secP, panel);

	fillTextureList(panel->texLs);

	fillColorList(panel);

	panel->texturePanel = CreateTexturePanel(panel->parent);
}

static void setupTextureFor(WMList *list, const char *key, const char *defValue, const char *title, int index)
{
	WMListItem *item;
	TextureListItem *titem;

	titem = wmalloc(sizeof(TextureListItem));

	titem->title = wstrdup(title);
	titem->prop = GetObjectForKey(key);
	if (!titem->prop || !WMIsPLArray(titem->prop)) {
		/* Maybe also give a error message to stderr that the entry is bad? */
		titem->prop = WMCreatePropListFromDescription(defValue);
	} else {
		WMRetainPropList(titem->prop);
	}
	titem->texture = WMGetPropListDescription((WMPropList *) titem->prop, False);
	titem->current = 1;
	titem->selectedFor = 1 << index;

	titem->ispixmap = isPixmap(titem->prop);

	titem->preview = renderTexture(WMWidgetScreen(list), titem->prop, TEXPREV_WIDTH, TEXPREV_HEIGHT, NULL, 0);

	item = WMAddListItem(list, "");
	item->clientData = titem;
}

static void showData(_Panel * panel)
{
	int i;
	const char *str;

	str = GetStringForKey("MenuStyle");
	panel->menuStyle = MSTYLE_NORMAL;
	if (str != NULL) {
		for (i = 0; i < wlengthof(menu_style); i++) {
			if (strcasecmp(str, menu_style[i].db_value) == 0) {
				panel->menuStyle = i;
				break;
			}
		}
	}

	str = GetStringForKey("TitleJustify");
	panel->titleAlignment = WACenter;
	if (str != NULL) {
		WMAlignment align;

		for (align = 0; align < wlengthof(wintitle_align); align++) {
			if (strcasecmp(str, wintitle_align[align].db_value) == 0) {
				panel->titleAlignment = align;
				break;
			}
		}
	}

	for (i = 0; i < wlengthof(colorOptions); i++) {
		WMColor *color;

		str = GetStringForKey(colorOptions[i].key);
		if (!str)
			str = colorOptions[i].default_value;

		if (!(color = WMCreateNamedColor(WMWidgetScreen(panel->box), str, False))) {
			color = WMCreateNamedColor(WMWidgetScreen(panel->box), "#000000", False);
		}

		panel->colors[i] = color;
	}
	changeColorPage(panel->colP, panel);

	for (i = 0; i < wlengthof(textureOptions); i++) {
		setupTextureFor(panel->texLs, textureOptions[i].key,
		                textureOptions[i].default_value, _(textureOptions[i].texture_label), i);
		panel->textureIndex[i] = i;
	}
	updatePreviewBox(panel, EVERYTHING);

	WMSetButtonSelected(panel->mstyB[panel->menuStyle], True);
	WMSetButtonSelected(panel->taliB[panel->titleAlignment], True);
}

static void storeData(_Panel * panel)
{
	TextureListItem *titem;
	WMListItem *item;
	int i;

	for (i = 0; i < wlengthof(textureOptions); i++) {
		item = WMGetListItem(panel->texLs, panel->textureIndex[i]);
		titem = (TextureListItem *) item->clientData;
		SetObjectForKey(titem->prop, textureOptions[i].key);
	}

	for (i = 0; i < wlengthof(colorOptions); i++) {
		char *str;

		str = WMGetColorRGBDescription(panel->colors[i]);

		if (str) {
			SetStringForKey(str, colorOptions[i].key);
			wfree(str);
		}
	}

	SetStringForKey(menu_style[panel->menuStyle].db_value, "MenuStyle");
	SetStringForKey(wintitle_align[panel->titleAlignment].db_value, "TitleJustify");
}

static void prepareForClose(_Panel * panel)
{
	WMPropList *textureList;
	WMPropList *texture;
	TextureListItem *titem;
	WMListItem *item;
	WMUserDefaults *udb = WMGetStandardUserDefaults();
	int i;

	textureList = WMCreatePLArray(NULL, NULL);

	/* store list of textures */
	for (i = 8; i < WMGetListNumberOfRows(panel->texLs); i++) {
		WMPropList *pl_title, *pl_path;

		item = WMGetListItem(panel->texLs, i);
		titem = (TextureListItem *) item->clientData;

		pl_title = WMCreatePLString(titem->title);
		pl_path = WMCreatePLString(titem->path);
		texture = WMCreatePLArray(pl_title, titem->prop, pl_path, NULL);
		WMReleasePropList(pl_title);
		WMReleasePropList(pl_path);

		WMAddToPLArray(textureList, texture);
	}

	WMSetUDObjectForKey(udb, textureList, "TextureList");
	WMReleasePropList(textureList);

	/* store list of colors */
	textureList = WMCreatePLArray(NULL, NULL);
	for (i = 0; i < wlengthof(sample_colors); i++) {
		WMColor *color;
		char *str;
		WMPropList *pl_color;

		color = WMGetColorWellColor(panel->sampW[i]);

		str = WMGetColorRGBDescription(color);
		pl_color = WMCreatePLString(str);
		WMAddToPLArray(textureList, pl_color);
		WMReleasePropList(pl_color);
		wfree(str);
	}
	WMSetUDObjectForKey(udb, textureList, "ColorList");
	WMReleasePropList(textureList);

	WMSynchronizeUserDefaults(udb);
}

Panel *InitAppearance(WMWidget *parent)
{
	_Panel *panel;

	panel = wmalloc(sizeof(_Panel));

	panel->sectionName = _("Appearance Preferences");

	panel->description = _("Background texture configuration for windows,\n" "menus and icons.");

	panel->parent = parent;

	panel->callbacks.createWidgets = createPanel;
	panel->callbacks.updateDomain = storeData;
	panel->callbacks.prepareForClose = prepareForClose;

	AddSection(panel, ICON_FILE);

	return panel;
}

/****************************************************************************/

typedef struct ExtractPanel {
	WMWindow *win;

	WMLabel *label;
	WMList *list;

	WMButton *closeB;
	WMButton *extrB;
} ExtractPanel;

static void OpenExtractPanelFor(_Panel *panel)
{
	ExtractPanel *epanel;
	WMColor *color;
	WMFont *font;
	WMScreen *scr = WMWidgetScreen(panel->parent);

	epanel = wmalloc(sizeof(ExtractPanel));
	epanel->win = WMCreatePanelWithStyleForWindow(panel->parent, "extract",
						      WMTitledWindowMask | WMClosableWindowMask);
	WMResizeWidget(epanel->win, 245, 250);
	WMSetWindowTitle(epanel->win, _("Extract Texture"));

	epanel->label = WMCreateLabel(epanel->win);
	WMResizeWidget(epanel->label, 225, 18);
	WMMoveWidget(epanel->label, 10, 10);
	WMSetLabelTextAlignment(epanel->label, WACenter);
	WMSetLabelRelief(epanel->label, WRSunken);

	color = WMDarkGrayColor(scr);
	WMSetWidgetBackgroundColor(epanel->label, color);
	WMReleaseColor(color);

	color = WMWhiteColor(scr);
	WMSetLabelTextColor(epanel->label, color);
	WMReleaseColor(color);

	font = WMBoldSystemFontOfSize(scr, 12);
	WMSetLabelFont(epanel->label, font);
	WMReleaseFont(font);

	WMSetLabelText(epanel->label, _("Textures"));

	epanel->list = WMCreateList(epanel->win);
	WMResizeWidget(epanel->list, 225, 165);
	WMMoveWidget(epanel->list, 10, 30);

	epanel->closeB = WMCreateCommandButton(epanel->win);
	WMResizeWidget(epanel->closeB, 74, 24);
	WMMoveWidget(epanel->closeB, 165, 215);
	WMSetButtonText(epanel->closeB, _("Close"));

	epanel->extrB = WMCreateCommandButton(epanel->win);
	WMResizeWidget(epanel->extrB, 74, 24);
	WMMoveWidget(epanel->extrB, 80, 215);
	WMSetButtonText(epanel->extrB, _("Extract"));

	WMMapSubwidgets(epanel->win);

	/* take textures from file */

	WMRealizeWidget(epanel->win);

	WMMapWidget(epanel->win);
}
