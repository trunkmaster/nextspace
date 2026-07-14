/* Implementation of class NSItemProvider
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: heron
   Date: Sun Nov 10 04:00:17 EST 2019

   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#import "Foundation/NSItemProvider.h"
#import "Foundation/NSString.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"

@implementation NSItemProvider

- (instancetype) init
{
  return [self notImplemented: _cmd];
}

- (void) registerDataRepresentationForTypeIdentifier: (NSString *)typeIdentifier
                                          visibility: (NSItemProviderRepresentationVisibility)visibility
                                         loadHandler: (GSProgressHandler)loadHandler
{
  [self notImplemented: _cmd];
}

- (void) registerFileRepresentationForTypeIdentifier: (NSString *)typeIdentifier
                                         fileOptions: (NSItemProviderFileOptions)fileOptions
                                          visibility: (NSItemProviderRepresentationVisibility)visibility
                                         loadHandler: (GSProgressURLBOOLHandler)loadHandler
{
  [self notImplemented: _cmd];
}

- (NSArray *) registeredTypeIdentifiers
{
  return [self notImplemented: _cmd];
}

- (NSArray *) registeredTypeIdentifiersWithFileOptions: (NSItemProviderFileOptions)fileOptions
{
  return [self notImplemented: _cmd];
}

- (BOOL) hasItemConformingToTypeIdentifier: (NSString *)typeIdentifier
{
  return NO;
}

- (BOOL) hasRepresentationConformingToTypeIdentifier: (NSString *)typeIdentifier
                                         fileOptions: (NSItemProviderFileOptions)fileOptions
{
  return NO;
}

- (NSProgress *) loadDataRepresentationForTypeIdentifier: (NSString *)typeIdentifier
                                       completionHandler: (GSProviderCompletionHandler)completionHandler
{
  return [self notImplemented: _cmd];
}

- (NSProgress *) loadFileRepresentationForTypeIdentifier: (NSString *)typeIdentifier
                                       completionHandler: (GSProviderURLCompletionHandler)completionHandler
{
  return [self notImplemented: _cmd];
}

- (NSProgress *) loadInPlaceFileRepresentationForTypeIdentifier: (NSString *)typeIdentifier
                                              completionHandler: (GSProviderURLBOOLCompletionHandler)completionHandler
{
  return [self notImplemented: _cmd];
}

- (NSString *) suggestedName
{
  return [self notImplemented: _cmd];
}

- (void) setSuggestedName: (NSString *)suggestedName
{
  [self notImplemented: _cmd];
}

- (instancetype) initWithObject: (id<NSItemProviderWriting>)object
{
  return [self notImplemented: _cmd];
}

- (void) registerObject: (id<NSItemProviderWriting>)object visibility: (NSItemProviderRepresentationVisibility)visibility
{
  [self notImplemented: _cmd];
}

- (void) registerObjectOfClass: (Class<NSItemProviderWriting>)aClass  // NSItemProviderWriting conforming class...
                    visibility: (NSItemProviderRepresentationVisibility)visibility
                   loadHandler: (GSItemProviderWritingHandler)loadHandler
{
  [self notImplemented: _cmd];
}

- (BOOL) canLoadObjectOfClass: (Class<NSItemProviderReading>)aClass
{
  return NO;
}

- (NSProgress *) loadObjectOfClass: (Class<NSItemProviderReading>)aClass // NSItemProviderReading conforming class...
                 completionHandler: (GSItemProviderReadingHandler)completionHandler
{
  return [self notImplemented: _cmd];
}

- (instancetype) initWithItem: (id<NSSecureCoding>)item typeIdentifier: (NSString *)typeIdentifier // designated init
{
  return [self notImplemented: _cmd];
}

- (instancetype) initWithContentsOfURL: (NSURL *)fileURL
{
  return [self notImplemented: _cmd];
}

- (void) registerItemForTypeIdentifier: (NSString *)typeIdentifier loadHandler: (NSItemProviderLoadHandler)loadHandler
{
  [self notImplemented: _cmd];
}

- (void)loadItemForTypeIdentifier: (NSString *)typeIdentifier
                          options: (NSDictionary *)options
                completionHandler: (NSItemProviderCompletionHandler)completionHandler
{
  [self notImplemented: _cmd];
}

- (instancetype) copyWithZone: (NSZone*)zone
{
  return [self notImplemented: _cmd];
}
@end

// Preview support

@implementation NSItemProvider (NSPreviewSupport)

- (NSItemProviderLoadHandler) previewImageHandler
{
  return (NSItemProviderLoadHandler)0;
}

- (void) setPreviewImageHandler: (NSItemProviderLoadHandler) previewImageHandler
{
  [self notImplemented: _cmd];
}
  
- (void) loadPreviewImageWithOptions: (NSDictionary *)options
                   completionHandler: (NSItemProviderCompletionHandler)completionHandler
{
  [self notImplemented: _cmd];
}

@end
