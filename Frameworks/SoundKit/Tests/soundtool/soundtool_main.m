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
  [stream release];
  fprintf(stderr, "\tRetain Count: %lu\n", [server retainCount]);
  [server release];
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
    [self playSystemBeep];
  }
}

// -----------------------------------------------------------------------------
// --- Play
// -----------------------------------------------------------------------------

static SNDFILE        *snd_file;
static pa_sample_spec sample_spec;

int pa_sndfile_read_sample_spec(SNDFILE *sf, pa_sample_spec *ss)
{
  SF_INFO sfi;
  int sf_errno;

  // NSAssert(NULL, sf);
  // NSAssert(NULL, ss);

  // pa_zero(sfi);
  if ((sf_errno = sf_command(sf, SFC_GET_CURRENT_SF_INFO, &sfi, sizeof(sfi)))) {
    fprintf(stderr, "sndfile: %s", sf_error_number(sf_errno));
    return -1;
  }

  switch (sfi.format & SF_FORMAT_SUBMASK) {

  case SF_FORMAT_PCM_16:
  case SF_FORMAT_PCM_U8:
  case SF_FORMAT_PCM_S8:
    ss->format = PA_SAMPLE_S16NE;
    break;

  case SF_FORMAT_PCM_24:
    ss->format = PA_SAMPLE_S24NE;
    break;

  case SF_FORMAT_PCM_32:
    ss->format = PA_SAMPLE_S32NE;
    break;

  case SF_FORMAT_ULAW:
    ss->format = PA_SAMPLE_ULAW;
    break;

  case SF_FORMAT_ALAW:
    ss->format = PA_SAMPLE_ALAW;
    break;

  case SF_FORMAT_FLOAT:
  case SF_FORMAT_DOUBLE:
  default:
    ss->format = PA_SAMPLE_FLOAT32NE;
    break;
  }

  ss->rate = (uint32_t) sfi.samplerate;
  ss->channels = (uint8_t) sfi.channels;

  if (!pa_sample_spec_valid(ss))
    return -1;

  return 0;
}
#define PA_ELEMENTSOF(x) (sizeof(x)/sizeof((x)[0]))
int pa_sndfile_read_channel_map(SNDFILE *sf, pa_channel_map *cm)
{

  static const pa_channel_position_t table[] = {
    [SF_CHANNEL_MAP_MONO] =                  PA_CHANNEL_POSITION_MONO,
    [SF_CHANNEL_MAP_LEFT] =                  PA_CHANNEL_POSITION_FRONT_LEFT, /* libsndfile distinguishes left and front-left, which we don't */
    [SF_CHANNEL_MAP_RIGHT] =                 PA_CHANNEL_POSITION_FRONT_RIGHT,
    [SF_CHANNEL_MAP_CENTER] =                PA_CHANNEL_POSITION_FRONT_CENTER,
    [SF_CHANNEL_MAP_FRONT_LEFT] =            PA_CHANNEL_POSITION_FRONT_LEFT,
    [SF_CHANNEL_MAP_FRONT_RIGHT] =           PA_CHANNEL_POSITION_FRONT_RIGHT,
    [SF_CHANNEL_MAP_FRONT_CENTER] =          PA_CHANNEL_POSITION_FRONT_CENTER,
    [SF_CHANNEL_MAP_REAR_CENTER] =           PA_CHANNEL_POSITION_REAR_CENTER,
    [SF_CHANNEL_MAP_REAR_LEFT] =             PA_CHANNEL_POSITION_REAR_LEFT,
    [SF_CHANNEL_MAP_REAR_RIGHT] =            PA_CHANNEL_POSITION_REAR_RIGHT,
    [SF_CHANNEL_MAP_LFE] =                   PA_CHANNEL_POSITION_LFE,
    [SF_CHANNEL_MAP_FRONT_LEFT_OF_CENTER] =  PA_CHANNEL_POSITION_FRONT_LEFT_OF_CENTER,
    [SF_CHANNEL_MAP_FRONT_RIGHT_OF_CENTER] = PA_CHANNEL_POSITION_FRONT_RIGHT_OF_CENTER,
    [SF_CHANNEL_MAP_SIDE_LEFT] =             PA_CHANNEL_POSITION_SIDE_LEFT,
    [SF_CHANNEL_MAP_SIDE_RIGHT] =            PA_CHANNEL_POSITION_SIDE_RIGHT,
    [SF_CHANNEL_MAP_TOP_CENTER] =            PA_CHANNEL_POSITION_TOP_CENTER,
    [SF_CHANNEL_MAP_TOP_FRONT_LEFT] =        PA_CHANNEL_POSITION_TOP_FRONT_LEFT,
    [SF_CHANNEL_MAP_TOP_FRONT_RIGHT] =       PA_CHANNEL_POSITION_TOP_FRONT_RIGHT,
    [SF_CHANNEL_MAP_TOP_FRONT_CENTER] =      PA_CHANNEL_POSITION_TOP_FRONT_CENTER,
    [SF_CHANNEL_MAP_TOP_REAR_LEFT] =         PA_CHANNEL_POSITION_TOP_REAR_LEFT,
    [SF_CHANNEL_MAP_TOP_REAR_RIGHT] =        PA_CHANNEL_POSITION_TOP_REAR_RIGHT,
    [SF_CHANNEL_MAP_TOP_REAR_CENTER] =       PA_CHANNEL_POSITION_TOP_REAR_CENTER
  };

  SF_INFO sfi;
  int sf_errno;
  int *channels;
  unsigned c;

  // pa_assert(sf);
  // pa_assert(cm);

  // pa_zero(sfi);
  if ((sf_errno = sf_command(sf, SFC_GET_CURRENT_SF_INFO, &sfi, sizeof(sfi)))) {
    fprintf(stderr, "sndfile: %s", sf_error_number(sf_errno));
    return -1;
  }

  channels = pa_xnew(int, sfi.channels);
  if (!sf_command(sf, SFC_GET_CHANNEL_MAP_INFO, channels, sizeof(channels[0]) * sfi.channels)) {
    pa_xfree(channels);
    return -1;
  }

  cm->channels = (uint8_t) sfi.channels;
  for (c = 0; c < cm->channels; c++) {
    if (channels[c] <= SF_CHANNEL_MAP_INVALID ||
        (unsigned) channels[c] >= PA_ELEMENTSOF(table)) {
      pa_xfree(channels);
      return -1;
    }

    cm->map[c] = table[channels[c]];
  }

  pa_xfree(channels);

  if (!pa_channel_map_valid(cm))
    return -1;

  return 0;
}

