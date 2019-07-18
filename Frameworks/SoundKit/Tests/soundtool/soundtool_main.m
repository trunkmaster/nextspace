//
//
//

#include <stdio.h>
#include <unistd.h>
#include <sndfile.h>

#import <Foundation/Foundation.h>
#import <SoundKit/SNDServer.h>
#import <SoundKit/SNDOut.h>
#import <SoundKit/SNDPlayStream.h>

@interface SoundKitClient : NSObject
{
  SNDServer     *server;
  SNDPlayStream *stream;
  
  BOOL          isRunning;
}
@end

@implementation SoundKitClient

- (void)dealloc
 {
  NSLog(@"SoundKitClient: dealloc");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  if (stream != nil) {
    [stream deactivate];
    [stream release];
  }
  
  fprintf(stderr, "\tRetain Count: %lu\n", [server retainCount]);
  [server disconnect];
  // [server release];
  
  [super dealloc];
}

- init
{
  self = [super init];

  // 1. Connect to PulseAudio on locahost
  server = [SNDServer sharedServer];
  // 2. Wait for server to be ready
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(serverStateChanged:)
           name:SNDServerStateDidChangeNotification
         object:server];
  [server connect];

  // [self serverStateChanged:nil];
  
  return self;
}

// -----------------------------------------------------------------------------
// --- Run loop
// -----------------------------------------------------------------------------
- (void)runLoopRun
{
  NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
  
  isRunning = YES;
  while (isRunning) {
    // NSLog(@"RunLoop is running");
    [runLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  }
}

- (void)runLoopStop
{
  isRunning = NO;
}

- (void)serverStateChanged:(NSNotification *)notif
{
  if (server.status == SNDServerReadyState) {
    // {
    //   fprintf(stderr, "========= Sound Server =========\n");
    //   fprintf(stderr, "\t        Name: %s\n", [server.name cString]);
    //   fprintf(stderr, "\t     Version: %s\n", [server.version cString]);
    //   fprintf(stderr, "\t    Username: %s\n", [server.userName cString]);
    //   fprintf(stderr, "\t    Hostname: %s\n", [server.hostName cString]);
    //   fprintf(stderr, "\tRetain Count: %lu\n", [server retainCount]);
    // }
    // {
    //   fprintf(stderr, "========= Default SoundOut =========\n");
    //   [[server defaultOutput] printDescription];
    // }
    if ([self playSystemBeep] != 0) {
      [self runLoopStop];
    }
  }
  else if (server.status == SNDServerFailedState ||
           server.status == SNDServerTerminatedState) {
    [self runLoopStop];
  }
}

// -----------------------------------------------------------------------------
// --- Play
// -----------------------------------------------------------------------------

static SNDFILE        *snd_file;
static struct SF_INFO sfi;
static pa_sample_spec sample_spec;
static char           *file = NULL;

- (void)soundStream:(SNDPlayStream *)sndStream bufferReady:(NSNumber *)count
{
  size_t     bytes_length = [count unsignedIntValue]; // length of stream in bytes
  sf_count_t frames_length;                           // length of stream in frames 
  sf_count_t frames_read;
  float      *buffer;

  buffer = pa_xmalloc(bytes_length);

  frames_length = (sf_count_t) (bytes_length/pa_frame_size(&sample_spec));
  frames_read = sf_readf_float(snd_file, buffer, (frames_length > sfi.frames) ? sfi.frames : frames_length);
  fprintf(stderr, "Stream size: %li bytes(B), %li frames(F) | F count: %li | F size: %i | F read: %li\n",
          bytes_length, frames_length, sfi.frames, (int)pa_frame_size(&sample_spec), frames_read);
  
  if (frames_read <= 0) {
    pa_xfree(buffer);
    [stream empty:NO];
    return;
  }

  [stream playBuffer:buffer size:bytes_length tag:0];
}
- (void)soundStreamBufferEmpty:(SNDPlayStream *)sndStream
{
  if (isRunning != NO) {
    NSLog(@"Play finished and buffer is empty. Can stop run loop now.");
    [self runLoopStop];
  }
}

- (int)playSystemBeep
{
  // struct SF_INFO sfi;
  // char *file = "/usr/NextSpace/Sounds/Welcome-to-the-NeXT-world.snd";
  // char *file = "/usr/NextSpace/Sounds/SystemBeep.snd";
  // char *file = "/usr/NextSpace/Sounds/Rooster.snd";
  // char *file = "/usr/share/sounds/alsa/Noise.wav";
  // char *file = "/usr/share/sounds/freedesktop/stereo/audio-channel-side-left.oga";
  // char *file = "/usr/share/sounds/KDE-Im-Irc-Event.ogg";

  if (file == NULL) {
    file = "/usr/NextSpace/Sounds/Rooster.snd";
  }

  if (!(snd_file = sf_open(file, SFM_READ, &sfi))) {
    fprintf(stderr, "Failed to open sound file: unsupported format.\n");
    return 1;
  }

  // Read sample specs
  sample_spec.rate = (uint32_t)sfi.samplerate;
  sample_spec.channels = (uint8_t)sfi.channels;
  // We'll read bytes with `sf_readf_float()` in `-playBytes:`
  sample_spec.format = PA_SAMPLE_FLOAT32LE;
  if (!pa_sample_spec_valid(&sample_spec)) {
    fprintf(stderr, "Failed to determine sample specification from file.\n");
    return 1;
  }
  fprintf(stderr, "channels: %i rate: %i format: %i\n",
          sample_spec.channels, sample_spec.rate,  sample_spec.format);
  
  NSLog(@"Creating stream...");
  stream = [[SNDPlayStream alloc] initOnDevice:[server defaultOutput]
                                  samplingRate:sample_spec.rate
                                  channelCount:sample_spec.channels
                                        format:sample_spec.format
                                          type:SNDEventType];
  [stream setDelegate:self];
  
  NSLog(@"Activate stream...");
  [stream activate];

  return 0;
}

@end

static SoundKitClient *client;

static void handle_signal(int sig)
{
  // fprintf(stderr, "got signal %i\n", sig);
  [client runLoopStop];
}

int main(int argc, char *argv[])
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  // NSConnection      *conn;

  if (argc < 2) {
    fprintf(stderr, "Specify file absolute path name to sound file, please.\n");
    return 1;
  }

  file = argv[1];

  client = [SoundKitClient new];
  // conn = [NSConnection defaultConnection];
  // [conn registerName:@"soundtool"];

  signal(SIGHUP, handle_signal);
  signal(SIGINT, handle_signal);
  signal(SIGQUIT, handle_signal);
  signal(SIGTERM, handle_signal);

  [client runLoopRun];

  fprintf(stderr, "Runloop exited.\n");

  // [conn invalidate];
  [client release];
  [pool release];

  return 0;
}
