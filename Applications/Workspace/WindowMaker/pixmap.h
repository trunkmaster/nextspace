/*
 *  Window Maker window manager
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
 *  USA.
 */
#ifndef WMPIXMAP_H_
#define WMPIXMAP_H_



typedef struct WPixmap {
    Pixmap image;		       /* icon image */
    Pixmap mask;		       /* icon mask */
    int width, height;		       /* size of pixmap */
    int depth;			       /* depth of pixmap */
    unsigned int shared:1;	       /* if pixmaps should be kept
                                        * when structure is freed */
    unsigned int client_owned:1;
    unsigned int client_owned_mask:1;
} WPixmap;


WPixmap *wPixmapCreate(WScreen *scr, Pixmap image, Pixmap mask);

WPixmap *wPixmapCreateFromXPMData(WScreen *scr, char **data);

WPixmap *wPixmapCreateFromXBMData(WScreen *scr, char *data, char *mask,
                                  int width, int height, unsigned long fg,
                                  unsigned long bg);
void wPixmapDestroy(WPixmap *pix);

#endif
