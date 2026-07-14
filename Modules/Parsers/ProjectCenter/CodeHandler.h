/*
**  CodeHandler.h
**
**  Copyright (c) 2003
**
**  Author: Yen-Ju  <yjchenx@hotmail.com>
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
**
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU General Public License
**  along with this program; if not, write to the Free Software
**  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef _CodeHandler_H_
#define _CodeHandler_H_

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

typedef enum _CommentType {
  NoComment,
  MultipleLineComment,
  SingleLineComment
} CommentType;

@class NSString;

@protocol CodeHandler <NSObject>

/* Called by CodeParser */
- (void)string:(NSString *)element;
- (void)number:(NSString *)element;
- (void)spaceAndNewLine:(unichar)element;
- (void)symbol:(unichar)element;
- (void)invisible:(unichar)element;

@end

#endif /* _CodeHandler_H_ */
