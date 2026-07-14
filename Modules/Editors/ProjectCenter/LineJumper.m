#import "LineJumper.h"

static id sharedLineJumper = nil;

@implementation LineJumper

+ (id)sharedInstance
{
  if (!sharedLineJumper) 
    {
      sharedLineJumper = [[self allocWithZone:[[NSApplication sharedApplication] zone]] init];
    }
  return sharedLineJumper;
}

- (id) init
{
  if (!(self = [super init])) return nil;
  //  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidActivate:) name:NSApplicationDidBecomeActiveNotification object:[NSApplication sharedApplication]];
  // [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addWillDeactivate:) name:NSApplicationWillResignActiveNotification object:[NSApplication sharedApplication]];
  return self;
}

- (void)loadUI
{
  if (!lineField)
    {
      if (![NSBundle loadNibNamed:@"LineJumper" owner:self])
        {
          NSLog(@"Failed to load LineJumper.nib");
          NSBeep();
        }
      if (self == sharedLineJumper)
        [[lineField window] setFrameAutosaveName:@"GoTo Line"];
    }
}

- (NSTextView<CodeEditorView> *)editorViewToUse
{
  id tv = [[NSApp mainWindow] firstResponder];
  if([tv conformsToProtocol:@protocol(CodeEditorView)])
    return tv;
  return nil;
}

- (NSPanel *)linePanel
{
    if (!lineField)
      [self loadUI];
    return (NSPanel *)[lineField window];
}

- (void)orderFrontLinePanel:(id)sender
{
  NSPanel *panel = [self linePanel];
  [lineField selectText:nil];
  [panel makeKeyAndOrderFront:nil];
}

- (IBAction)goToLine:(id)sender
{
  NSUInteger line;
  NSTextView<CodeEditorView> *cev;

  line = (NSUInteger)[lineField integerValue];
  cev = [self editorViewToUse];
  if (cev)
    {
      [cev goToLineNumber:line];
    }
}

@end
