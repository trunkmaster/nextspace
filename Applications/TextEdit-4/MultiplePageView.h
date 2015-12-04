#import <AppKit/NSView.h>
@class NSPrintInfo;
@class NSColor;

@interface MultiplePageView : NSView {
    NSPrintInfo *printInfo;
    NSColor *lineColor;
    NSColor *marginColor;
    unsigned numPages;
}

- (void)setPrintInfo:(NSPrintInfo *)anObject;
- (NSPrintInfo *)printInfo;
- (float)pageSeparatorHeight;
- (NSSize)documentSizeInPage;	/* Returns the area where the document can draw */
- (NSRect)documentRectForPageNumber:(unsigned)pageNumber;	/* First page is page 0 */
- (NSRect)pageRectForPageNumber:(unsigned)pageNumber;	/* First page is page 0 */
- (void)setNumberOfPages:(unsigned)num;
- (unsigned)numberOfPages;
- (void)setLineColor:(NSColor *)color;
- (NSColor *)lineColor;
- (void)setMarginColor:(NSColor *)color;
- (NSColor *)marginColor;

@end
