/* All Rights reserved */

#include "TitleBarPrefs.h"
#import "../TerminalWindow.h"

@implementation TitleBarPrefs

+ (NSString *)name
{
  return @"Title Bar";
}

- init
{
  self = [super init];

  [NSBundle loadNibNamed:@"TitleBar" owner:self];

  return self;
}

- (void)awakeFromNib
{
  [view retain];
}

- (NSView *)view
{
  return view;
}


- (NSUInteger)_elementsMaskFromButtons
{
  NSUInteger mask = 0;
  
  if ([shellPathBth state] == NSOnState)
    mask |= TitleBarShellPath;
  if ([deviceNameBtn state] == NSOnState)
    mask |= TitleBarDeviceName;
  if ([filenameBtn state] == NSOnState)
    mask |= TitleBarFileName;
  if ([windowSizeBtn state] == NSOnState)
    mask |= TitleBarWindowSize;
  if ([customTitleBtn state] == NSOnState)
    mask |= TitleBarCustomTitle;

  return mask;
}

// Title bar display format:
// CutomTitle -- ShellPath (DeviceName) WindowSize -- FileName
- (void)_updateDemoTitleBar
{
  NSUInteger elementsMask = [self _elementsMaskFromButtons];
  NSString   *title;
  TerminalWindowController *twc = [[NSApp mainWindow] windowController];

  title = [NSString new];
  
  if (elementsMask & TitleBarShellPath)
    title = [title stringByAppendingFormat:@"%@ ", [twc shellPath]];
  
  if (elementsMask & TitleBarDeviceName)
    title = [title stringByAppendingFormat:@"(%@) ", [twc deviceName]];
  
  if (elementsMask & TitleBarWindowSize)
    title = [title stringByAppendingFormat:@"%@ ", [twc windowSize]];
  
  if (elementsMask & TitleBarCustomTitle)
    {
      if ([title length] == 0)
        {
          title = [NSString stringWithFormat:@"%@ ",
                            [customTitleField stringValue]];
        }
      else
        {
          title = [NSString stringWithFormat:@"%@ \u2014 %@",
                            [customTitleField stringValue], title];
        }
    }

  if (elementsMask & TitleBarFileName)
    {
      if ([title length] == 0)
        {
          title = [NSString stringWithFormat:@"%@", [twc fileName]];
        }
      else
        {
          title = [title stringByAppendingFormat:@"\u2014 %@", [twc fileName]];
        }
    }
  
  [demoTitleBarField setStringValue:title];
}


- (void)setElements:(id)sender
{
  if ([customTitleBtn state] == NSOnState)
    {
      [customTitleField setEditable:YES];
      [customTitleField setTextColor:[NSColor blackColor]];
      [[view window] makeFirstResponder:customTitleField];
    }
  else
    {
      [customTitleField setEditable:NO];
      [customTitleField setTextColor:[NSColor darkGrayColor]];
      [[view window] makeFirstResponder:window];
    }

  [self _updateDemoTitleBar];
}

- (void)setDefault:(id)sender
{
  NSUInteger titleBarMask = [self _elementsMaskFromButtons];
  
  [ud setInteger:titleBarMask forKey:TitleBarElementsMaskKey];
  if (titleBarMask & TitleBarCustomTitle)
    {
      [ud setObject:[customTitleField stringValue]
             forKey:TitleBarCustomTitleKey];
    }

  [ud synchronize];
  [Defaults readTitleBarDefaults];
}
- (void)showDefault:(id)sender
{
  NSUInteger titleBarMask = [Defaults titleBarElementsMask];
  NSString   *customTitle = [Defaults customTitle];

  [shellPathBth setState:(titleBarMask & TitleBarShellPath) ? 1 : 0];
  [deviceNameBtn setState:(titleBarMask & TitleBarDeviceName) ? 1 : 0];
  [filenameBtn setState:(titleBarMask & TitleBarFileName) ? 1 : 0];
  [windowSizeBtn setState:(titleBarMask & TitleBarWindowSize) ? 1 : 0];
  [customTitleBtn setState:(titleBarMask & TitleBarCustomTitle) ? 1 : 0];

  if (!customTitle)
    [customTitleField setStringValue:@"Terminal"];
  else
    [customTitleField setStringValue:customTitle];
  
  [self setElements:self];
  [self _updateDemoTitleBar];
}
- (void)setWindow:(id)sender
{
  NSMutableDictionary *prefs;
  NSUInteger          titleBarMask;

  if (![sender isKindOfClass:[NSButton class]]) return;
  
  prefs = [NSMutableDictionary new];

  titleBarMask = [self _elementsMaskFromButtons];
  [prefs setObject:[NSNumber numberWithInt:titleBarMask]
            forKey:TitleBarElementsMaskKey];
  if (titleBarMask & TitleBarCustomTitle)
    {
      [prefs setObject:[customTitleField stringValue]
                forKey:TitleBarCustomTitleKey];
    }

  [[NSNotificationCenter defaultCenter]
    postNotificationName:TerminalPreferencesDidChangeNotification
                  object:[NSApp mainWindow]
                userInfo:prefs];
}


// TextField delegate
- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  [self _updateDemoTitleBar];
}

@end
