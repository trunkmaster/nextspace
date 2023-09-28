/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Description:  A FileMover.tool wrapper and UI.
//
// Copyright (C) 2018 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import <Foundation/Foundation.h>

#import "Processes/BGProcess.h"
#import <Operations/FileMover.h>

@interface FileMoverUI : BGProcess
{
  // BGProcess
  // IBOutlet NSWindow    *window;
  // IBOutlet NSBox       *processBox;
  // IBOutlet NSTextField *currentField;
  // IBOutlet NSButton    *stopButton;
  //
  // IBOutlet NSBox       *alertBox;

  OperationState operationState;

  // Addons
  id fromField;
  id fromLabel;
  id toField;
  id toLabel;
  id progressBar;  // NXProgressPie
  id pauseButton;
}

- (void)pause:(id)sender;

@end

@interface NSObject (FileMoverDelegate)

- (void)fileOperation:(FileMover *)fop
       processingFile:(NSString *)filename
         sourcePrefix:(NSString *)sourcePrefix
         targetPrefix:(NSString *)targetPrefix;

- (void)fileOperation:(FileMover *)anOperation processedToPercentDone:(float)percentDone;

- (void)fileOperation:(FileMover *)anOperation didChangeStateTo:(OperationState)aState;

- (void)fileOperation:(FileMover *)anOperation
      encounteredProblem:(OperationProblem)problem
             description:(NSString *)problemDescription
    solutionDescriptions:(NSArray *)solutions;

@end
