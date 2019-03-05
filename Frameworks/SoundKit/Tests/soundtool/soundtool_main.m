//
//
//

#include <stdio.h>
#include <unistd.h>
#include <sndfile.h>

#import <Foundation/Foundation.h>
#import <SoundKit/SKSoundServer.h>
#import <SoundKit/SKSoundOut.h>

@interface SoundKitClient : NSObject
{
  SKSoundServer *server;
  BOOL          isRunning;
}
@end

@implementation SoundKitClient (Play)

int pa_sndfile_read_sample_spec(SNDFILE *sf, pa_sample_spec *ss)
{
    SF_INFO sfi;
    int sf_errno;

    pa_assert(sf);
    pa_assert(ss);

    pa_zero(sfi);
    if ((sf_errno = sf_command(sf, SFC_GET_CURRENT_SF_INFO, &sfi, sizeof(sfi)))) {
        pa_log_error("sndfile: %s", sf_error_number(sf_errno));
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

    pa_assert(sf);
    pa_assert(cm);

    pa_zero(sfi);
    if ((sf_errno = sf_command(sf, SFC_GET_CURRENT_SF_INFO, &sfi, sizeof(sfi)))) {
        pa_log_error("sndfile: %s", sf_error_number(sf_errno));
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

- (void)playSystemBeep
{
  struct SF_INFO sfi;
  SNDFILE        *snd_file;
  pa_sample_spec sample_spec;
  pa_channel_map channel_map;
  pa_stream      *play_stream;

  if (!(snd_file = sf_open("/usr/NextSpace/Sounds/SystemBeep.snd", SFM_READ, &sfi))) {
    fprintf(stderr, "Failed to open sound file.\n");
    return;
  }

  if (pa_sndfile_read_sample_spec(snd_file, &sample_spec) < 0) {
    fprintf(stderr, "Failed to determine sample specification from file.\n");
    return;
  }
  // sample_spec.format = PA_SAMPLE_FLOAT32;

  if (pa_sndfile_read_channel_map(snd_file, &channel_map) < 0) {
    if (sample_spec.channels > 2) {
      fprintf(stderr, "Warning: Failed to determine sample specification from file.\n");
    }
    pa_channel_map_init_extend(&channel_map, sample_spec.channels, PA_CHANNEL_MAP_DEFAULT);
  }

  sample_length = (size_t)sfi.frames * pa_frame_size(&sample_spec);

  SKPlayStream *skStream;
  skStream = [[SKPlayStream alloc] initOnDevice:[server defaultOutput]
                                           rate:sample_spec.rate
                                       channels:sample_spec.channels
                                         format:sample_spec.format];

  // typedef struct pa_sample_spec {
  //   pa_sample_format_t format;   /* The sample format */
  //   uint32_t           rate;     /* The sample rate. (e.g. 44100) */
  //   uint8_t            channels; /* Audio channels. (1 for mono, 2 for stereo, ...) */
  // } pa_sample_spec;
  sample_spec.rate = 44100;
  sample_spec.channels = 2;
  sample_spec.format = ?;
  
  // typedef struct pa_channel_map {
  //   uint8_t               channels;             /* Number of channels */
  //   pa_channel_position_t map[PA_CHANNELS_MAX]; /* Channel labels */
  // } pa_channel_map;
  
  // pa_stream* pa_stream_new(
  //       pa_context *c                     /**< The context to create this stream in */,
  //       const char *name                  /**< A name for this stream */,
  //       const pa_sample_spec *ss          /**< The desired sample format */,
  //       const pa_channel_map *map         /**< The desired channel map, or NULL for default */);
  play_stream = pa_stream_new(pa_ctx, "soundtool", &sample_spec, NULL);
  
  // int pa_stream_connect_playback(
  //       pa_stream *s                  /**< The stream to connect to a sink */,
  //       const char *dev               /**< Name of the sink to connect to, or NULL for default */ ,
  //       const pa_buffer_attr *attr    /**< Buffering attributes, or NULL for default */,
  //       pa_stream_flags_t flags       /**< Additional flags, or 0 for default */,
  //       const pa_cvolume *volume      /**< Initial volume, or NULL for default */,
  //       pa_stream *sync_stream        /**< Synchronize this stream with the specified one, or NULL for a standalone stream */);
  pa_stream_connect_playback(play_stream, "alsa_output.pci-0000_00_1b.0.analog-stereo", NULL, 0, NULL, NULL);
}

@end

@implementation SoundKitClient

- (void)dealloc
{
  NSLog(@"SoundKitClient: dealloc");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  fprintf(stderr, "\tRetain Count: %lu\n", [server retainCount]);
  [server release];
  [super dealloc];
}

- init
{
  self = [super init];

  // 1. Connect to PulseAudio on locahost
  server = [SKSoundServer sharedServer];
  // 2. Wait for server to be ready
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(serverStateChanged:)
           name:SKServerStateDidChangeNotification
         object:server];
  
  return self;
}

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

- (void)describeSoundSystem
{
  // Server
  fprintf(stderr, "=== Sound Server ===\n");
  fprintf(stderr, "\t        Name: %s\n", [server.name cString]);
  fprintf(stderr, "\t     Version: %s\n", [server.version cString]);
  fprintf(stderr, "\t    Username: %s\n", [server.userName cString]);
  fprintf(stderr, "\t    Hostname: %s\n", [server.hostName cString]);
  fprintf(stderr, "\tRetain Count: %lu\n", [server retainCount]);
  
  // // Sound Out
  // fprintf(stderr, "=== SoundOut ===\n");
  // for (SKSoundOut *sout in server.outputList) {
  //   [sout printDescription];
  // }
}

- (SKSoundOut *)defaultSoundOut
{
  SKSoundOut *sOut;
  // SKSoundStream *sStream;
  // sStream = [[SKSoundStream alloc] initWithDevice:sOut];

  for (SKSoundOut *sout in [server outputList]) {
    [sout printDescription];
  }

  sOut = [server defaultOutput];
  fprintf(stderr, "========= Default SoundOut =========\n");
  [sOut printDescription];

  return sOut;
}

- (SKSoundIn *)defaultSoundIn
{
  SKSoundIn *sIn;

  for (SKSoundIn *sin in [server inputList]) {
    [sin printDescription];
  }

  sIn = [server defaultInput];
  fprintf(stderr, "========= Default SoundIn =========\n");
  [sIn printDescription];

  return sIn;
}

- (void)serverStateChanged:(NSNotification *)notif
{
  if (server.status == SKServerReadyState) {
    [self describeSoundSystem];
    [self defaultSoundOut];
    [self defaultSoundIn];
  }
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
  conn = [NSConnection defaultConnection];
  [conn registerName:@"soundtool"];

  signal(SIGHUP, handle_signal);
  signal(SIGINT, handle_signal);
  signal(SIGQUIT, handle_signal);
  signal(SIGTERM, handle_signal);
  
  [client runLoopRun];

  fprintf(stderr, "Runloop exited.\n");

  [conn invalidate];
  [client release];
  [pool release];

  return 0;
}
