/********************************************************************
 * text.c -- a basic text field                                     *
 * Copyright (C) 1997 Robin D. Clark                                *
 *                                                                  *
 * This program is free software; you can redistribute it and/or    *
 * modify it under the terms of the GNU General Public License as   *
 * published by the Free Software Foundation; either version 2 of   *
 * the License, or (at your option) any later version.              *
 *                                                                  *
 * This program is distributed in the hope that it will be useful,  *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of   *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the    *
 * GNU General Public License for more details.                     *
 *                                                                  *
 * You should have received a copy of the GNU General Public License*
 * along with this program; if not, write to the Free Software      *
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.        *
 *                                                                  *
 *   Author: Rob Clark                                              *
 * Internet: rclark@cs.hmc.edu                                      *
 *  Address: 609 8th Street                                         *
 *           Huntington Beach, CA 92648-4632                        *
 ********************************************************************/

#include "wconfig.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "WindowMaker.h"
#include "funcs.h"
#include "text.h"
#include "actions.h"

/* X11R5 don't have this */
#ifndef IsPrivateKeypadKey
#define IsPrivateKeypadKey(keysym) \
    (((KeySym)(keysym) >= 0x11000000) && ((KeySym)(keysym) <= 0x1100FFFF))
#endif


#ifdef DEBUG
#  define  ENTER(X)  fprintf(stderr,"Entering:  %s()\n", X);
#  define  LEAVE(X)  fprintf(stderr,"Leaving:   %s()\n", X);
#  define  PDEBUG(X)  fprintf(stderr,"debug:     %s()\n", X);
#else
#  define  ENTER(X)
#  define  LEAVE(X)
#  define  PDEBUG(X)
#endif

extern Cursor wCursor[WCUR_LAST];

/********************************************************************
 * The event handler for the text-field:                            *
 ********************************************************************/
static void textEventHandler( WObjDescriptor *desc, XEvent *event );

static void handleExpose( WObjDescriptor *desc, XEvent *event );

static void textInsert( WTextInput *wtext, char *txt );
#if 0
static void blink(void *data);
#endif

/********************************************************************
 * handleKeyPress                                                   *
 *   handle cursor keys, regular keys, etc.  Inserts characters in  *
 *   text field, at cursor position, if it is a "Normal" key.  If   *
 *   ksym is the delete key, backspace key, etc., the appropriate   *
 *   action is performed on the text in the text field.  Does not   *
 *   refresh the text field                                         *
 *                                                                  *
 * Args:   wText - the text field                                   *
 *         ksym  - the key that was pressed                         *
 * Return: True, unless the ksym is ignored                         *
 * Global: modifier - the bitfield that keeps track of the modifier *
 *                    keys that are down                            *
 ********************************************************************/
static int
handleKeyPress( WTextInput *wtext, XKeyEvent *event )
{
    KeySym ksym;
    char buffer[32];
    int count;

    count = XLookupString(event, buffer, 32, &ksym, NULL);

    /* Ignore these keys: */
    if( IsFunctionKey(ksym)      || IsKeypadKey(ksym) ||
       IsMiscFunctionKey(ksym)  || IsPFKey(ksym)     ||
       IsPrivateKeypadKey(ksym) )
        /* If we don't handle it, make sure it isn't a key that
         * the window manager needs to see */
        return False;

    /* Take care of the cursor keys.. ignore up and down
     * cursor keys */
    else if( IsCursorKey(ksym) )
    {
        int length = wtext->text.length;
        switch(ksym)
        {
        case XK_Home:
        case XK_Begin:
            wtext->text.endPos = 0;
            break;
        case XK_Left:
            wtext->text.endPos--;
            break;
        case XK_Right:
            wtext->text.endPos++;
            break;
        case XK_End:
            wtext->text.endPos = length;
            break;
        default:
            return False;
        }
        /* make sure that the startPos and endPos have values
         * that make sense  (ie the are in [0..length] ) */
        if( wtext->text.endPos < 0 )
            wtext->text.endPos = 0;
        if( wtext->text.endPos > length )
            wtext->text.endPos = length;
        wtext->text.startPos = wtext->text.endPos;
    }
    else
    {
        switch(ksym)
        {
            /* Ignore these keys: */
        case XK_Escape:
            wtext->canceled = True;
        case XK_Return:
            wtext->done = True;
            break;
        case XK_Tab:
        case XK_Num_Lock:
            break;

        case XK_Delete:
            /* delete after cursor */
            if( (wtext->text.endPos == wtext->text.startPos) &&
               (wtext->text.endPos < wtext->text.length) )
                wtext->text.endPos++;
            textInsert( wtext, "" );
            break;
        case XK_BackSpace:
            /* delete before cursor */
            if(  (wtext->text.endPos == wtext->text.startPos) &&
               (wtext->text.startPos > 0) )
                wtext->text.startPos--;
            textInsert( wtext, "" );
            break;
        default:
            if (count==1 && !iscntrl(buffer[0])) {
                buffer[count] = 0;
                textInsert( wtext, buffer);
            }
        }
    }
    return True;
}



