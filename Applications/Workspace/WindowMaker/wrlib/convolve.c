/*
 * Raster graphics library
 *
 * Copyright (c) 1997-2003 Alfredo K. Kojima
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public
 *  License along with this library; if not, write to the Free
 *  Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

#include <config.h>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <X11/Xlib.h>
#include "wraster.h"

/*
 *----------------------------------------------------------------------
 * RBlurImage--
 * 	Apply 3x3 1 1 1 low pass, convolution mask to image.
 *                1 2 1
 *                1 1 1 /10
 *----------------------------------------------------------------------
 */
int RBlurImage(RImage * image)
{
	register int x, y;
	register int tmp;
	unsigned char *ptr, *nptr;
	unsigned char *pptr = NULL, *tmpp;
	int ch = image->format == RRGBAFormat ? 4 : 3;

	pptr = malloc(image->width * ch);
	if (!pptr) {
		RErrorCode = RERR_NOMEMORY;
		return False;
	}
#define MASK(prev, cur, next, ch)\
    (*(prev-ch) + *prev + *(prev+ch)\
    +*(cur-ch) + 2 * *cur + *(cur+ch)\
    +*(next-ch) + *next + *(next+ch)) / 10

	memcpy(pptr, image->data, image->width * ch);

	ptr = image->data;
	nptr = ptr + image->width * ch;
	tmpp = pptr;

	if (ch == 3) {
		ptr += 3;
		nptr += 3;
		pptr += 3;

		for (y = 1; y < image->height - 1; y++) {

			for (x = 1; x < image->width - 1; x++) {
				tmp = *ptr;
				*ptr = MASK(pptr, ptr, nptr, 3);
				*pptr = tmp;
				ptr++;
				nptr++;
				pptr++;

				tmp = *ptr;
				*ptr = MASK(pptr, ptr, nptr, 3);
				*pptr = tmp;
				ptr++;
				nptr++;
				pptr++;

				tmp = *ptr;
				*ptr = MASK(pptr, ptr, nptr, 3);
				*pptr = tmp;
				ptr++;
				nptr++;
				pptr++;
			}
			pptr = tmpp;
			ptr += 6;
			nptr += 6;
			pptr += 6;
		}
	} else {
		ptr += 4;
		nptr += 4;
		pptr += 4;

		for (y = 1; y < image->height - 1; y++) {
			for (x = 1; x < image->width - 1; x++) {
				tmp = *ptr;
				*ptr = MASK(pptr, ptr, nptr, 4);
				*pptr = tmp;
				ptr++;
				nptr++;
				pptr++;

				tmp = *ptr;
				*ptr = MASK(pptr, ptr, nptr, 4);
				*pptr = tmp;
				ptr++;
				nptr++;
				pptr++;

				tmp = *ptr;
				*ptr = MASK(pptr, ptr, nptr, 4);
				*pptr = tmp;
				ptr++;
				nptr++;
				pptr++;

				tmp = *ptr;
				*ptr = MASK(pptr, ptr, nptr, 4);
				*pptr = tmp;
				ptr++;
				nptr++;
				pptr++;
			}
			pptr = tmpp;
			ptr += 8;
			nptr += 8;
			pptr += 8;
		}
	}

	free(tmpp);

	return True;
}

