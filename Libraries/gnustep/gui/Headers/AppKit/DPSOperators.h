/* DPSOperators - Drawing engine operators that require context

   Copyright (C) 1999 Free Software Foundation, Inc.
   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Based on code by Adam Fedor
   Date: Feb 1999
   
   This file is part of the GNU Objective C User Interface library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/

#ifndef _DPSOperators_h_INCLUDE
#define _DPSOperators_h_INCLUDE
#import <AppKit/AppKitDefines.h>

#import <AppKit/NSGraphicsContext.h>

#define	GSCTXT	NSGraphicsContext

/* ----------------------------------------------------------------------- */
/* Color operations */
/* ----------------------------------------------------------------------- */
static inline void
DPScurrentalpha(GSCTXT *ctxt, CGFloat* a)
__attribute__((unused));

static inline void
DPScurrentcmykcolor(GSCTXT *ctxt, CGFloat* c, CGFloat* m, CGFloat* y, CGFloat* k)
__attribute__((unused));

static inline void
DPScurrentgray(GSCTXT *ctxt, CGFloat* gray)
__attribute__((unused));

static inline void
DPScurrenthsbcolor(GSCTXT *ctxt, CGFloat* h, CGFloat* s, CGFloat* b)
__attribute__((unused));

static inline void
DPScurrentrgbcolor(GSCTXT *ctxt, CGFloat* r, CGFloat* g, CGFloat* b)
__attribute__((unused));

static inline void
DPSsetalpha(GSCTXT *ctxt, CGFloat a)
__attribute__((unused));

static inline void
DPSsetcmykcolor(GSCTXT *ctxt, CGFloat c, CGFloat m, CGFloat y, CGFloat k)
__attribute__((unused));

static inline void
DPSsetgray(GSCTXT *ctxt, CGFloat gray)
__attribute__((unused));

static inline void
DPSsethsbcolor(GSCTXT *ctxt, CGFloat h, CGFloat s, CGFloat b)
__attribute__((unused));

static inline void
DPSsetrgbcolor(GSCTXT *ctxt, CGFloat r, CGFloat g, CGFloat b)
__attribute__((unused));


static inline void
GSSetFillColorspace(GSCTXT *ctxt, NSDictionary * dict)
__attribute__((unused));

static inline void
GSSetStrokeColorspace(GSCTXT *ctxt, NSDictionary * dict)
__attribute__((unused));

static inline void
GSSetFillColor(GSCTXT *ctxt, CGFloat * values)
__attribute__((unused));

static inline void
GSSetStrokeColor(GSCTXT *ctxt, CGFloat * values)
__attribute__((unused));


/* ----------------------------------------------------------------------- */
/* Text operations */
/* ----------------------------------------------------------------------- */
static inline void
DPSashow(GSCTXT *ctxt, CGFloat x, CGFloat y, const char* s)
__attribute__((unused));

static inline void
DPSawidthshow(GSCTXT *ctxt, CGFloat cx, CGFloat cy, int c, CGFloat ax, CGFloat ay, const char* s)
__attribute__((unused));

static inline void
DPScharpath(GSCTXT *ctxt, const char* s, int b)
__attribute__((unused));

static inline void
DPSshow(GSCTXT *ctxt, const char* s)
__attribute__((unused));

static inline void
DPSwidthshow(GSCTXT *ctxt, CGFloat x, CGFloat y, int c, const char* s)
__attribute__((unused));

static inline void
DPSxshow(GSCTXT *ctxt, const char* s, const CGFloat* numarray, int size)
__attribute__((unused));

static inline void
DPSxyshow(GSCTXT *ctxt, const char* s, const CGFloat* numarray, int size)
__attribute__((unused));

static inline void
DPSyshow(GSCTXT *ctxt, const char* s, const CGFloat* numarray, int size)
__attribute__((unused));


static inline void
GSSetCharacterSpacing(GSCTXT *ctxt, CGFloat extra)
__attribute__((unused));

static inline void
GSSetFont(GSCTXT *ctxt, NSFont* font)
__attribute__((unused));

static inline void
GSSetFontSize(GSCTXT *ctxt, CGFloat size)
__attribute__((unused));

static inline NSAffineTransform *
GSGetTextCTM(GSCTXT *ctxt)
__attribute__((unused));

static inline NSPoint
GSGetTextPosition(GSCTXT *ctxt)
__attribute__((unused));