/********************************************************************
 * textXYtoPos                                                      *
 *   given X coord, return position in array                        *
 ********************************************************************/
static int
textXtoPos( WTextInput *wtext, int x )
{
    int pos;
    x -= wtext->xOffset;

    for( pos=0; wtext->text.txt[pos] != '\0'; pos++ )
    {
        if( x < 0 )
            break;
        else
            x -= WMWidthOfString( wtext->font, &(wtext->text.txt[pos]), 1 );
    }

    return pos;
}

/********************************************************************
 * wTextCreate                                                      *
 *   create an instance of a text class                             *
 *                                                                  *
 * Args:                                                            *
 * Return:                                                          *
 * Global: dpy - the display                                        *
 ********************************************************************/
WTextInput *
wTextCreate( WCoreWindow *core, int x, int y, int width, int height )
{
    WTextInput *wtext;

    ENTER("wTextCreate");

    wtext = wmalloc(sizeof(WTextInput));
    wtext->core = wCoreCreate( core, x, y, width, height );
    wtext->core->descriptor.handle_anything = &textEventHandler;
    wtext->core->descriptor.handle_expose = &handleExpose;
    wtext->core->descriptor.parent_type = WCLASS_TEXT_INPUT;
    wtext->core->descriptor.parent = wtext;

    wtext->font = core->screen_ptr->menu_entry_font;

    XDefineCursor( dpy, wtext->core->window, wCursor[WCUR_TEXT] );

    /* setup the text: */
    wtext->text.txt      = (char *)wmalloc(sizeof(char));
    wtext->text.txt[0]   = '\0';
    wtext->text.length   = 0;
    wtext->text.startPos = 0;
    wtext->text.endPos   = 0;

    {
        XGCValues gcv;

        gcv.foreground = core->screen_ptr->black_pixel;
        gcv.background = core->screen_ptr->white_pixel;
        gcv.line_width = 1;
        gcv.function   = GXcopy;

        wtext->gc = XCreateGC( dpy, wtext->core->window,
                              (GCForeground|GCBackground|
                               GCFunction|GCLineWidth),
                              &gcv );

        /* set up the regular context */
        gcv.foreground = core->screen_ptr->black_pixel;
        gcv.background = core->screen_ptr->white_pixel;
        gcv.line_width = 1;
        gcv.function   = GXcopy;

        wtext->regGC = XCreateGC( dpy, wtext->core->window,
                                 (GCForeground|GCBackground|
                                  GCFunction|GCLineWidth),
                                 &gcv );

        /* set up the inverted context */
        gcv.function   = GXcopyInverted;

        wtext->invGC = XCreateGC( dpy, wtext->core->window,
                                 (GCForeground|GCBackground|
                                  GCFunction|GCLineWidth),
                                 &gcv );

        /* and set the background! */
        XSetWindowBackground( dpy, wtext->core->window, gcv.background );
    }

    /* Figure out the y-offset... */
    wtext->yOffset = (height - WMFontHeight(wtext->font))/2;
    wtext->xOffset = wtext->yOffset;

    wtext->canceled     = False;
    wtext->done         = False;     /* becomes True when the user    *
    * hits "Return" key             */

    XMapRaised(dpy, wtext->core->window);

    LEAVE("wTextCreate");

    return wtext;
}

