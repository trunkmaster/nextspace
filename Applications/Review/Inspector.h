/* 
 * Inspector.h created by probert on 2001-11-15 20:24:21 +0000
 *
 * Project ImageViewer
 *
 * Created with ProjectCenter - http://www.projectcenter.ch
 *
 * $Id: Inspector.h,v 1.3 2001/11/18 13:51:10 probert Exp $
 */

#ifndef _INSPECTOR_H_
#define _INSPECTOR_H_

#import <AppKit/AppKit.h>
#import "ImageShowing.h"

@interface Inspector : NSObject
{
    NSWindow *inspector;
    NSTextField *nameField;
    NSTextField *pathField;
    NSTextField *sizeField;
    NSTextField *permissionsField;
    NSTextField *dateField;
    NSTextField *ownerField;
    NSTextField *resField;
    NSTextField *bitsField;
    NSTextField *colSpaceField;
    NSTextField *alphaField;
    NSTextField *repsField;

    NSButton *imgButton;
}

+ (Inspector *)sharedInspector;

- (void)show;

- (void)imageWindowDidBecomeActive:(id<ImageShowing>)imgWin;

@end

#endif // _INSPECTOR_H_

