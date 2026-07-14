/*
**  ObjCClassHandler.h
**
**  Copyright (c) 2003-2013
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

#ifndef _ObjCClassHandler_H_
#define _ObjCClassHandler_H_

#import "CodeHandler.h"

#import "ObjCCommentHandler.h"

/**
 * ClassStart  ClassSymbol  ClassName  ClassSuper  ClassProto   | ClassCategory
 *             @...         CName      : CSuper    < Protocol > | ( Category )
 *
 * ClassStart is after each ';' or new line
 * ClassSymbol is '@' with 'interface'/'implementation' after that
 * ClassName started after ClassSymbol and next first ' '
 * ClassCategory is surround by '(' and ')'. Started after ClassName and ' '
 * ClassNone is not method;
 */

typedef enum _CS {
  ClassStart, 
  ClassSymbol,
  ClassName,
  ClassSuper,
  ClassProto,
  ClassCategory,
  ClassBody,
  ClassNone,
} CS;


@class NSMutableString;
@class NSMutableArray;

@interface ObjCClassHandler : ObjCCommentHandler <CodeHandler>
{
  NSUInteger      position;

  BOOL            inSpace;
  NSMutableString *keyword;
  NSMutableString *class;
  NSMutableArray  *classes;
  unichar         _preSymbol;
  NSUInteger      nameBeginPosition;
  NSUInteger      nameEndPosition;
  NSUInteger      bodyBeginPosition;
  NSInteger       bodySymbolCount;

  CS       step;
  CS       prev_step;
}

// NSArray of NSDictionaries 
// ClassName = NSString;
// ClassNameRange = NSString <- NSStringFromRange(NSRange)
// ClassBodyRange = NSString <- NSStringFromRange(NSRange)
- (NSArray *)classes;

- (void)addClassToArray;

@end

#endif /* _ObjCClassHandler_H_ */
