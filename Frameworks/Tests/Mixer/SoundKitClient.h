/* -*- mode:objc -*- */

#import <Foundation/Foundation.h>
#import <SoundKit/NXSoundServer.h>
#import <SoundKit/NXSoundOut.h>

@interface SoundKitClient : NSObject
{
  NXSoundServer *server;
  BOOL isRunning;
}

- (void)runLoopRun;

@end
