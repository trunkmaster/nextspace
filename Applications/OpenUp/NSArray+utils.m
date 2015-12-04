/*
 File:       NSArray+utils.m 
 Written By: Scott Anguish
 Created:    Dec 9, 1997
 Copyright:  Copyright 1997 by Scott Anguish, all rights reserved.
*/

#include "NSArray+utils.h"
#include "NSString+utils.h"

@implementation NSArray(utils)

- arrayByReplacingInEachStringValuesInArray:(NSArray *)values withValuesInArray:(NSArray *)newValues
{
    NSEnumerator *theEnumerator;
    NSString *eachString;
    NSMutableArray *theArray=[NSMutableArray array];


    theEnumerator=[self objectEnumerator];
    while ((eachString = [theEnumerator nextObject]))
      {
        NSString *tempString;

        tempString=[eachString stringByReplacingValuesInArray:values withValuesInArray:newValues];
        if (tempString)
            [theArray addObject:tempString];
      }
    return [NSArray arrayWithArray:theArray];
}

- arrayWithShellCharactersQuoted
{
    NSEnumerator *theEnumerator;
    NSString *eachString;
    NSMutableArray *theArray=[NSMutableArray array];


    theEnumerator=[self objectEnumerator];
    while ((eachString = [theEnumerator nextObject]))
      {
        NSString *tempString;

        tempString=[eachString stringWithShellCharactersQuoted];
        if (tempString)
            [theArray addObject:tempString];
      }
    return [NSArray arrayWithArray:theArray];
}


- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(int)rowIndex
{
    id theRecord, theValue;

    NSParameterAssert(rowIndex >= 0 && rowIndex < [self count]);
    theRecord = [self objectAtIndex:rowIndex];
    theValue = [theRecord objectForKey:[aTableColumn identifier]];
    return theValue;
}


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [self count];
}

@end


@implementation NSMutableArray (utils)

- arrayByReplacingInEachStringValuesInArray:(NSArray *)values withValuesInArray:(NSArray *)newValues;
{
    NSEnumerator *theEnumerator;
    NSString *eachString;
    NSMutableArray *theArray=[NSMutableArray array];


    theEnumerator=[self objectEnumerator];
    while ((eachString = [theEnumerator nextObject]))
      {
        NSString *tempString;

        tempString=[eachString stringByReplacingValuesInArray:values withValuesInArray:newValues];
        if (tempString)
            [theArray addObject:tempString];
      }
    return [NSArray arrayWithArray:theArray];
}

- arrayWithShellCharactersQuoted
{
    NSEnumerator *theEnumerator;
    NSString *eachString;
    NSMutableArray *theArray=[NSMutableArray array];


    theEnumerator=[self objectEnumerator];
    while ((eachString = [theEnumerator nextObject]))
      {
        NSString *tempString;

        tempString=[eachString stringWithShellCharactersQuoted];
        if (tempString)
            [theArray addObject:tempString];
      }
    return [NSArray arrayWithArray:theArray];
}


- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(int)rowIndex
{
    id theRecord, theValue;

    NSParameterAssert(rowIndex >= 0 && rowIndex < [self count]);
    theRecord = [self objectAtIndex:rowIndex];
    theValue = [theRecord objectForKey:[aTableColumn identifier]];
    return theValue;
}


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [self count];
}
@end
