// BGOperation - concrete class methods implementation.

#import "Operations/BGOperation.h"

@implementation BGOperation : NSObject

- (id)initWithOperationType:(OperationType)opType
                  sourceDir:(NSString *)sourceDir
                  targetDir:(NSString *)targetDir
                      files:(NSArray *)fileList
                    manager:(ProcessManager *)delegate
{
  [super init];
  
  // Initial arguments
  type = opType;
  
  ASSIGN(source, (sourceDir != nil) ? sourceDir : @"");
  ASSIGN(target, (targetDir != nil) ? targetDir : @"");
  ASSIGN(files, fileList);

  ASSIGN(currSourceDir, (sourceDir != nil) ? sourceDir : @"");
  ASSIGN(currTargetDir, (targetDir != nil) ? targetDir : @"");
  ASSIGN(currFile, (fileList != nil) ? [fileList objectAtIndex:0] : @"");

  manager = delegate;
  
  processUI = nil;
  alertUI = nil;
  message = nil;

  [[NSNotificationCenter defaultCenter]
    postNotificationName:WMOperationDidCreateNotification
                  object:self];

  [self setState:OperationPrepare];

  return self;
}

- (void)dealloc
{
  TEST_RELEASE(source);
  TEST_RELEASE(target);
  TEST_RELEASE(files);
  
  TEST_RELEASE(currSourceDir);
  TEST_RELEASE(currTargetDir);
  TEST_RELEASE(currFile);

  TEST_RELEASE(processUI);
  
  [super dealloc];
}

// Bottom part of 'Processes' panel in 'Background' section
- (BGProcess *)userInterface
{
  if (processUI == nil)
    {
      processUI = [[BGProcess alloc] initWithOperation:self];
    }
  
 return processUI;
}

- (void)updateProcessView:(BOOL)create
{
  if (state == OperationStopping || state == OperationStopped)
    return;
  
  // Process UI will be created if not exists
  if (create)
    {
      [self userInterface];
    }
  
  if (processUI)
    {
      [processUI updateWithMessage:message
                              file:currFile
                            source:currSourceDir
                            target:currTargetDir
                          progress:[self progressValue]];
    }
}

- (OperationType)type
{
  return type;
}

- (NSString *)typeString
{
  switch (type)
    {
    case CopyOperation:
      return @"Copy";
      break;
    case DuplicateOperation:
      return @"Duplicate";
      break;
    case MoveOperation:
      return @"Move";
      break;
    case LinkOperation:
      return @"Link";
      break;
    case DeleteOperation:
      return @"Delete";
      break;
    case RecycleOperation:
      return @"Recycle";
      break;
    case MountOperation:
      return @"Mount";
      break;
    case UnmountOperation:
      return @"Unmount";
      break;
    case EjectOperation:
      return @"Eject";
      break;
    case SizeOperation:
      return @"Size";
      break;
    case PermissionOperation:
      return @"Permission";
    }

  return @"";
}

// Operation state. There's no '-start' method '-initWithOperationType:::::'
// starts background operation.
- (void)setState:(OperationState)opState
{
  state = opState;

  if (state == OperationAlert)
    {
      [[self userInterface] updateAlertWithMessage:problemDesc
                                              help:problemSolutionDesc
                                         solutions:solutions];
    }
  
  [[NSNotificationCenter defaultCenter]
        postNotificationName:WMOperationDidChangeStateNotification
                      object:self];
}
- (OperationState)state
{
  return state;
}
- (NSString *)stateString
{
  switch (state)
    {
    case OperationPrepare:
      return @"Preparing";
    case OperationRunning:
      return @"";
    case OperationPaused:
      return @"Paused";
    case OperationAlert:
      return @"Alert";
    case OperationCompleted:
      return @"Completed";
    case OperationStopping:
      return @"Stopping";
    case OperationStopped:
      return @"Stopped";
    }

  return @"";
}

- (void)stop:(id)sender
{
  // Subclass responsibility
  [self setState:OperationStopped];
}
- (BOOL)canBeStopped
{
  return YES;
}

// Operated objects info
- (NSString *)source
{
  return source;
}
- (NSString *)target
{
  return target;
}
- (NSArray *)files
{
  return files;
}
  
// Must be overriden in subclass to describe operation specifics
- (NSString *)titleString
{
  NSString   *title;
  NSString   *path = source;
  NSUInteger filesCount = [files count];
  
  if (filesCount == 1)
    {
      path = [source stringByAppendingPathComponent:[files objectAtIndex:0]];
    }
  else if (filesCount > 1)
    {
      path = [NSString stringWithFormat:@"%@/(%lu items)", source, filesCount];
    }
  
  return [NSString stringWithFormat:@"%@ %@", [self typeString], path];
}

- (NSString *)currentSourceDirectory
{
  return currSourceDir;
}
- (NSString *)currentTargetDirectory
{
  return currTargetDir;
}
- (NSString *)currentFile
{
  return currFile;
}
- (NSString *)currentMessage
{
  return message;
}

- (BOOL)isProgressSupported
{
  return NO;
}

- (float)progressValue
{
  return 0.0;
}

@end
