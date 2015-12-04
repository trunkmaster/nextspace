/* 
 * PrefController.h created by probert on 2001-11-15 20:24:09 +0000
 *
 * Project ImageViewer
 *
 * Created with ProjectCenter - http://www.projectcenter.ch
 *
 * $Id: PrefController.h,v 1.3 2002/01/26 17:08:43 probert Exp $
 */

#ifndef _PREFCONTROLLER_H_
#define _PREFCONTROLLER_H_

#import <AppKit/AppKit.h>

@interface PrefController : NSObject
{
    NSWindow *preferences;
    NSMutableDictionary *prefDict;

    id cacheSizeField;
    id openRecursive;
}

-(id)init;

- (void)show;
- (void)setCacheSize:(id)sender;
- (void)setOpenRecursive:(id)sender;

- (void)buttonsPressed:(id)sender;

- (void)resetPreferences;
- (void)setPreferences;

@end

#endif // _PREFCONTROLLER_H_