- (void)playBytes:(NSNumber *)count
{
  size_t     length = [count unsignedIntValue];
  sf_count_t bytes_to_read, bytes_read;
  float      *buffer;

  // NSLog(@"Play bytes count: %li", length);
  buffer = pa_xmalloc(length);

  // pa_assert(sample_length >= length);
  bytes_to_read = (sf_count_t) (length/pa_frame_size(&sample_spec));
  bytes_read = sf_readf_float(snd_file, buffer, bytes_to_read);
  // fprintf(stderr, "Stream ready to receive: %li | Bytes to read: %li | Bytes were read: %li\n",
  //         length, bytes_to_read, bytes_read);
  
  if (bytes_read <= 0) {
    pa_xfree(buffer);
    [stream deactivate];
    return;
  }

  [stream playBuffer:buffer size:length tag:0];
}

- (void)playSystemBeep
{
  struct SF_INFO sfi;
  // char *file = "/usr/NextSpace/Sounds/Welcome-to-the-NeXT-world.snd";
  // char *file = "/usr/NextSpace/Sounds/SystemBeep.snd";
  char    *file = "/usr/NextSpace/Sounds/Rooster.snd";
  // char *file = "/usr/share/sounds/alsa/Noise.wav";
  // char *file = "/usr/share/sounds/freedesktop/stereo/audio-channel-side-left.oga";
  // char *file = "/usr/share/sounds/KDE-Im-Irc-Event.ogg";

  if (!(snd_file = sf_open(file, SFM_READ, &sfi))) {
    fprintf(stderr, "Failed to open sound file.\n");
    return;
  }

  if (pa_sndfile_read_sample_spec(snd_file, &sample_spec) < 0) {
    fprintf(stderr, "Failed to determine sample specification from file.\n");
    return;
  }
  fprintf(stderr, "channels: %i rate: %i format: %i\n",
          sample_spec.channels, sample_spec.rate, sample_spec.format);
  sample_spec.format = PA_SAMPLE_FLOAT32LE;
  
  // NSLog(@"Creating stream...");
  stream = [[SNDPlayStream alloc] initOnDevice:[server defaultOutput]
                                  samplingRate:sample_spec.rate
                                  channelCount:sample_spec.channels
                                        format:sample_spec.format];
  [stream setDelegate:self];
  [stream setAction:@selector(playBytes:)];
  
  // NSLog(@"Activate stream...");
  [stream activate];
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
  NSConnection      *conn;

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
