/** Interface for NSExpression for GNUStep
   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by:  Dr. H. Nikolaus Schaller
   Created: 2005

   This file is part of the GNUstep Base Library.

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

#ifndef __NSExpression_h_GNUSTEP_BASE_INCLUDE
#define __NSExpression_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if	OS_API_VERSION(MAC_OS_X_VERSION_10_4, GS_API_LATEST)

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSArray;
@class NSMutableDictionary;
@class NSString;

enum
{
  NSConstantValueExpressionType = 0,
  NSEvaluatedObjectExpressionType,
  NSVariableExpressionType,
  NSKeyPathExpressionType,
  NSFunctionExpressionType,
  NSKeyPathCompositionExpressionType,
#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
  NSUnionSetExpressionType,
  NSIntersectSetExpressionType,
  NSMinusSetExpressionType,
  NSSubqueryExpressionType = 13,
  NSAggregateExpressionType = 14,
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_9, GS_API_LATEST)
  NSAnyKeyExpressionType = 15,
#endif
  NSBlockExpressionType = 19,
#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
  NSConditionalExpressionType = 20
#endif
};
typedef NSUInteger NSExpressionType;

GS_EXPORT_CLASS
@interface NSExpression : NSObject <NSCoding, NSCopying>
{
#if	GS_EXPOSE(NSExpression)
  NSExpressionType _type;
#endif
}

+ (NSExpression *) expressionForConstantValue: (id)obj;
+ (NSExpression *) expressionForEvaluatedObject;
+ (NSExpression *) expressionForFunction: (NSString *)name
			       arguments: (NSArray *)args;
+ (NSExpression *) expressionForKeyPath: (NSString *)path;
+ (NSExpression *) expressionForVariable: (NSString *)string;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
+ (NSExpression *) expressionForIntersectSet: (NSExpression *)left
					with: (NSExpression *)right;
+ (NSExpression *) expressionForAggregate: (NSArray *)subExpressions;
+ (NSExpression *) expressionForUnionSet: (NSExpression *)left
				    with: (NSExpression *)right;
+ (NSExpression *) expressionForMinusSet: (NSExpression *)left
				    with: (NSExpression *)right;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
+ (NSExpression *) expressionWithFormat: (NSString *)format, ...;
+ (NSExpression *) expressionWithFormat: (NSString *)format
			      arguments: (va_list)args;
+ (NSExpression *) expressionWithFormat: (NSString *)format
			  argumentArray: (NSArray *)args;
#endif

- (NSArray *) arguments;
- (id) constantValue;
- (NSExpressionType) expressionType;
- (id) expressionValueWithObject: (id)object
			 context: (NSMutableDictionary *)context;
- (NSString *) function;
- (id) initWithExpressionType: (NSExpressionType) type;
- (NSString *) keyPath;
- (NSExpression *) operand;
- (NSString *) variable;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
- (id) collection;
- (NSExpression *) leftExpression;
- (NSExpression *) rightExpression;
#endif
@end

#if	defined(__cplusplus)
}
#endif

#endif	/* 100400 */

#endif /* __NSExpression_h_GNUSTEP_BASE_INCLUDE */
