/* Definition of class NSCollectionViewTransitionLayout
   Copyright (C) 2021 Free Software Foundation, Inc.
   
   By: Gregory John Casamento
   Date: 30-05-2021

   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#ifndef _NSCollectionViewTransitionLayout_h_GNUSTEP_GUI_INCLUDE
#define _NSCollectionViewTransitionLayout_h_GNUSTEP_GUI_INCLUDE

#import <AppKit/NSCollectionViewLayout.h>
#import <AppKit/AppKitDefines.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

typedef NSString* NSCollectionViewTransitionLayoutAnimatedKey;

APPKIT_EXPORT_CLASS
@interface NSCollectionViewTransitionLayout : NSCollectionViewLayout
{
  CGFloat _transitionProgress;
  NSCollectionViewLayout *_currentLayout;
  NSCollectionViewLayout *_nextLayout;
}

- (CGFloat) transitionProgress;
- (void) setTransitionProgress: (CGFloat)transitionProgress;

- (NSCollectionViewLayout *) currentLayout;
- (NSCollectionViewLayout *) nextLayout;

// Designated initializer
- (instancetype) initWithCurrentLayout: (NSCollectionViewLayout *)currentLayout
                            nextLayout: (NSCollectionViewLayout *)nextLayout;

- (void) updateValue: (CGFloat)value forAnimatedKey: (NSCollectionViewTransitionLayoutAnimatedKey)key;
- (CGFloat) valueForAnimatedKey: (NSCollectionViewTransitionLayoutAnimatedKey)key;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSCollectionViewTransitionLayout_h_GNUSTEP_GUI_INCLUDE */