static inline void
GSSetTextCTM(GSCTXT *ctxt, NSAffineTransform * ctm)
__attribute__((unused));

static inline void
GSSetTextDrawingMode(GSCTXT *ctxt, GSTextDrawingMode mode)
__attribute__((unused));

static inline void
GSSetTextPosition(GSCTXT *ctxt, NSPoint loc)
__attribute__((unused));

static inline void
GSShowText(GSCTXT *ctxt, const char * string, size_t length)
__attribute__((unused));

static inline void
GSShowGlyphs(GSCTXT *ctxt, const NSGlyph * glyphs, size_t length)
__attribute__((unused));

static inline void
GSShowGlyphsWithAdvances(GSCTXT *ctxt, const NSGlyph * glyphs, const NSSize * advances, size_t length)
__attribute__((unused));



/* ----------------------------------------------------------------------- */
/* Gstate Handling */
/* ----------------------------------------------------------------------- */
static inline void
DPSgrestore(GSCTXT *ctxt)
__attribute__((unused));

static inline void
DPSgsave(GSCTXT *ctxt)
__attribute__((unused));

static inline void
DPSinitgraphics(GSCTXT *ctxt)
__attribute__((unused));

static inline void
DPSsetgstate(GSCTXT *ctxt, NSInteger gst)
__attribute__((unused));


static inline NSInteger
GSDefineGState(GSCTXT *ctxt)
__attribute__((unused));

static inline void
GSUndefineGState(GSCTXT *ctxt, NSInteger gst)
__attribute__((unused));

static inline void
GSReplaceGState(GSCTXT *ctxt, NSInteger gst)
__attribute__((unused));

/* ----------------------------------------------------------------------- */
/* Gstate operations */
/* ----------------------------------------------------------------------- */
static inline void
DPScurrentflat(GSCTXT *ctxt, CGFloat* flatness)
__attribute__((unused));

static inline void
DPScurrentlinecap(GSCTXT *ctxt, int* linecap)
__attribute__((unused));

static inline void
DPScurrentlinejoin(GSCTXT *ctxt, int* linejoin)
__attribute__((unused));

static inline void
DPScurrentlinewidth(GSCTXT *ctxt, CGFloat* width)
__attribute__((unused));

static inline void
DPScurrentmiterlimit(GSCTXT *ctxt, CGFloat* limit)
__attribute__((unused));

static inline void
DPScurrentpoint(GSCTXT *ctxt, CGFloat* x, CGFloat* y)
__attribute__((unused));

static inline void
DPScurrentstrokeadjust(GSCTXT *ctxt, int* b)
__attribute__((unused));

static inline void
DPSsetdash(GSCTXT *ctxt, const CGFloat* pat, NSInteger size, CGFloat offset)
__attribute__((unused));

static inline void
DPSsetflat(GSCTXT *ctxt, CGFloat flatness)
__attribute__((unused));

static inline void
DPSsethalftonephase(GSCTXT *ctxt, CGFloat x, CGFloat y)
__attribute__((unused));

static inline void
DPSsetlinecap(GSCTXT *ctxt, int linecap)
__attribute__((unused));

static inline void
DPSsetlinejoin(GSCTXT *ctxt, int linejoin)
__attribute__((unused));

static inline void
DPSsetlinewidth(GSCTXT *ctxt, CGFloat width)
__attribute__((unused));

static inline void
DPSsetmiterlimit(GSCTXT *ctxt, CGFloat limit)
__attribute__((unused));

static inline void
DPSsetstrokeadjust(GSCTXT *ctxt, int b)
__attribute__((unused));


/* ----------------------------------------------------------------------- */
/* Matrix operations */
/* ----------------------------------------------------------------------- */
static inline void
DPSconcat(GSCTXT *ctxt, const CGFloat* m)
__attribute__((unused));

static inline void
DPSinitmatrix(GSCTXT *ctxt)
__attribute__((unused));

static inline void
DPSrotate(GSCTXT *ctxt, CGFloat angle)
__attribute__((unused));

static inline void
DPSscale(GSCTXT *ctxt, CGFloat x, CGFloat y)
__attribute__((unused));

static inline void
DPStranslate(GSCTXT *ctxt, CGFloat x, CGFloat y)
__attribute__((unused));


static inline NSAffineTransform *
GSCurrentCTM(GSCTXT *ctxt)
__attribute__((unused));

