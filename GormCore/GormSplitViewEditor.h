/* GormSplitViewEditor.h - Editor for splitviews.
 *
 * Copyright (C) 2002 Free Software Foundation, Inc.
 *
 * Author:	Pierre-Yves Rivaille
 * Date:	Aug 2002
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */
#ifndef	INCLUDED_GormSplitViewEditor_h
#define	INCLUDED_GormSplitViewEditor_h

#include <GormCore/GormViewWithSubviewsEditor.h>

@interface GormSplitViewEditor : GormViewWithSubviewsEditor
{
}
- (NSArray *)destroyAndListSubviews;
@end

#endif
