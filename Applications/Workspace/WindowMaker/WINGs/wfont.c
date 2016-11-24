
#include <stdlib.h>

#include "wconfig.h"

#include "WINGsP.h"

#include <wraster.h>
#include <assert.h>
#include <X11/Xlocale.h>

#include <X11/Xft/Xft.h>
#include <fontconfig/fontconfig.h>

#ifdef USE_PANGO
#include <pango/pango.h>
#include <pango/pangofc-fontmap.h>
#include <pango/pangoxft.h>
#endif

#define DEFAULT_FONT "sans serif:pixelsize=12"

#define DEFAULT_SIZE WINGsConfiguration.defaultFontSize

static FcPattern *xlfdToFcPattern(const char *xlfd)
{
	FcPattern *pattern;
	char *fname, *ptr;

	/* Just skip old font names that contain %d in them.
	 * We don't support that anymore. */
	if (strchr(xlfd, '%') != NULL)
		return FcNameParse((FcChar8 *) DEFAULT_FONT);

	fname = wstrdup(xlfd);
	if ((ptr = strchr(fname, ','))) {
		*ptr = 0;
	}
	pattern = XftXlfdParse(fname, False, False);
	wfree(fname);

	if (!pattern) {
		wwarning(_("invalid font: %s. Trying '%s'"), xlfd, DEFAULT_FONT);
		pattern = FcNameParse((FcChar8 *) DEFAULT_FONT);
	}

	return pattern;
}

static char *xlfdToFcName(const char *xlfd)
{
	FcPattern *pattern;
	char *fname;

	pattern = xlfdToFcPattern(xlfd);
	fname = (char *)FcNameUnparse(pattern);
	FcPatternDestroy(pattern);

	return fname;
}

static Bool hasProperty(FcPattern * pattern, const char *property)
{
	FcValue val;

	if (FcPatternGet(pattern, property, 0, &val) == FcResultMatch) {
		return True;
	}

	return False;
}

static Bool hasPropertyWithStringValue(FcPattern * pattern, const char *object, const char *value)
{
	FcChar8 *str;
	int id;

	if (!value || value[0] == 0)
		return True;

	id = 0;
	while (FcPatternGetString(pattern, object, id, &str) == FcResultMatch) {
		if (strcasecmp(value, (char *)str) == 0) {
			return True;
		}
		id++;
	}

	return False;
}

static char *makeFontOfSize(const char *font, int size, const char *fallback)
{
	FcPattern *pattern;
	char *result;

	if (font[0] == '-') {
		pattern = xlfdToFcPattern(font);
	} else {
		pattern = FcNameParse((const FcChar8 *) font);
	}

	/*FcPatternPrint(pattern); */

	if (size > 0) {
		FcPatternDel(pattern, FC_PIXEL_SIZE);
		FcPatternAddDouble(pattern, FC_PIXEL_SIZE, (double)size);
	} else if (size == 0 && !hasProperty(pattern, "size") && !hasProperty(pattern, FC_PIXEL_SIZE)) {
		FcPatternAddDouble(pattern, FC_PIXEL_SIZE, (double)DEFAULT_SIZE);
	}

	if (fallback && !hasPropertyWithStringValue(pattern, FC_FAMILY, fallback)) {
		FcPatternAddString(pattern, FC_FAMILY, (const FcChar8 *) fallback);
	}

	/*FcPatternPrint(pattern); */

	result = (char *)FcNameUnparse(pattern);
	FcPatternDestroy(pattern);

	return result;
}

