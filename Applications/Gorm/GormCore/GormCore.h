/* GormCore.h
*
* Copyright (C) 2019 Free Software Foundation, Inc.
*
* Author:  Lars Sonchocky-Helldorf
* Date:  01.11.19
*
* This file is part of GNUstep.
*
* This program is free software; you can redistribute it and/or modify
* it under the terms of the GNU Lesser General Public License as published by
* the Free Software Foundation; either version 2.1 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Lesser General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
*/

#import <Foundation/Foundation.h>

#ifndef GNUSTEP
//! Project version number for GormCore.
FOUNDATION_EXPORT double GormCoreVersionNumber;

//! Project version string for GormCore.
FOUNDATION_EXPORT const unsigned char GormCoreVersionString[];
#endif

#ifndef INCLUDED_GORMCORE_H
#define INCLUDED_GORMCORE_H

#import <GormCore/GormAbstractDelegate.h>
#import <GormCore/GormBoxEditor.h>
#import <GormCore/GormClassEditor.h>
#import <GormCore/GormClassInspector.h>
#import <GormCore/GormClassManager.h>
#import <GormCore/GormClassPanelController.h>
#import <GormCore/GormConnectionInspector.h>
#import <GormCore/GormControlEditor.h>
#import <GormCore/GormCustomClassInspector.h>
#import <GormCore/GormCustomView.h>
#import <GormCore/GormDefines.h>
#import <GormCore/GormDocument.h>
#import <GormCore/GormDocumentController.h>
#import <GormCore/GormDocumentWindow.h>
#import <GormCore/GormFilePrefsManager.h>
#import <GormCore/GormFilesOwner.h>
#import <GormCore/GormFontViewController.h>
#import <GormCore/GormFunctions.h>
#import <GormCore/GormGenericEditor.h>
#import <GormCore/GormHelpInspector.h>
#import <GormCore/GormImage.h>
#import <GormCore/GormImageEditor.h>
#import <GormCore/GormImageInspector.h>
#import <GormCore/GormInspectorsManager.h>
#import <GormCore/GormInternalViewEditor.h>
#import <GormCore/GormMatrixEditor.h>
#import <GormCore/GormNSPanel.h>
#import <GormCore/GormNSSplitViewInspector.h>
#import <GormCore/GormNSWindow.h>
#import <GormCore/GormObjectEditor.h>
#import <GormCore/GormObjectInspector.h>
#import <GormCore/GormOpenGLView.h>
#import <GormCore/GormOutlineView.h>
#import <GormCore/GormPalettesManager.h>
#import <GormCore/GormPlacementInfo.h>
#import <GormCore/GormPlugin.h>
#import <GormCore/GormPluginManager.h>
#import <GormCore/GormPrivate.h>
#import <GormCore/GormProtocol.h>
#import <GormCore/GormResource.h>
#import <GormCore/GormResourceEditor.h>
#import <GormCore/GormResourceManager.h>
#import <GormCore/GormScrollViewAttributesInspector.h>
#import <GormCore/GormServer.h>
#import <GormCore/GormSetNameController.h>
#import <GormCore/GormSound.h>
#import <GormCore/GormSoundEditor.h>
#import <GormCore/GormSoundInspector.h>
#import <GormCore/GormSoundView.h>
#import <GormCore/GormSplitViewEditor.h>
#import <GormCore/GormStandaloneViewEditor.h>
#import <GormCore/GormViewEditor.h>
#import <GormCore/GormViewKnobs.h>
#import <GormCore/GormViewSizeInspector.h>
#import <GormCore/GormViewWindow.h>
#import <GormCore/GormViewWithContentViewEditor.h>
#import <GormCore/GormViewWithSubviewsEditor.h>
#import <GormCore/GormWindowEditor.h>
#import <GormCore/GormWindowTemplate.h>
#import <GormCore/GormWrapperBuilder.h>
#import <GormCore/GormWrapperLoader.h>
#import <GormCore/GormXLIFFDocument.h>
#import <GormCore/NSCell+GormAdditions.h>
#import <GormCore/NSColorWell+GormExtensions.h>
#import <GormCore/NSFontManager+GormExtensions.h>
#import <GormCore/NSView+GormExtensions.h>

#endif

