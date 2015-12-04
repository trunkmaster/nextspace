/*
 * Raster graphics library
 *
 * Copyright (c) 2014 Window Maker Team
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

/*
 * Functions to convert images to given color depths
 *
 * The functions here are for WRaster library's internal use only,
 * Please use functions in 'wraster.h' in applications
 */

#ifndef WRASTER_CONVERT_H
#define WRASTER_CONVERT_H


/*
 * Function for to release internal Conversion Tables
 */
void r_destroy_conversion_tables(void);


#endif