WMFont *WMCreateFont(WMScreen * scrPtr, const char *fontName)
{
	Display *display = scrPtr->display;
	WMFont *font;
	char *fname;
#ifdef USE_PANGO
	PangoFontMap *fontmap;
	PangoContext *context;
	PangoLayout *layout;
	FcPattern *pattern;
	PangoFontDescription *description;
	double size;
#endif

	if (fontName[0] == '-') {
		fname = xlfdToFcName(fontName);
	} else {
		fname = wstrdup(fontName);
	}

	if (!WINGsConfiguration.antialiasedText && !strstr(fname, ":antialias=")) {
		fname = wstrappend(fname, ":antialias=false");
	}

	font = WMHashGet(scrPtr->fontCache, fname);
	if (font) {
		WMRetainFont(font);
		wfree(fname);
		return font;
	}

	font = wmalloc(sizeof(WMFont));

	font->screen = scrPtr;

	font->font = XftFontOpenName(display, scrPtr->screen, fname);
	if (!font->font) {
		wfree(font);
		wfree(fname);
		return NULL;
	}

	font->height = font->font->ascent + font->font->descent;
	font->y = font->font->ascent;

	font->refCount = 1;

	font->name = fname;

#ifdef USE_PANGO
	fontmap = pango_xft_get_font_map(scrPtr->display, scrPtr->screen);
	context = pango_font_map_create_context(fontmap);
	layout = pango_layout_new(context);

	pattern = FcNameParse((FcChar8 *) font->name);
	description = pango_fc_font_description_from_pattern(pattern, FALSE);

	/* Pango examines FC_SIZE but not FC_PIXEL_SIZE of the patten, but
	 * font-name has only "pixelsize", so set the size manually here.
	 */
	if (FcPatternGetDouble(pattern, FC_PIXEL_SIZE, 0, &size) == FcResultMatch)
		pango_font_description_set_absolute_size(description, size * PANGO_SCALE);

	pango_layout_set_font_description(layout, description);

	font->layout = layout;
#endif

	assert(WMHashInsert(scrPtr->fontCache, font->name, font) == NULL);

	return font;
}

WMFont *WMRetainFont(WMFont * font)
{
	wassertrv(font != NULL, NULL);

	font->refCount++;

	return font;
}

void WMReleaseFont(WMFont * font)
{
	wassertr(font != NULL);

	font->refCount--;
	if (font->refCount < 1) {
		XftFontClose(font->screen->display, font->font);
		if (font->name) {
			WMHashRemove(font->screen->fontCache, font->name);
			wfree(font->name);
		}
		wfree(font);
	}
}

Bool WMIsAntialiasingEnabled(WMScreen * scrPtr)
{
	return scrPtr->antialiasedText;
}

unsigned int WMFontHeight(WMFont * font)
{
	wassertrv(font != NULL, 0);

	return font->height;
}

char *WMGetFontName(WMFont * font)
{
	wassertrv(font != NULL, NULL);

	return font->name;
}

WMFont *WMDefaultSystemFont(WMScreen * scrPtr)
{
	return WMRetainFont(scrPtr->normalFont);
}

WMFont *WMDefaultBoldSystemFont(WMScreen * scrPtr)
{
	return WMRetainFont(scrPtr->boldFont);
}

WMFont *WMSystemFontOfSize(WMScreen * scrPtr, int size)
{
	WMFont *font;
	char *fontSpec;

	fontSpec = makeFontOfSize(WINGsConfiguration.systemFont, size, NULL);

	font = WMCreateFont(scrPtr, fontSpec);

	if (!font) {
		wwarning(_("could not load font: %s."), fontSpec);
	}

	wfree(fontSpec);

	return font;
}

WMFont *WMBoldSystemFontOfSize(WMScreen * scrPtr, int size)
{
	WMFont *font;
	char *fontSpec;

	fontSpec = makeFontOfSize(WINGsConfiguration.boldSystemFont, size, NULL);

	font = WMCreateFont(scrPtr, fontSpec);

	if (!font) {
		wwarning(_("could not load font: %s."), fontSpec);
	}

	wfree(fontSpec);

	return font;
}

int WMWidthOfString(WMFont * font, const char *text, int length)
{
#ifdef USE_PANGO
	const char *previous_text;
	int width;
#else
	XGlyphInfo extents;
#endif

	wassertrv(font != NULL && text != NULL, 0);
#ifdef USE_PANGO
	previous_text = pango_layout_get_text(font->layout);
	if ((previous_text == NULL) || (strncmp(text, previous_text, length) != 0) || previous_text[length] != '\0')
		pango_layout_set_text(font->layout, text, length);
	pango_layout_get_pixel_size(font->layout, &width, NULL);

	return width;
#else
	XftTextExtentsUtf8(font->screen->display, font->font, (XftChar8 *) text, length, &extents);

	return extents.xOff;	/* don't ask :P */
#endif
}