/********************************************************************
 * wTextDestroy                                                     *
 *                                                                  *
 * Args:   wtext  - the text field                                  *
 * Return:                                                          *
 * Global: dpy    - the display                                     *
 ********************************************************************/
void
wTextDestroy( WTextInput *wtext )
{
    ENTER("wTextDestroy")

#if 0
        if (wtext->magic)
            wDeleteTimerHandler(wtext->magic);
    wtext->magic = NULL;
#endif
    XFreeGC( dpy, wtext->gc );
    XFreeGC( dpy, wtext->regGC );
    XFreeGC( dpy, wtext->invGC );
    wfree( wtext->text.txt );
    wCoreDestroy( wtext->core );
    wfree( wtext );

    LEAVE("wTextDestroy");
}


/* The text-field consists of a frame drawn around the outside,
 * and a textbox inside.  The space between the frame and the
 * text-box is the xOffset,yOffset.  When the text needs refreshing,
 * we only have to redraw the part inside the text-box, and we can
 * leave the frame.  If we get an expose event, or for some reason
 * need to redraw the frame, wTextPaint will redraw the frame, and
 * then call wTextRefresh to redraw the text-box */


/********************************************************************
 * textRefresh                                                     *
 *   Redraw the text field.  Call this after messing with the text  *
 *   field.  wTextRefresh re-draws the inside of the text field. If *
 *   the frame-area of the text-field needs redrawing, call         *
 *   wTextPaint()                                                   *
 *                                                                  *
 * Args:   wtext  - the text field                                  *
 * Return: none                                                     *
 * Global: dpy    - the display                                     *
 ********************************************************************/
static void
textRefresh(WTextInput *wtext)
{
    WScreen *scr = wtext->core->screen_ptr;
    char *ptr = wtext->text.txt;
    int  x1,x2,y1,y2;

    /* x1,y1 is the upper left corner of the text box */
    x1 = wtext->xOffset;
    y1 = wtext->yOffset;
    /* x2,y2 is the lower right corner of the text box */
    x2 = wtext->core->width - wtext->xOffset;
    y2 = wtext->core->height - wtext->yOffset;

    /* Fill in the text field.  Use the invGC to draw the rectangle,
     * becuase then it will be the background color */
    XFillRectangle(dpy, wtext->core->window, wtext->invGC,
                   x1, y1, x2-x1, y2-y1);

    /* Draw the text normally */
    WMDrawImageString(scr->wmscreen, wtext->core->window,
                      scr->black, scr->white, wtext->font, x1, y1, ptr,
                      wtext->text.length);

    /* Draw the selected text */
    if (wtext->text.startPos != wtext->text.endPos) {
        int sp,ep;
        /* we need sp < ep */
        if (wtext->text.startPos > wtext->text.endPos) {
            sp = wtext->text.endPos;
            ep = wtext->text.startPos;
        } else {
            sp = wtext->text.startPos;
            ep = wtext->text.endPos;
        }

        /* x1,y1 is now the upper-left of the selected area */
        x1 += WMWidthOfString(wtext->font, ptr, sp);
        /* and x2,y2 is the lower-right of the selected area */
        ptr += sp * sizeof(char);
        x2 = x1 + WMWidthOfString(wtext->font, ptr, (ep - sp));
        /* Fill in the area  where the selected text will go:     *
         * use the regGC to draw the rectangle, becuase then it   *
         * will be the color of the non-selected text             */
        XFillRectangle(dpy, wtext->core->window, wtext->regGC,
                       x1, y1, x2-x1, y2-y1);

        /* Draw the selected text. Inverse bg and fg colors for selection */
        WMDrawImageString(scr->wmscreen, wtext->core->window,
                          scr->white, scr->black, wtext->font, x1, y1, ptr,
                          (ep - sp));
    }

    /* And draw a quick little line for the cursor position */
    x1 = WMWidthOfString(wtext->font, wtext->text.txt, wtext->text.endPos)
        + wtext->xOffset;
    XDrawLine(dpy, wtext->core->window, wtext->regGC, x1, 2, x1,
              wtext->core->height - 3);
}


