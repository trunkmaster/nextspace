/* GormViewWithSubviewsEditor.h
 *
 * Copyright (C) 2002 Free Software Foundation, Inc.
 *
 * Author:	Pierre-Yves Rivaille <pyrivail@ens-lyon.fr>
 * Date:	2002
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
#ifndef	INCLUDED_GormViewWithSubviewsEditor_h
#define	INCLUDED_GormViewWithSubviewsEditor_h

#include <GormCore/GormViewEditor.h>

@interface GormViewWithSubviewsEditor : GormViewEditor <IBSelectionOwners>
{
  BOOL _displaySelection;
  GormViewWithSubviewsEditor *openedSubeditor;
  NSMutableArray *selection;
  BOOL opened;
  BOOL _followGuideLine;
}

/*
 * Handle mouse click on knob.
 */
- (void) handleMouseOnKnob: (IBKnobPosition) knob
		    ofView: (GormViewEditor *) view
		 withEvent: (NSEvent *) theEvent;

/*
 * Handle mouse click on view.
 */
- (void) handleMouseOnView: (GormViewEditor *) view
		 withEvent: (NSEvent *) theEvent;

- (void) setOpenedSubeditor: (GormViewWithSubviewsEditor *) newEditor;
- (void) openParentEditor;
- (void) makeSubeditorResign;
- (void) silentlyResetSelection;
- (void) selectObjects: (NSArray *) objects;
- (void) copySelection;

/*
 * Close subeditors of this editor.
 */
- (void) closeSubeditors;
- (void) deactivateSubeditors;
- (void) changeFont: (id)sender;
@end

#endif
