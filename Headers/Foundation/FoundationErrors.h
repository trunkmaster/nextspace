/* Interface for FoundationErrors for GNUstep
   Copyright (C) 2008 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: 2008
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
   */ 

#ifndef __FoundationErrors_h_GNUSTEP_BASE_INCLUDE
#define __FoundationErrors_h_GNUSTEP_BASE_INCLUDE

#import <GNUstepBase/GSVersionMacros.h>
#import <Foundation/NSObject.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_4, GS_API_LATEST)

/* These are those of the NSError code values for the NSCocoaErrorDomain
 * which are defined in the foundation/base library.
 */

enum
{

  NSFileErrorMaximum = 1023,
  NSFileErrorMinimum = 0,
  NSFileLockingError = 255,
  NSFileNoSuchFileError = 4,
  NSFileReadCorruptFileError = 259,
  NSFileReadInapplicableStringEncodingError = 261,
  NSFileReadInvalidFileNameError = 258,
  NSFileReadNoPermissionError = 257,
  NSFileReadNoSuchFileError = 260,
  NSFileReadUnknownError = 256,
  NSFileReadUnsupportedSchemeError = 262,
  NSFileWriteInapplicableStringEncodingError = 517,
  NSFileWriteInvalidFileNameError = 514,
  NSFileWriteFileExistsError = 516,
  NSFileWriteNoPermissionError = 513,
  NSFileWriteOutOfSpaceError = 640,
  NSFileWriteUnknownError = 512,
  NSFileWriteUnsupportedSchemeError = 518,
  NSFormattingError = 2048,
  NSFormattingErrorMaximum = 2559,
  NSFormattingErrorMinimum = 2048,
  NSKeyValueValidationError = 1024,
  NSUserCancelledError = 3072,
  NSValidationErrorMaximum = 2047,
  NSValidationErrorMinimum = 1024,

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
  NSExecutableArchitectureMismatchError = 3585,
  NSExecutableErrorMaximum = 3839,
  NSExecutableErrorMinimum = 3584,
  NSExecutableLinkError = 3588,
  NSExecutableLoadError = 3587,
  NSExecutableNotLoadableError = 3584,
  NSExecutableRuntimeMismatchError = 3586,
  NSFileReadTooLargeError = 263,
  NSFileReadUnknownStringEncodingError = 264,
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
  NSFileWriteVolumeReadOnlyError = 642,
  NSPropertyListErrorMaximum = 4095,
  NSPropertyListErrorMinimum = 3840,
  NSPropertyListReadCorruptError = 3840,
  NSPropertyListReadStreamError = 3842,
  NSPropertyListReadUnknownVersionError = 3841,
  NSPropertyListWriteStreamError = 3851,
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_8, GS_API_LATEST)
  NSFeatureUnsupportedError = 3328,
  NSXPCConnectionErrorMaximum = 4224,
  NSXPCConnectionErrorMinimum = 4096,
  NSXPCConnectionInterrupted = 4097,
  NSXPCConnectionInvalid = 4099,
  NSXPCConnectionReplyInvalid = 4101,
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_9, GS_API_LATEST)
  NSUbiquitousFileErrorMaximum = 4607,
  NSUbiquitousFileErrorMinimum = 4352,
  NSUbiquitousFileNotUploadedDueToQuotaError = 4354,
  NSUbiquitousFileUbiquityServerNotAvailable = 4355,
  NSUbiquitousFileUnavailableError = 4353, 
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_10, GS_API_LATEST)
  NSPropertyListWriteInvalidError = 3852,       
  NSUserActivityConnectionUnavailableError = 4609,
  NSUserActivityErrorMaximum = 4863, 
  NSUserActivityErrorMinimum = 4608,
  NSUserActivityHandoffFailedError = 4608,
  NSUserActivityHandoffUserInfoTooLargeError = 4611,
  NSUserActivityRemoteApplicationTimedOutError = 4610,
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
  NSBundleErrorMaximum = 5119,
  NSBundleErrorMinimum = 4992,
  NSCoderErrorMaximum = 4991,
  NSCoderErrorMinimum = 4864,
  NSCoderReadCorruptError = 4864,
  NSCoderValueNotFoundError = 4865,
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_12, GS_API_LATEST)
  NSCloudSharingConflictError = 5123,
  NSCloudSharingErrorMaximum = 5375,
  NSCloudSharingErrorMinimum = 5120, 
  NSCloudSharingNetworkFailureError = 5120,
  NSCloudSharingNoPermissionError = 5124,
  NSCloudSharingOtherError = 5375,
  NSCloudSharingQuotaExceededError = 5121,
  NSCloudSharingTooManyParticipantsError = 5122,
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_13, GS_API_LATEST)
  NSCoderInvalidValueError = 4866, 
#endif

  GSFoundationPlaceHolderError = 9999
};

#endif
#endif

