/* -*-objc-*-
   NSCollectionViewItem.h

   Copyright (C) 2013 Free Software Foundation, Inc.

   Author: Doug Simons (doug.simons@testplant.com)
           Frank LeGrand (frank.legrand@testplant.com)
   Date: February 2013
   
   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/

#ifndef _GNUstep_H_NSCollectionViewItem
#define _GNUstep_H_NSCollectionViewItem
#import <AppKit/AppKitDefines.h>

#import <Foundation/NSArray.h>
#import <AppKit/NSViewController.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)

#if defined(__cplusplus)
extern "C" {
#endif

@class NSImageView, NSTextField;
  
APPKIT_EXPORT_CLASS
@interface NSCollectionViewItem : NSViewController <NSCopying>
{
  IBOutlet NSTextField *textField;
  IBOutlet NSImageView *imageView;
  BOOL _isSelected;
}

- (NSCollectionView *)collectionView;
- (NSArray *)draggingImageComponents;

- (void)setSelected:(BOOL)shouldBeSelected;
- (BOOL)isSelected;

- (NSTextField *)textField;
- (void)setTextField:(NSTextField *)aTextField;

- (NSImageView *)imageView;
- (void)setImageView:(NSImageView *)anImageView;

@end

#if defined(__cplusplus)
}
#endif
  
#endif /* OS_API_MACOSX */

#endif /* _GNUstep_H_NSCollectionViewItem */
