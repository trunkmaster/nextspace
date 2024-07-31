/*
 *  Window Maker window manager
 *
 *  Copyright (c) 2021 Window Maker Team
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
 *  with this program, see the file COPYING.
 */

/*
 * This file defines the basic stuff for WRaster's message
 * internationalization in the code
 */

#ifndef WRASTER_I18N_H
#define WRASTER_I18N_H

#if defined(HAVE_LIBINTL_H) && defined(I18N)
#include <libintl.h>
#define _(text) dgettext("WRaster", (text))
#else
#define _(text) (text)
#endif

/*
 * the N_ macro is used for initializers, it will make xgettext pick the
 * string for translation when generating PO files
 */
#define N_(text) (text)

#endif