static inline void
GSSetCTM(GSCTXT *ctxt, NSAffineTransform * ctm)
__attribute__((unused));

static inline void
GSConcatCTM(GSCTXT *ctxt, NSAffineTransform * ctm)
__attribute__((unused));


/* ----------------------------------------------------------------------- */
/* Paint operations */
/* ----------------------------------------------------------------------- */
static inline void
DPSarc(GSCTXT *ctxt, CGFloat x, CGFloat y, CGFloat r, CGFloat angle1, CGFloat angle2)
__attribute__((unused));

static inline void
DPSarcn(GSCTXT *ctxt, CGFloat x, CGFloat y, CGFloat r, CGFloat angle1, CGFloat angle2)
__attribute__((unused));

static inline void
DPSarct(GSCTXT *ctxt, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat r)
__attribute__((unused));

static inline void
DPSclip(GSCTXT *ctxt)
__attribute__((unused));

static inline void
DPSclosepath(GSCTXT *ctxt)
__attribute__((unused));

static inline void
DPScurveto(GSCTXT *ctxt, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat x3, CGFloat y3)
__attribute__((unused));

static inline void
DPSeoclip(GSCTXT *ctxt)
__attribute__((unused));

static inline void
DPSeofill(GSCTXT *ctxt)
__attribute__((unused));

static inline void
DPSfill(GSCTXT *ctxt)
__attribute__((unused));

static inline void
DPSflattenpath(GSCTXT *ctxt)
__attribute__((unused));

static inline void
DPSinitclip(GSCTXT *ctxt)
__attribute__((unused));

static inline void
DPSlineto(GSCTXT *ctxt, CGFloat x, CGFloat y)
__attribute__((unused));

static inline void
DPSmoveto(GSCTXT *ctxt, CGFloat x, CGFloat y)
__attribute__((unused));

static inline void
DPSnewpath(GSCTXT *ctxt)
__attribute__((unused));

static inline void
DPSpathbbox(GSCTXT *ctxt, CGFloat* llx, CGFloat* lly, CGFloat* urx, CGFloat* ury)
__attribute__((unused));

static inline void
DPSrcurveto(GSCTXT *ctxt, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat x3, CGFloat y3)
__attribute__((unused));

static inline void
DPSrectclip(GSCTXT *ctxt, CGFloat x, CGFloat y, CGFloat w, CGFloat h)
__attribute__((unused));

static inline void
DPSrectfill(GSCTXT *ctxt, CGFloat x, CGFloat y, CGFloat w, CGFloat h)
__attribute__((unused));

static inline void
DPSrectstroke(GSCTXT *ctxt, CGFloat x, CGFloat y, CGFloat w, CGFloat h)
__attribute__((unused));

static inline void
DPSreversepath(GSCTXT *ctxt)
__attribute__((unused));

static inline void
DPSrlineto(GSCTXT *ctxt, CGFloat x, CGFloat y)
__attribute__((unused));

static inline void
DPSrmoveto(GSCTXT *ctxt, CGFloat x, CGFloat y)
__attribute__((unused));

static inline void
DPSstroke(GSCTXT *ctxt)
__attribute__((unused));

static inline void
DPSshfill(GSCTXT *ctxt, NSDictionary *shaderDictionary)
__attribute__((unused));


static inline void
GSSendBezierPath(GSCTXT *ctxt, NSBezierPath * path)
__attribute__((unused));

static inline void
GSRectClipList(GSCTXT *ctxt, const NSRect * rects, int count)
__attribute__((unused));

static inline void
GSRectFillList(GSCTXT *ctxt, const NSRect * rects, int count)
__attribute__((unused));


/* ----------------------------------------------------------------------- */
/* Window system ops */
/* ----------------------------------------------------------------------- */
static inline void
GSCurrentDevice(GSCTXT *ctxt, void** device, int* x, int* y)
__attribute__((unused));

static inline void
DPScurrentoffset(GSCTXT *ctxt, int* x, int* y)
__attribute__((unused));

static inline void
GSSetDevice(GSCTXT *ctxt, void* device, int x, int y)
__attribute__((unused));

static inline void
DPSsetoffset(GSCTXT *ctxt, short int x, short int y)
__attribute__((unused));


