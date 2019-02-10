/* -*- mode: objc -*- */
/*
  Project: SoundKit framework.

  Copyright (C) 2019 Sergii Stoian

  This application is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public
  License as published by the Free Software Foundation; either
  version 2 of the License, or (at your option) any later version.

  This application is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Library General Public License for more details.

  You should have received a copy of the GNU General Public
  License along with this library; if not, write to the Free
  Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import <pulse/pulseaudio.h>
#import <Foundation/Foundation.h>

@interface NXSoundDevice : NSObject // <NXSoundParameters>
{
  id       _server;
  NSString *_name;
  NSString *_description;
  
  // port_t		_devicePort;
  // port_t		_streamOwnerPort;
  // unsigned int		_bufferSize;
  // unsigned int		_bufferCount;
  // unsigned int		_isDetectingPeaks;
  // unsigned int		_peakHistory;
  // kern_return_t		_kernelError;
  // NXSoundDeviceError	_lastError;
  // int			_reserved;
}
// + (NSString *)textForError:(NXSoundDeviceError)errorCode;
// + (unsigned int)timeout;
// + setTimeout:(unsigned int)milliseconds;
// + (port_t)replyPort;
// + (BOOL)isUsingSeparateThread;
// + setUseSeparateThread:(BOOL)flag;
// + (cthread_t)replyThread;
// + (int)threadThreshold;
// + setThreadThreshold:(int)threshold;

// New in 3.1.
// - (id <NXSoundParameters>)parameters;
// - (NXSoundDeviceError)setParameters:(id <NXSoundParameters>)params;
// - (BOOL)acceptsContinuousStreamSamplingRates;
// - (NXSoundDeviceError)getStreamSamplingRatesLow:(float *)lowRate
//                                            high:(float *)highRate;
// - (NXSoundDeviceError)getStreamSamplingRates:(const float **)rates
//                                        count:(unsigned int *)numRates;
// - (NXSoundDeviceError)getStreamDataEncodings:
//   (const NXSoundParameterTag **)encodings
//                                        count:(unsigned int *)numEncodings;
// - (unsigned int)streamChannelCountLimit;
// - (unsigned int)clipCount;
// - (NSString *)name;

- (id)init;
- (id)initOnHost:(NSString *)hostName
        withName:(NSString *)appName;
- (NSString *)host;

// - (port_t)devicePort;
// - (port_t)streamOwnerPort;
// - (BOOL)isReserved;
// - (NXSoundDeviceError)setReserved:(BOOL)flag;
// - (void)pauseStreams:sender;
// - (void)resumeStreams:sender;
// - (void)abortStreams:sender;
// - (NXSoundDeviceError)getPeakLeft:(float *)leftAmp
//                             right:(float *)rightAmp;
// - (NXSoundDeviceError)lastError;
// - (void)dealloc;

// // Obsolete - use generic parameter api.
// - (unsigned int)bufferSize;
// - (NXSoundDeviceError)setBufferSize:(unsigned int)bytes;
// - (unsigned int)bufferCount;
// - (NXSoundDeviceError)setBufferCount:(unsigned int)count;
// - (unsigned int)peakHistory;
// - (NXSoundDeviceError)setPeakHistory:(unsigned int)bufferCount;
// - (BOOL)isDetectingPeaks;
// - (NXSoundDeviceError)setDetectPeaks:(BOOL)flag;

@end
