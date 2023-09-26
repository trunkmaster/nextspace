/*
 File:       NSArray+utils.h
 Written By: Scott Anguish
 Created:    Dec 9, 1997
 Copyright:  Copyright 1997 by Scott Anguish, all rights reserved.
*/

#include <AppKit/AppKit.h>

@interface NSArray (utils)
- arrayByReplacingInEachStringValuesInArray:(NSArray *)values
                          withValuesInArray:(NSArray *)newValues;
- arrayWithShellCharactersQuoted;

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
                          row:(int)rowIndex;
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
@end

@interface NSMutableArray (utils)
- arrayByReplacingInEachStringValuesInArray:(NSArray *)values
                          withValuesInArray:(NSArray *)newValues;
- arrayWithShellCharactersQuoted;

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
                          row:(int)rowIndex;
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
@end
