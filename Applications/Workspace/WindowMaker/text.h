/********************************************************************
 * text.h -- a basic text field                                     *
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

#ifndef __TEXT_H__
#define __TEXT_H__

#include "wcore.h"

typedef struct {
    char  *txt;                      /* ptr to the text               */
    int   length;                    /* length of txt[]               */
    int   startPos;                  /* beginning of selected text    */
    int   endPos;                    /* end of selected text          */
} WTextBlock;                        /* if startPos == endPos, no txt *
                                      * is selected... they give the  *
                                      * cursor position.              */
typedef struct {
    WCoreWindow *core;
    WMFont       *font;
    WTextBlock  text;
    GC	gc;
    GC    regGC;                     /* the normal GC                 */
    GC    invGC;                     /* inverted, for selected text   */
    WMagicNumber *magic;
    short xOffset;
    short yOffset;
    unsigned int done:1;
    unsigned int blink_on:1;
    unsigned int blinking:1;
    unsigned int canceled:1;
} WTextInput;


/** PROTOTYPES ******************************************************/
WTextInput* wTextCreate( WCoreWindow *core, int x, int y, int width,
                        int height );
void   wTextDestroy( WTextInput *wText );
void   wTextPaint( WTextInput *wText );
char*  wTextGetText( WTextInput *wText );
void   wTextPutText( WTextInput *wText, char *txt );
void   wTextInsert( WTextInput *wText, char *txt );
void   wTextSelect( WTextInput *wText, int start, int end );
void   wTextRefresh( WTextInput *wText );

#endif