/*-------------------------------------------------------------------------*/
/* Graphics Extensions Ops */
/*-------------------------------------------------------------------------*/
static inline void
DPScomposite(GSCTXT *ctxt, CGFloat x, CGFloat y, CGFloat w, CGFloat h, NSInteger gstateNum, CGFloat dx, CGFloat dy, NSCompositingOperation op)
__attribute__((unused));

static inline void
DPScompositerect(GSCTXT *ctxt, CGFloat x, CGFloat y, CGFloat w, CGFloat h, NSCompositingOperation op)
__attribute__((unused));

static inline void
DPSdissolve(GSCTXT *ctxt, CGFloat x, CGFloat y, CGFloat w, CGFloat h, NSInteger gstateNum, CGFloat dx, CGFloat dy, CGFloat delta)
__attribute__((unused));


static inline void
GSDrawImage(GSCTXT *ctxt, NSRect rect, void * imageref)
__attribute__((unused));

/* ----------------------------------------------------------------------- */
/* Postscript Client functions */
/* ----------------------------------------------------------------------- */
static void
DPSPrintf(GSCTXT *ctxt, const char * fmt, ...)
__attribute__((unused));

static inline void
DPSWriteData(GSCTXT *ctxt, const char * buf, unsigned int count)
__attribute__((unused));

/** <ignore> These are duplicate definitions for MSVC, let's ignore them for autogsdoc */
#ifdef _MSC_VER
#define DPS_FUNCTION(type, name) static inline type \
name(GSCTXT *ctxt) \
{ \
  return [ctxt name]; \
}

#define DPS_METHOD(name) static inline void \
name(GSCTXT *ctxt) \
{ \
  [ctxt name]; \
}

#define DPS_METHOD_1(name, type1, var1) static inline void \
name(GSCTXT *ctxt, type1 var1) \
{ \
  [ctxt name :var1]; \
}

#define DPS_METHOD_2(name, type1, var1, type2, var2) static inline void \
name(GSCTXT *ctxt, type1 var1, type2 var2) \
{ \
  [ctxt name :var1 :var2]; \
}

#define DPS_METHOD_3(name, type1, var1, type2, var2, type3, var3) static inline void \
name(GSCTXT *ctxt, type1 var1, type2 var2, type3 var3) \
{ \
  [ctxt name :var1 :var2 :var3]; \
}

#define DPS_METHOD_4(name, type1, var1, type2, var2, type3, var3, type4, var4) static inline void \
name(GSCTXT *ctxt, type1 var1, type2 var2, type3 var3, type4 var4) \
{ \
  [ctxt name :var1 :var2 :var3 :var4]; \
}

#define DPS_METHOD_5(name, type1, var1, type2, var2, type3, var3, type4, var4, type5, var5) static inline void \
name(GSCTXT *ctxt, type1 var1, type2 var2, type3 var3, type4 var4, type5 var5) \
{ \
  [ctxt name :var1 :var2 :var3 :var4 :var5]; \
}

#define DPS_METHOD_6(name, type1, var1, type2, var2, type3, var3, type4, var4, type5, var5, type6, var6) static inline void \
name(GSCTXT *ctxt, type1 var1, type2 var2, type3 var3, type4 var4, type5 var5, type6 var6) \
{ \
  [ctxt name :var1 :var2 :var3 :var4 :var5 :var6]; \
}

#define DPS_METHOD_8(name, type1, var1, type2, var2, type3, var3, type4, var4, type5, var5, type6, var6, type7, var7, type8, var8) static inline void \
name(GSCTXT *ctxt, type1 var1, type2 var2, type3 var3, type4 var4, type5 var5, type6 var6, type7 var7, type8 var8) \
{ \
  [ctxt name :var1 :var2 :var3 :var4 :var5 :var6 :var7 :var8]; \
}
#else
#define DPS_FUNCTION(type, name) static inline type \
name(GSCTXT *ctxt) \
{ \
  return (ctxt->methods->name) \
    (ctxt, @selector(name)); \
}

#define DPS_METHOD(name) static inline void \
name(GSCTXT *ctxt) \
{ \
  (ctxt->methods->name) \
    (ctxt, @selector(name)); \
}