/********************************************************************
 * wTextPaint                                                       *
 *                                                                  *
 * Args:   wtext  - the text field                                  *
 * Return:                                                          *
 * Global: dpy    - the display                                     *
 ********************************************************************/
void
wTextPaint( WTextInput *wtext )
{
    ENTER("wTextPaint");

    /* refresh */
    textRefresh( wtext );

    /* Draw box */
    XDrawRectangle(dpy, wtext->core->window, wtext->gc, 0, 0,
                   wtext->core->width-1, wtext->core->height-1);

    LEAVE("wTextPaint");
}


/********************************************************************
 * wTextGetText                                                     *
 *   return the string in the text field wText.  DO NOT FREE THE    *
 *   RETURNED STRING!                                               *
 *                                                                  *
 * Args:   wtext  - the text field                                  *
 * Return: the text in the text field (NULL terminated)             *
 * Global:                                                          *
 ********************************************************************/
char *
wTextGetText( WTextInput *wtext )
{
    if (!wtext->canceled)
        return wtext->text.txt;
    else
        return NULL;
}

/********************************************************************
 * wTextPutText                                                     *
 *   Put the string txt in the text field wText.  The text field    *
 *   needs to be explicitly refreshed after wTextPutText by calling *
 *   wTextRefresh().                                                *
 *   The string txt is copied                                       *
 *                                                                  *
 * Args:   wtext  - the text field                                  *
 *         txt    - the new text string... freed by the text field! *
 * Return: none                                                     *
 * Global:                                                          *
 ********************************************************************/
void
wTextPutText( WTextInput *wtext, char *txt )
{
    int length = strlen(txt);

    /* no memory leaks!  free the old txt */
    if( wtext->text.txt != NULL )
        wfree( wtext->text.txt );

    wtext->text.txt = (char *)wmalloc((length+1)*sizeof(char));
    strcpy(wtext->text.txt, txt );
    wtext->text.length   = length;
    /* By default No text is selected, and the cursor is at the end */
    wtext->text.startPos = length;
    wtext->text.endPos   = length;
}

/********************************************************************
 * textInsert                                                      *
 *   Insert some text at the cursor.  (if startPos != endPos,       *
 *   replace the selected text, otherwise insert)                   *
 *   The string txt is copied.                                      *
 *                                                                  *
 * Args:   wText  - the text field                                  *
 *         txt    - the new text string... freed by the text field! *
 * Return: none                                                     *
 * Global:                                                          *
 ********************************************************************/
static void
textInsert( WTextInput *wtext, char *txt )
{
    char *newTxt;
    int  newLen, txtLen, i,j;
    int  sp,ep;

    /* we need sp < ep */
    if( wtext->text.startPos > wtext->text.endPos )
    {
        sp = wtext->text.endPos;
        ep = wtext->text.startPos;
    }
    else
    {
        sp = wtext->text.startPos;
        ep = wtext->text.endPos;
    }

    txtLen = strlen(txt);
    newLen = wtext->text.length + txtLen - (ep - sp) + 1;

    newTxt = (char *)malloc(newLen*sizeof(char));

    /* copy the old text up to sp */
    for( i=0; i<sp; i++ )
        newTxt[i] = wtext->text.txt[i];

    /* insert new text */
    for( j=0; j<txtLen; j++,i++ )
        newTxt[i] = txt[j];

    /* copy old text after ep */
    for( j=ep; j<wtext->text.length; j++,i++ )
        newTxt[i] = wtext->text.txt[j];

    newTxt[i] = '\0';

    /* By default No text is selected, and the cursor is at the end
     * of inserted text */
    wtext->text.startPos = sp+txtLen;
    wtext->text.endPos   = sp+txtLen;

    wfree(wtext->text.txt);
    wtext->text.txt    = newTxt;
    wtext->text.length = newLen-1;
}

