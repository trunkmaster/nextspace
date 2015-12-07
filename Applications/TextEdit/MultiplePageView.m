/*
        MultiplePageView.m
	Copyright (c) 1995-1996, NeXT Software, Inc.
        All rights reserved.
        Author: Ali Ozer

	You may freely copy, distribute and reuse the code in this example.
	NeXT disclaims any warranty of any kind, expressed or implied,
	as to its fitness for any particular use.

        View which holds all the pages together in the multiple-page case
*/

#import <AppKit/AppKit.h>
#import "MultiplePageView.h"

@implementation MultiplePageView

- (id)initWithFrame:(NSRect)rect {
    if ((self = [super initWithFrame:rect])) {
        numPages = 0;
        [self setLineColor:[NSColor lightGrayColor]];
        [self setMarginColor:[NSColor whiteColor]];
	/* This will set the frame to be whatever's appropriate... */
        [self setPrintInfo:[NSPrintInfo sharedPrintInfo]];
    }
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)isOpaque {
    return YES;
}

- (void)updateFrame {
    if ([self superview]) {
        NSRect rect = NSZeroRect;
        rect.size = [printInfo paperSize];
        rect.size.height = rect.size.height * numPages;
        if (numPages > 1) rect.size.height += [self pageSeparatorHeight] * (numPages - 1);
        rect.size = [self convertSize:rect.size toView:[self superview]];
        [self setFrame:rect];
    }
}

- (void)setPrintInfo:(NSPrintInfo *)anObject {
    if (printInfo != anObject) {
        [printInfo autorelease];
        printInfo = [anObject copy];
        [self updateFrame];
        [self setNeedsDisplay:YES];	/* Because the page size might change (could optimize this) */
    }
}

- (NSPrintInfo *)printInfo {
    return printInfo;
}

- (void)setNumberOfPages:(unsigned)num {
    if (numPages != num) {
	NSRect oldFrame = [self frame];
        NSRect newFrame;
        numPages = num;
        [self updateFrame];
	newFrame = [self frame];
        if (newFrame.size.height > oldFrame.size.height) {
	    [self setNeedsDisplayInRect:NSMakeRect(oldFrame.origin.x, NSMaxY(oldFrame), oldFrame.size.width, NSMaxY(newFrame) - NSMaxY(oldFrame))];
        }
    }
}

- (unsigned)numberOfPages {
    return numPages;
}
    
- (float)pageSeparatorHeight {
    return 5.0;
}

- (void)dealloc {
    [printInfo release];
    [super dealloc];
}

- (NSSize)documentSizeInPage {
    NSSize paperSize = [printInfo paperSize];
    paperSize.width -= ([printInfo leftMargin] + [printInfo rightMargin]);
    paperSize.height -= ([printInfo topMargin] + [printInfo bottomMargin]);
    return paperSize;
}

- (NSRect)documentRectForPageNumber:(unsigned)pageNumber {	/* First page is page 0, of course! */
    NSRect rect = [self pageRectForPageNumber:pageNumber];
    rect.origin.x += [printInfo leftMargin];
    rect.origin.y += [printInfo topMargin];
    rect.size = [self documentSizeInPage];
    return rect;
}

- (NSRect)pageRectForPageNumber:(unsigned)pageNumber {
    NSRect rect;
    rect.size = [printInfo paperSize];
    rect.origin = [self frame].origin;
    rect.origin.y += ((rect.size.height + [self pageSeparatorHeight]) * pageNumber);
    return rect;
}

- (void)setLineColor:(NSColor *)color {
    if (color != lineColor) {
        [lineColor autorelease];
        lineColor = [color copy];
        [self setNeedsDisplay:YES];
    }
}

- (NSColor *)lineColor {
    return lineColor;
}

- (void)setMarginColor:(NSColor *)color {
    if (color != marginColor) {
        [marginColor autorelease];
        marginColor = [color copy];
        [self setNeedsDisplay:YES];
    }
}

- (NSColor *)marginColor {
    return marginColor;
}

- (void)drawRect:(NSRect)rect {
    if ([[NSGraphicsContext currentContext] isDrawingToScreen]) {
        NSSize paperSize = [printInfo paperSize];
        unsigned firstPage = rect.origin.y / (paperSize.height + [self pageSeparatorHeight]);
        unsigned lastPage = NSMaxY(rect) / (paperSize.height + [self pageSeparatorHeight]);
        unsigned cnt;
        
        [marginColor set];
        NSRectFill(rect);

        [lineColor set];
        for (cnt = firstPage; cnt <= lastPage; cnt++) {
            NSRect docRect = NSInsetRect([self documentRectForPageNumber:cnt], -1.0, -1.0);
            NSFrameRectWithWidth(docRect, 0.0);
        }

        if ([[self superview] isKindOfClass:[NSClipView class]]) {
	    NSColor *backgroundColor = [(NSClipView *)[self superview] backgroundColor];
            [backgroundColor set];
            for (cnt = firstPage; cnt <= lastPage; cnt++) {
                NSRect pageRect = [self pageRectForPageNumber:cnt];
                NSRectFill (NSMakeRect(pageRect.origin.x, NSMaxY(pageRect), pageRect.size.width, [self pageSeparatorHeight]));
            }
        }
    }
}

/**** Printing support... ****/

- (BOOL)knowsPagesFirst:(int *)firstPageNum last:(int *)lastPageNum {
    *lastPageNum = [self numberOfPages];
    return YES;     
}

- (NSRect)rectForPage:(int)page {
    return [self documentRectForPageNumber:page-1];  /* Our page numbers start from 0; the kit's from 1 */
}

@end

/*

 2/16/95 aozer	Created for Edit II.
 4/20/95 aozer	Implemented printing

*/