#define DPS_METHOD_1(name, type1, var1) static inline void \
name(GSCTXT *ctxt, type1 var1) \
{ \
  (ctxt->methods->name ## _) \
    (ctxt, @selector(name:), var1); \
}

#define DPS_METHOD_2(name, type1, var1, type2, var2) static inline void \
name(GSCTXT *ctxt, type1 var1, type2 var2) \
{ \
  (ctxt->methods->name ## __) \
    (ctxt, @selector(name: :), var1, var2); \
}

#define DPS_METHOD_3(name, type1, var1, type2, var2, type3, var3) static inline void \
name(GSCTXT *ctxt, type1 var1, type2 var2, type3 var3) \
{ \
  (ctxt->methods->name ## ___) \
    (ctxt, @selector(name: : :), var1, var2, var3); \
}

#define DPS_METHOD_4(name, type1, var1, type2, var2, type3, var3, type4, var4) static inline void \
name(GSCTXT *ctxt, type1 var1, type2 var2, type3 var3, type4 var4) \
{ \
  (ctxt->methods->name ## ____) \
    (ctxt, @selector(name: : : :), var1, var2, var3, var4); \
}

#define DPS_METHOD_5(name, type1, var1, type2, var2, type3, var3, type4, var4, type5, var5) static inline void \
name(GSCTXT *ctxt, type1 var1, type2 var2, type3 var3, type4 var4, type5 var5) \
{ \
  (ctxt->methods->name ## _____) \
    (ctxt, @selector(name: : : : :), var1, var2, var3, var4, var5); \
}

#define DPS_METHOD_6(name, type1, var1, type2, var2, type3, var3, type4, var4, type5, var5, type6, var6) static inline void \
name(GSCTXT *ctxt, type1 var1, type2 var2, type3 var3, type4 var4, type5 var5, type6 var6) \
{ \
  (ctxt->methods->name ## ______) \
    (ctxt, @selector(name: : : : : :), var1, var2, var3, var4, var5, var6); \
}

#define DPS_METHOD_8(name, type1, var1, type2, var2, type3, var3, type4, var4, type5, var5, type6, var6, type7, var7, type8, var8) static inline void \
name(GSCTXT *ctxt, type1 var1, type2 var2, type3 var3, type4 var4, type5 var5, type6 var6, type7 var7, type8 var8) \
{ \
  (ctxt->methods->name ## ________) \
    (ctxt, @selector(name: : : : : : : :), var1, var2, var3, var4, var5, var6, var7, var8); \
}
#endif // _MSVC_VER

/* ----------------------------------------------------------------------- */
/* Color operations */
/* ----------------------------------------------------------------------- */
DPS_METHOD_1(DPScurrentalpha, CGFloat*, a)

DPS_METHOD_4(DPScurrentcmykcolor, CGFloat*, c, CGFloat*, m, CGFloat*, y, CGFloat*, k)

DPS_METHOD_1(DPScurrentgray, CGFloat*, gray)

DPS_METHOD_3(DPScurrenthsbcolor, CGFloat*, h, CGFloat*, s, CGFloat*, b)

DPS_METHOD_3(DPScurrentrgbcolor, CGFloat*, r, CGFloat*, g, CGFloat*, b)

DPS_METHOD_1(DPSsetalpha, CGFloat, a)

DPS_METHOD_4(DPSsetcmykcolor, CGFloat, c, CGFloat, m, CGFloat, y, CGFloat, k)

DPS_METHOD_1(DPSsetgray, CGFloat, gray)

DPS_METHOD_3(DPSsethsbcolor, CGFloat, h, CGFloat, s, CGFloat, b)

DPS_METHOD_3(DPSsetrgbcolor, CGFloat, r, CGFloat, g, CGFloat, b)

DPS_METHOD_1(GSSetFillColorspace, NSDictionary *, dict)

DPS_METHOD_1(GSSetStrokeColorspace, NSDictionary *, dict)

DPS_METHOD_1(GSSetFillColor, CGFloat *, values)

DPS_METHOD_1(GSSetStrokeColor, CGFloat *, values)

/* ----------------------------------------------------------------------- */
/* Text operations */
/* ----------------------------------------------------------------------- */
DPS_METHOD_3(DPSashow, CGFloat, x, CGFloat, y, const char*, s)

DPS_METHOD_6(DPSawidthshow, CGFloat, cx, CGFloat, cy, int, c, CGFloat, ax, CGFloat, ay, const char*, s)

DPS_METHOD_2(DPScharpath, const char*, s, int, b)

DPS_METHOD_1(DPSshow, const char*, s)

DPS_METHOD_4(DPSwidthshow, CGFloat, x, CGFloat, y, int, c, const char*, s)

DPS_METHOD_3(DPSxshow, const char*, s, const CGFloat*, numarray, int, size)

DPS_METHOD_3(DPSxyshow, const char*, s, const CGFloat*, numarray, int, size)

DPS_METHOD_3(DPSyshow, const char*, s, const CGFloat*, numarray, int, size)

DPS_METHOD_1(GSSetCharacterSpacing, CGFloat, extra)

DPS_METHOD_1(GSSetFont, NSFont*, font)

DPS_METHOD_1(GSSetFontSize, CGFloat, size)

DPS_FUNCTION(NSAffineTransform *, GSGetTextCTM)

DPS_FUNCTION(NSPoint, GSGetTextPosition)

DPS_METHOD_1(GSSetTextCTM, NSAffineTransform *, ctm)

DPS_METHOD_1(GSSetTextDrawingMode, GSTextDrawingMode, mode)

DPS_METHOD_1(GSSetTextPosition, NSPoint, loc)

DPS_METHOD_2(GSShowText, const char *, string, size_t, length)

DPS_METHOD_2(GSShowGlyphs, const NSGlyph *, glyphs, size_t, length)

DPS_METHOD_3(GSShowGlyphsWithAdvances, const NSGlyph *, glyphs, const NSSize *, advances, size_t, length)

/* ----------------------------------------------------------------------- */
/* Gstate Handling */
/* ----------------------------------------------------------------------- */
DPS_METHOD(DPSgrestore)

DPS_METHOD(DPSgsave)

DPS_METHOD(DPSinitgraphics)

DPS_METHOD_1(DPSsetgstate, NSInteger, gst)

DPS_FUNCTION(NSInteger, GSDefineGState)

DPS_METHOD_1(GSUndefineGState, NSInteger, gst)

DPS_METHOD_1(GSReplaceGState, NSInteger, gst)

/* ----------------------------------------------------------------------- */
/* Gstate operations */
/* ----------------------------------------------------------------------- */
DPS_METHOD_1(DPScurrentflat, CGFloat*, flatness)

DPS_METHOD_1(DPScurrentlinecap, int*, linecap)

DPS_METHOD_1(DPScurrentlinejoin, int*, linejoin)

DPS_METHOD_1(DPScurrentlinewidth, CGFloat*, width)

DPS_METHOD_1(DPScurrentmiterlimit, CGFloat*, limit)

DPS_METHOD_2(DPScurrentpoint, CGFloat*, x, CGFloat*, y)

DPS_METHOD_1(DPScurrentstrokeadjust, int*, b)

DPS_METHOD_3(DPSsetdash, const CGFloat*, pat, NSInteger, size, CGFloat, offset)

DPS_METHOD_1(DPSsetflat, CGFloat, flatness)

DPS_METHOD_2(DPSsethalftonephase, CGFloat, x, CGFloat, y)

DPS_METHOD_1(DPSsetlinecap, int, linecap)

DPS_METHOD_1(DPSsetlinejoin, int, linejoin)

DPS_METHOD_1(DPSsetlinewidth, CGFloat, width)

DPS_METHOD_1(DPSsetmiterlimit, CGFloat, limit)

DPS_METHOD_1(DPSsetstrokeadjust, int, b)


/* ----------------------------------------------------------------------- */
/* Matrix operations */
/* ----------------------------------------------------------------------- */
DPS_METHOD_1(DPSconcat, const CGFloat*, m)

DPS_METHOD(DPSinitmatrix)

DPS_METHOD_1(DPSrotate, CGFloat, angle)

DPS_METHOD_2(DPSscale, CGFloat, x, CGFloat, y)

DPS_METHOD_2(DPStranslate, CGFloat, x, CGFloat, y)

DPS_FUNCTION(NSAffineTransform *, GSCurrentCTM)

DPS_METHOD_1(GSSetCTM, NSAffineTransform *, ctm)

DPS_METHOD_1(GSConcatCTM, NSAffineTransform *, ctm)


/* ----------------------------------------------------------------------- */
/* Paint operations */
/* ----------------------------------------------------------------------- */
DPS_METHOD_5(DPSarc, CGFloat, x, CGFloat, y, CGFloat, r, CGFloat, angle1, CGFloat, angle2)

DPS_METHOD_5(DPSarcn, CGFloat, x, CGFloat, y, CGFloat, r, CGFloat, angle1, CGFloat, angle2)

DPS_METHOD_5(DPSarct, CGFloat, x1, CGFloat, y1, CGFloat, x2, CGFloat, y2, CGFloat, r)

DPS_METHOD(DPSclip)

DPS_METHOD(DPSclosepath)

DPS_METHOD_6(DPScurveto, CGFloat, x1, CGFloat, y1, CGFloat, x2, CGFloat, y2, CGFloat, x3, CGFloat, y3)

DPS_METHOD(DPSeoclip)

DPS_METHOD(DPSeofill)

DPS_METHOD(DPSfill)

DPS_METHOD(DPSflattenpath)

DPS_METHOD(DPSinitclip)

DPS_METHOD_2(DPSlineto, CGFloat, x, CGFloat, y)

DPS_METHOD_2(DPSmoveto, CGFloat, x, CGFloat, y)

DPS_METHOD(DPSnewpath)

DPS_METHOD_4(DPSpathbbox, CGFloat *, llx, CGFloat *, lly, CGFloat *, urx, CGFloat *, ury)

DPS_METHOD_6(DPSrcurveto, CGFloat, x1, CGFloat, y1, CGFloat, x2, CGFloat, y2, CGFloat, x3, CGFloat, y3)

DPS_METHOD_4(DPSrectclip, CGFloat, x, CGFloat, y, CGFloat, w, CGFloat, h)

DPS_METHOD_4(DPSrectfill, CGFloat, x, CGFloat, y, CGFloat, w, CGFloat, h)

DPS_METHOD_4(DPSrectstroke, CGFloat, x, CGFloat, y, CGFloat, w, CGFloat, h)

DPS_METHOD(DPSreversepath)

DPS_METHOD_2(DPSrlineto, CGFloat, x, CGFloat, y)

DPS_METHOD_2(DPSrmoveto, CGFloat, x, CGFloat, y)

DPS_METHOD(DPSstroke)

DPS_METHOD_1(DPSshfill, NSDictionary *, shaderDictionary)

DPS_METHOD_1(GSSendBezierPath, NSBezierPath *, path)

DPS_METHOD_2(GSRectClipList, const NSRect *, rects, int, count)

DPS_METHOD_2(GSRectFillList, const NSRect *, rects, int, count)


/* ----------------------------------------------------------------------- */
/* Window system ops */
/* ----------------------------------------------------------------------- */
DPS_METHOD_3(GSCurrentDevice, void**, device, int*, x, int*, y)

DPS_METHOD_2(DPScurrentoffset, int*, x, int*, y)

DPS_METHOD_3(GSSetDevice, void*, device, int, x, int, y)

DPS_METHOD_2(DPSsetoffset, short int, x, short int, y)


/*-------------------------------------------------------------------------*/
/* Graphics Extensions Ops */
/*-------------------------------------------------------------------------*/
DPS_METHOD_8(DPScomposite, CGFloat, x, CGFloat, y, CGFloat, w, CGFloat, h,
             NSInteger, gstateNum, CGFloat, dx, CGFloat, dy, NSCompositingOperation, op)

DPS_METHOD_5(DPScompositerect, CGFloat, x, CGFloat, y, CGFloat, w, CGFloat, h, NSCompositingOperation, op)

DPS_METHOD_8(DPSdissolve, CGFloat, x, CGFloat, y, CGFloat, w, CGFloat, h, NSInteger, gstateNum, CGFloat, dx, CGFloat, dy, CGFloat, delta)


DPS_METHOD_2(GSDrawImage, NSRect, rect, void *, imageref)

/** </ignore> */

/* ----------------------------------------------------------------------- */
/* Postscript Client functions */
/* ----------------------------------------------------------------------- */
static void
DPSPrintf(GSCTXT *ctxt, const char * fmt, ...)
{
  va_list ap;

  va_start(ap, fmt);
  if (fmt != NULL)
    (ctxt->methods->DPSPrintf__)
      (ctxt, @selector(DPSPrintf: :), fmt, ap);
  va_end(ap);
}

static inline void
DPSWriteData(GSCTXT *ctxt, const char * buf, unsigned int count)
{
  (ctxt->methods->DPSWriteData__)
    (ctxt, @selector(DPSWriteData: :), buf, count);
}

#endif	