/********************************************************************
 * wTextSelect                                                      *
 *   Select some text.  If start == end, then the cursor is moved   *
 *   to that position.  If end == -1, then the text from start to   *
 *   the end of the text entered in the text field is selected.     *
 *   The text field is not automatically re-drawn!  You must call   *
 *   wTextRefresh to re-draw the text field.                        *
 *                                                                  *
 * Args:   wtext  - the text field                                  *
 *         start  - the beginning of the selected text              *
 *         end    - the end of the selected text                    *
 * Return: none                                                     *
 * Global:                                                          *
 ********************************************************************/
void
wTextSelect( WTextInput *wtext, int start, int end )
{
    if( end == -1 )
        wtext->text.endPos = wtext->text.length;
    else
        wtext->text.endPos = end;
    wtext->text.startPos = start;
}

#if 0
static void
blink(void *data)
{
    int x;
    WTextInput *wtext = (WTextInput*)data;
    GC gc;

    /* And draw a quick little line for the cursor position */
    if (wtext->blink_on) {
        gc = wtext->regGC;
        wtext->blink_on = 0;
    } else {
        gc = wtext->invGC;
        wtext->blink_on = 1;
    }
    x = WMWidthOfString( wtext->font, wtext->text.txt, wtext->text.endPos )
        + wtext->xOffset;
    XDrawLine( dpy, wtext->core->window, gc, x, 2, x, wtext->core->height-3);

    if (wtext->blinking)
        wtext->magic = wAddTimerHandler(CURSOR_BLINK_RATE, blink, data);
}
#endif

/********************************************************************
 * textEventHandler -- handles and dispatches all the events that   *
 *   the text field class supports                                  *
 *                                                                  *
 * Args:   desc - all we need to know about this object             *
 * Return: none                                                     *
 * Global:                                                          *
 ********************************************************************/
static void
textEventHandler( WObjDescriptor *desc, XEvent *event )
{
    WTextInput *wtext  = desc->parent;
    int   handled = False;      /* has the event been handled */

    switch( event->type )
    {
    case MotionNotify:
        /* If the button isn't down, we don't care about the
         * event, but otherwise we want to adjust the selected
         * text so we can wTextRefresh() */
        if( event->xmotion.state & (Button1Mask|Button3Mask|Button2Mask) )
        {
            PDEBUG("MotionNotify");
            handled = True;
            wtext->text.endPos = textXtoPos( wtext, event->xmotion.x );
        }
        break;

    case ButtonPress:
        PDEBUG("ButtonPress");
        handled = True;
        wtext->text.startPos = textXtoPos( wtext, event->xbutton.x );
        wtext->text.endPos   = wtext->text.startPos;
        break;

    case ButtonRelease:
        PDEBUG("ButtonRelease");
        handled = True;
        wtext->text.endPos = textXtoPos( wtext, event->xbutton.x );
        break;

    case KeyPress:
        PDEBUG("KeyPress");
        handled = handleKeyPress( wtext, &event->xkey );
        break;

    case EnterNotify:
        PDEBUG("EnterNotify");
        handled = True;
#if 0
        if (!wtext->magic)
        {
            wtext->magic = wAddTimerHandler(CURSOR_BLINK_RATE, blink, wtext);
            wtext->blink_on = !wtext->blink_on;
            blink(wtext);
            wtext->blinking = 1;
        }
#endif
        break;

    case LeaveNotify:
        PDEBUG("LeaveNotify");
        handled = True;
#if 0
        wtext->blinking = 0;
        if (wtext->blink_on)
            blink(wtext);
        if (wtext->magic)
            wDeleteTimerHandler(wtext->magic);
        wtext->magic = NULL;
#endif
        break;

    default:
        break;
    }

    if( handled )
        textRefresh(wtext);
    else
        WMHandleEvent(event);

    return;
}


static void
handleExpose(WObjDescriptor *desc, XEvent *event)
{
    wTextPaint(desc->parent);
}

