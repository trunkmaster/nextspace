/* Interface for NSURLError for GNUstep
   Copyright (C) 2006 Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <frm@gnu.org>
   Date: 2006
   
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

#ifndef __NSURLError_h_GNUSTEP_BASE_INCLUDE
#define __NSURLError_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSString;

/**
 * The domain for a URL error.
 */
GS_EXPORT NSString * const NSURLErrorDomain;

/**
 * Obtain the URL which caused the failure
 */
GS_EXPORT NSString * const NSErrorFailingURLStringKey;

/**
 * Error codes for URL errors
 */
enum
{
  NSURLErrorUnknown = 				-1,
  NSURLErrorCancelled = 			-999,
  NSURLErrorBadURL = 				-1000,
  NSURLErrorTimedOut = 				-1001,
  NSURLErrorUnsupportedURL = 			-1002,
  NSURLErrorCannotFindHost = 			-1003,
  NSURLErrorCannotConnectToHost = 		-1004,
  NSURLErrorNetworkConnectionLost = 		-1005,
  NSURLErrorDNSLookupFailed = 			-1006,
  NSURLErrorHTTPTooManyRedirects = 		-1007,
  NSURLErrorResourceUnavailable = 		-1008,
  NSURLErrorNotConnectedToInternet = 		-1009,
  NSURLErrorRedirectToNonExistentLocation = 	-1010,
  NSURLErrorBadServerResponse = 		-1011,
  NSURLErrorUserCancelledAuthentication = 	-1012,
  NSURLErrorUserAuthenticationRequired = 	-1013,
  NSURLErrorZeroByteResource = 			-1014,
#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
  NSURLErrorCannotDecodeRawData =		-1015,
  NSURLErrorCannotDecodeContentData =		-1016,
  NSURLErrorCannotParseResponse =		-1017,
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)
  NSURLErrorInternationalRoamingOff =		-1018,
  NSURLErrorCallIsActive =			-1019,
  NSURLErrorDataNotAllowed =			-1020,
  NSURLErrorRequestBodyStreamExhausted =	-1021,
#endif
  NSURLErrorFileDoesNotExist = 			-1100,
  NSURLErrorFileIsDirectory = 			-1101,
  NSURLErrorNoPermissionsToReadFile = 		-1102,
#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
  NSURLErrorDataLengthExceedsMaximum =		-1103,
#endif
  NSURLErrorSecureConnectionFailed = 		-1200,
  NSURLErrorServerCertificateHasBadDate = 	-1201,
  NSURLErrorServerCertificateUntrusted = 	-1202,
  NSURLErrorServerCertificateHasUnknownRoot =	-1203,
  NSURLErrorServerCertificateNotYetValid = 	-1204,
  NSURLErrorClientCertificateRejected = 	-1205,
#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
  NSURLErrorClientCertificateRequired = -1206,
#endif
  NSURLErrorCannotLoadFromNetwork = 		-2000,

  NSURLErrorCannotCreateFile = 			-3000,
  NSURLErrorCannotOpenFile = 			-3001,
  NSURLErrorCannotCloseFile = 			-3002,
  NSURLErrorCannotWriteToFile = 		-3003,
  NSURLErrorCannotRemoveFile = 			-3004,
  NSURLErrorCannotMoveFile = 			-3005,
  NSURLErrorDownloadDecodingFailedMidStream =	-3006,
  NSURLErrorDownloadDecodingFailedToComplete =	-3007
};

#if	defined(__cplusplus)
}
#endif

#endif

#endif
