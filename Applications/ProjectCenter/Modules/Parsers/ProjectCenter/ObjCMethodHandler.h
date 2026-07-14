/*
**  ObjCMethodHandler.h
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

#ifndef _ObjCMethodHandler_H_
#define _ObjCMethodHandler_H_

#import "CodeHandler.h"

#import "ObjCCommentHandler.h"

/**
 * MethodStart MethodSymbol   MethodReturnValue        MethodName      MethodEnd
 *                 +/-      (        id         )  simpleMethod:value      ;
 *
 * MethodStart is after each ';' or new line
 * MethodSymbol is +/- for objective-C
 * MethodReturnValue is surround by '(' and ')', and can be ignore
 * MethodName contain method name and messages
 * MethodNone is not method;
 */

typedef enum _CheckStep {
  MethodStart, 
  MethodBody,
  MethodSymbol,
  MethodReturnValue,
  MethodName,
  MethodParameterStart,
  MethodParameter,
  MethodNone
} CheckStep;


@class NSMutableString;
@class NSMutableArray;

@interface ObjCMethodHandler : ObjCCommentHandler <CodeHandler>
{
  NSUInteger      position;

  BOOL            inSpace;
  NSMutableString *method;
  NSMutableArray  *methods;
  unichar         _preSymbol;
  NSUInteger      nameBeginPosition;
  NSUInteger      nameEndPosition;
  NSUInteger      bodyBeginPosition;
  NSInteger       bodySymbolCount;

  CheckStep       step;
  CheckStep       prev_step;
}

// NSArray of NSDictionaries 
// MethodName = NSString;
// MethodNameRange = NSString <- NSStringFromRange(NSRange)
// MethodBodyRange = NSString <- NSStringFromRange(NSRange)
- (NSArray *)methods;

- (void)addMethodToArray;

@end

#endif /* _ObjCMethodHandler_H_ */
