/* alpha_combine.c - Alpha channel combination, based on Gimp 1.1.24
 * The GIMP -- an image manipulation program
 * Copyright (C) 1995 Spencer Kimball and Peter Mattis
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

#include "wraster.h"

void RCombineAlpha(unsigned char *d, unsigned char *s, int s_has_alpha,
		   int width, int height, int dwi, int swi, int opacity) {
	int x, y;
	int t, sa;
	int alpha;
	float ratio, cratio;

	for (y=0; y<height; y++) {
		for (x=0; x<width; x++) {
			sa=s_has_alpha?*(s+3):255;

			if (opacity!=255) {
				t = sa * opacity + 0x80;
				sa = ((t>>8)+t)>>8;
			}

			t = *(d+3) * (255-sa) + 0x80;
			alpha = sa + (((t>>8)+t)>>8);

			if (sa==0 || alpha==0) {
				ratio = 0;
				cratio = 1.0;
			} else if(sa == alpha) {
				ratio = 1.0;
				cratio = 0;
			} else {
				ratio = (float)sa / alpha;
				cratio = 1.0F - ratio;
			}

			*d = (int)*d * cratio + (int)*s * ratio;
			s++; d++;
			*d = (int)*d * cratio + (int)*s * ratio;
			s++; d++;
			*d = (int)*d * cratio + (int)*s * ratio;
			s++; d++;
			*d = alpha;
			d++;

			if (s_has_alpha) s++;
		}
		d+=dwi;
		s+=swi;
	}
}