void WMDrawString(WMScreen * scr, Drawable d, WMColor * color, WMFont * font, int x, int y, const char *text, int length)
{
	XftColor xftcolor;
#ifdef USE_PANGO
	const char *previous_text;
#endif

	wassertr(font != NULL);

	xftcolor.color.red = color->color.red;
	xftcolor.color.green = color->color.green;
	xftcolor.color.blue = color->color.blue;
	xftcolor.color.alpha = color->alpha;;
	xftcolor.pixel = W_PIXEL(color);

	XftDrawChange(scr->xftdraw, d);

#ifdef USE_PANGO
	previous_text = pango_layout_get_text(font->layout);
	if ((previous_text == NULL) || (strcmp(text, previous_text) != 0))
		pango_layout_set_text(font->layout, text, length);
	pango_xft_render_layout(scr->xftdraw, &xftcolor, font->layout, x * PANGO_SCALE, y * PANGO_SCALE);
#else
	XftDrawStringUtf8(scr->xftdraw, &xftcolor, font->font, x, y + font->y, (XftChar8 *) text, length);
#endif
}

void
WMDrawImageString(WMScreen * scr, Drawable d, WMColor * color, WMColor * background,
		  WMFont * font, int x, int y, const char *text, int length)
{
	XftColor textColor;
	XftColor bgColor;
#ifdef USE_PANGO
	const char *previous_text;
#endif

	wassertr(font != NULL);

	textColor.color.red = color->color.red;
	textColor.color.green = color->color.green;
	textColor.color.blue = color->color.blue;
	textColor.color.alpha = color->alpha;;
	textColor.pixel = W_PIXEL(color);

	bgColor.color.red = background->color.red;
	bgColor.color.green = background->color.green;
	bgColor.color.blue = background->color.blue;
	bgColor.color.alpha = background->alpha;;
	bgColor.pixel = W_PIXEL(background);

	XftDrawChange(scr->xftdraw, d);

	XftDrawRect(scr->xftdraw, &bgColor, x, y, WMWidthOfString(font, text, length), font->height);

#ifdef USE_PANGO
	previous_text = pango_layout_get_text(font->layout);
	if ((previous_text == NULL) || (strcmp(text, previous_text) != 0))
		pango_layout_set_text(font->layout, text, length);
	pango_xft_render_layout(scr->xftdraw, &textColor, font->layout, x * PANGO_SCALE, y * PANGO_SCALE);
#else
	XftDrawStringUtf8(scr->xftdraw, &textColor, font->font, x, y + font->y, (XftChar8 *) text, length);
#endif
}

WMFont *WMCopyFontWithStyle(WMScreen * scrPtr, WMFont * font, WMFontStyle style)
{
	FcPattern *pattern;
	WMFont *copy;
	char *name;

	if (!font)
		return NULL;

	/* It's enough to add italic to slant, even if the font has no italic
	 * variant, but only oblique. This is because fontconfig will actually
	 * return the closest match font to what we requested which is the
	 * oblique font. Same goes for using bold for weight.
	 */
	pattern = FcNameParse((FcChar8 *) WMGetFontName(font));
	switch (style) {
	case WFSNormal:
		FcPatternDel(pattern, FC_WEIGHT);
		FcPatternDel(pattern, FC_SLANT);
		break;
	case WFSBold:
		FcPatternDel(pattern, FC_WEIGHT);
		FcPatternAddString(pattern, FC_WEIGHT, (FcChar8 *) "bold");
		break;
	case WFSItalic:
		FcPatternDel(pattern, FC_SLANT);
		FcPatternAddString(pattern, FC_SLANT, (FcChar8 *) "italic");
		break;
	case WFSBoldItalic:
		FcPatternDel(pattern, FC_WEIGHT);
		FcPatternDel(pattern, FC_SLANT);
		FcPatternAddString(pattern, FC_WEIGHT, (FcChar8 *) "bold");
		FcPatternAddString(pattern, FC_SLANT, (FcChar8 *) "italic");
		break;
	}

	name = (char *)FcNameUnparse(pattern);
	copy = WMCreateFont(scrPtr, name);
	FcPatternDestroy(pattern);
	wfree(name);

	return copy;
}
