// BGOperation - background operation concrete class.
// Background operation doesn't have GUI.
// Usually BGOperation ancestor calls BGOperation.tool and communicate with it
// notifying about progress, state changes and problems.

#import <Foundation/Foundation.h>

#import "Operations/ProcessManager.h"
#import "Processes/BGProcess.h"

typedef enum {
  NoProblem,
  ReadError,
  WriteError,
  DeleteError,
  MoveError,
  SymlinkEncountered,
  SymlinkTargetNotExist,
  AttributesUnchangeable,
  FileExists,
  UnknownFile
} OperationProblem;

@interface BGOperation : NSObject
{
  // Background operations manager.
  ProcessManager *manager;
  // BGProcess subclass which displays UI in ProcessPanel.
  // 'process != nil' if '-userInterface' method was called.
  BGProcess *processUI;
  BGProcess *alertUI;

  // Inital ivars
  OperationState state;
  OperationType  type;
  NSString       *source;
  NSString       *target;
  NSArray        *files;

  // Current state ivars (used to show progress and update of FileViewer)
  NSString *message;
  NSString *currSourceDir;
  NSString *currTargetDir;
  NSString *currFile;

  // Alert
  OperationProblem problem;
  NSString         *problemDesc;
  NSString         *problemSolutionDesc;
  NSArray          *solutions;
}

- (id)initWithOperationType:(OperationType)opType
                  sourceDir:(NSString *)sourceDir
                  targetDir:(NSString *)targetDir
                      files:(NSArray *)fileList
                    manager:(ProcessManager *)delegate;

// Bottom part of 'Processes' panel in 'Background' section
- (BGProcess *)userInterface;
- (void)updateProcessView:(BOOL)create;

- (OperationType)type;
- (NSString *)typeString;

// Operation state. There's no '-start' method '-initWithOperationType:::::'
// starts background operation.
- (void)setState:(OperationState)opState;
- (OperationState)state;
- (NSString *)stateString;

- (void)stop:(id)sender;
- (BOOL)canBeStopped;     // If NO 'Stop' button will be disabled.

// Operated objects info
- (NSString *)source;
- (NSString *)target;
- (NSArray *)files;

- (NSString *)titleString;
- (NSString *)currentSourceDirectory; // From:
- (NSString *)currentTargetDirectory; // To:
- (NSString *)currentMessage;         // Copying file <currentFile>... 
- (NSString *)currentFile;            // <currentFile>

- (BOOL)isProgressSupported;
- (float)progressValue;

@end
