/** All of the external data
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Scott Christley <scottc@net-community.com>
   Date: August 1997

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

#import "common.h"

#import "Foundation/NSError.h"

/*
 * NSConnection Notification Strings.
 */
GS_DECLARE NSString* const NSConnectionDidDieNotification = @"NSConnectionDidDieNotification";

GS_DECLARE NSString* const NSConnectionDidInitializeNotification = @"NSConnectionDidInitializeNotification";


/*
 * NSDistributedNotificationCenter types.
 */
GS_DECLARE NSString* const NSLocalNotificationCenterType = @"NSLocalNotificationCenterType";
GS_DECLARE NSString* const GSNetworkNotificationCenterType = @"GSNetworkNotificationCenterType";
GS_DECLARE NSString* const GSPublicNotificationCenterType = @"GSPublicNotificationCenterType";

/*
 * NSThread Notifications
 */
GS_DECLARE NSString* const NSWillBecomeMultiThreadedNotification = @"NSWillBecomeMultiThreadedNotification";

GS_DECLARE NSString* const NSThreadDidStartNotification = @"NSThreadDidStartNotification";

GS_DECLARE NSString* const NSThreadWillExitNotification = @"NSThreadWillExitNotification";


/*
 * Port Notifications
 */

GS_DECLARE NSString* const NSPortDidBecomeInvalidNotification = @"NSPortDidBecomeInvalidNotification";

/* NSTask notifications */
GS_DECLARE NSString* const NSTaskDidTerminateNotification = @"NSTaskDidTerminateNotification";

/* NSUndoManager notifications */
GS_DECLARE NSString* const NSUndoManagerCheckpointNotification = @"NSUndoManagerCheckpointNotification";

GS_DECLARE NSString* const NSUndoManagerDidOpenUndoGroupNotification = @"NSUndoManagerDidOpenUndoGroupNotification";

GS_DECLARE NSString* const NSUndoManagerDidRedoChangeNotification = @"NSUndoManagerDidRedoChangeNotification";

GS_DECLARE NSString* const NSUndoManagerDidUndoChangeNotification = @"NSUndoManagerDidUndoChangeNotification";

GS_DECLARE NSString* const NSUndoManagerWillCloseUndoGroupNotification = @"NSUndoManagerWillCloseUndoGroupNotification";

GS_DECLARE NSString* const NSUndoManagerWillRedoChangeNotification = @"NSUndoManagerWillRedoChangeNotification";

GS_DECLARE NSString* const NSUndoManagerWillUndoChangeNotification = @"NSUndoManagerWillUndoChangeNotification";

/*
 * NSUbiquitousKeyValueStore notifications
 */
GS_DECLARE NSString* const NSUbiquitousKeyValueStoreDidChangeExternallyNotification = @"NSUbiquitousKeyValueStoreDidChangeExternallyNotification";
GS_DECLARE NSString* const NSUbiquitousKeyValueStoreChangeReasonKey = @"NSUbiquitousKeyValueStoreChangeReasonKey";

/* NSURL constants */
GS_DECLARE NSString* const NSURLFileScheme = @"file";

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
GS_DECLARE NSString* const NSURLNameKey = @"NSURLNameKey";
GS_DECLARE NSString* const NSURLLocalizedNameKey = @"NSURLLocalizedNameKey";
GS_DECLARE NSString* const NSURLIsRegularFileKey = @"NSURLIsRegularFileKey";
GS_DECLARE NSString* const NSURLIsDirectoryKey = @"NSURLIsDirectoryKey";
GS_DECLARE NSString* const NSURLIsSymbolicLinkKey = @"NSURLIsSymbolicLinkKey";
GS_DECLARE NSString* const NSURLIsVolumeKey = @"NSURLIsVolumeKey";
GS_DECLARE NSString* const NSURLIsPackageKey = @"NSURLIsPackageKey";
GS_DECLARE NSString* const NSURLIsSystemImmutableKey = @"NSURLIsSystemImmutableKey";
GS_DECLARE NSString* const NSURLIsUserImmutableKey = @"NSURLIsUserImmutableKey";
GS_DECLARE NSString* const NSURLIsHiddenKey = @"NSURLIsHiddenKey";
GS_DECLARE NSString* const NSURLHasHiddenExtensionKey = @"NSURLHasHiddenExtensionKey";
GS_DECLARE NSString* const NSURLCreationDateKey = @"NSURLCreationDateKey";
GS_DECLARE NSString* const NSURLContentAccessDateKey = @"NSURLContentAccessDateKey";
GS_DECLARE NSString* const NSURLContentModificationDateKey = @"NSURLContentModificationDateKey";
GS_DECLARE NSString* const NSURLAttributeModificationDateKey = @"NSURLAttributeModificationDateKey";
GS_DECLARE NSString* const NSURLLinkCountKey = @"NSURLLinkCountKey";
GS_DECLARE NSString* const NSURLParentDirectoryURLKey = @"NSURLParentDirectoryURLKey";
GS_DECLARE NSString* const NSURLVolumeURLKey = @"NSURLVolumeURLKey";
GS_DECLARE NSString* const NSURLTypeIdentifierKey = @"NSURLTypeIdentifierKey";
GS_DECLARE NSString* const NSURLLocalizedTypeDescriptionKey = @"NSURLLocalizedTypeDescriptionKey";
GS_DECLARE NSString* const NSURLLabelNumberKey = @"NSURLLabelNumberKey";
GS_DECLARE NSString* const NSURLLabelColorKey = @"NSURLLabelColorKey";
GS_DECLARE NSString* const NSURLLocalizedLabelKey = @"NSURLLocalizedLabelKey";
GS_DECLARE NSString* const NSURLEffectiveIconKey = @"NSURLEffectiveIconKey";
GS_DECLARE NSString* const NSURLCustomIconKey = @"NSURLCustomIconKey";
GS_DECLARE NSString* const NSURLFileSizeKey = @"NSURLFileSizeKey";
GS_DECLARE NSString* const NSURLFileAllocatedSizeKey = @"NSURLFileAllocatedSizeKey";
GS_DECLARE NSString* const NSURLIsAliasFileKey = @"NSURLIsAliasFileKey";
GS_DECLARE NSString* const NSURLVolumeLocalizedFormatDescriptionKey = @"NSURLVolumeLocalizedFormatDescriptionKey";
GS_DECLARE NSString* const NSURLVolumeTotalCapacityKey = @"NSURLVolumeTotalCapacityKey";
GS_DECLARE NSString* const NSURLVolumeAvailableCapacityKey = @"NSURLVolumeAvailableCapacityKey";
GS_DECLARE NSString* const NSURLVolumeResourceCountKey = @"NSURLVolumeResourceCountKey";
GS_DECLARE NSString* const NSURLVolumeSupportsPersistentIDsKey = @"NSURLVolumeSupportsPersistentIDsKey";
GS_DECLARE NSString* const NSURLVolumeSupportsSymbolicLinksKey = @"NSURLVolumeSupportsSymbolicLinksKey";
GS_DECLARE NSString* const NSURLVolumeSupportsHardLinksKey = @"NSURLVolumeSupportsHardLinksKey";
GS_DECLARE NSString* const NSURLVolumeSupportsJournalingKey = @"NSURLVolumeSupportsJournalingKey";
GS_DECLARE NSString* const NSURLVolumeIsJournalingKey = @"NSURLVolumeIsJournalingKey";
GS_DECLARE NSString* const NSURLVolumeSupportsSparseFilesKey = @"NSURLVolumeSupportsSparseFilesKey";
GS_DECLARE NSString* const NSURLVolumeSupportsZeroRunsKey = @"NSURLVolumeSupportsZeroRunsKey";
GS_DECLARE NSString* const NSURLVolumeSupportsCaseSensitiveNamesKey = @"NSURLVolumeSupportsCaseSensitiveNamesKey";
GS_DECLARE NSString* const NSURLVolumeSupportsCasePreservedNamesKey = @"NSURLVolumeSupportsCasePreservedNamesKey";
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)
GS_DECLARE NSString* const NSURLFileResourceIdentifierKey = @"NSURLFileResourceIdentifierKey";
GS_DECLARE NSString* const NSURLVolumeIdentifierKey = @"NSURLVolumeIdentifierKey";
GS_DECLARE NSString* const NSURLPreferredIOBlockSizeKey = @"NSURLPreferredIOBlockSizeKey";
GS_DECLARE NSString* const NSURLIsReadableKey = @"NSURLIsReadableKey";
GS_DECLARE NSString* const NSURLIsWritableKey = @"NSURLIsWritableKey";
GS_DECLARE NSString* const NSURLIsExecutableKey = @"NSURLIsExecutableKey";
GS_DECLARE NSString* const NSURLFileSecurityKey = @"NSURLFileSecurityKey";
GS_DECLARE NSString* const NSURLIsMountTriggerKey = @"NSURLIsMountTriggerKey";
GS_DECLARE NSString* const NSURLFileResourceTypeKey = @"NSURLFileResourceTypeKey";
GS_DECLARE NSString* const NSURLTotalFileSizeKey = @"NSURLTotalFileSizeKey";
GS_DECLARE NSString* const NSURLTotalFileAllocatedSizeKey = @"NSURLTotalFileAllocatedSizeKey";
GS_DECLARE NSString* const NSURLVolumeSupportsRootDirectoryDatesKey = @"NSURLVolumeSupportsRootDirectoryDatesKey";
GS_DECLARE NSString* const NSURLVolumeSupportsVolumeSizesKey = @"NSURLVolumeSupportsVolumeSizesKey";
GS_DECLARE NSString* const NSURLVolumeSupportsRenamingKey = @"NSURLVolumeSupportsRenamingKey";
GS_DECLARE NSString* const NSURLVolumeSupportsAdvisoryFileLockingKey = @"NSURLVolumeSupportsAdvisoryFileLockingKey";
GS_DECLARE NSString* const NSURLVolumeSupportsExtendedSecurityKey = @"NSURLVolumeSupportsExtendedSecurityKey";
GS_DECLARE NSString* const NSURLVolumeIsBrowsableKey = @"NSURLVolumeIsBrowsableKey";
GS_DECLARE NSString* const NSURLVolumeMaximumFileSizeKey = @"NSURLVolumeMaximumFileSizeKey";
GS_DECLARE NSString* const NSURLVolumeIsEjectableKey = @"NSURLVolumeIsEjectableKey";
GS_DECLARE NSString* const NSURLVolumeIsRemovableKey = @"NSURLVolumeIsRemovableKey";
GS_DECLARE NSString* const NSURLVolumeIsInternalKey = @"NSURLVolumeIsInternalKey";
GS_DECLARE NSString* const NSURLVolumeIsAutomountedKey = @"NSURLVolumeIsAutomountedKey";
GS_DECLARE NSString* const NSURLVolumeIsLocalKey = @"NSURLVolumeIsLocalKey";
GS_DECLARE NSString* const NSURLVolumeIsReadOnlyKey = @"NSURLVolumeIsReadOnlyKey";
GS_DECLARE NSString* const NSURLVolumeCreationDateKey = @"NSURLVolumeCreationDateKey";
GS_DECLARE NSString* const NSURLVolumeURLForRemountingKey = @"NSURLVolumeURLForRemountingKey";
GS_DECLARE NSString* const NSURLVolumeUUIDStringKey = @"NSURLVolumeUUIDStringKey";
GS_DECLARE NSString* const NSURLVolumeNameKey = @"NSURLVolumeNameKey";
GS_DECLARE NSString* const NSURLVolumeLocalizedNameKey = @"NSURLVolumeLocalizedNameKey";
GS_DECLARE NSString* const NSURLIsUbiquitousItemKey = @"NSURLIsUbiquitousItemKey";
GS_DECLARE NSString* const NSURLUbiquitousItemHasUnresolvedConflictsKey = @"NSURLUbiquitousItemHasUnresolvedConflictsKey";
GS_DECLARE NSString* const NSURLUbiquitousItemIsDownloadingKey = @"NSURLUbiquitousItemIsDownloadingKey";
GS_DECLARE NSString* const NSURLUbiquitousItemIsUploadedKey = @"NSURLUbiquitousItemIsUploadedKey";
GS_DECLARE NSString* const NSURLUbiquitousItemIsUploadingKey = @"NSURLUbiquitousItemIsUploadingKey";
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_8, GS_API_LATEST)
GS_DECLARE NSString* const NSURLIsExcludedFromBackupKey = @"NSURLIsExcludedFromBackupKey";
GS_DECLARE NSString* const NSURLPathKey = @"NSURLPathKey";
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_9, GS_API_LATEST)
GS_DECLARE NSString* const NSURLTagNamesKey = @"NSURLTagNamesKey";
GS_DECLARE NSString* const NSURLUbiquitousItemDownloadingStatusKey = @"NSURLUbiquitousItemDownloadingStatusKey";
GS_DECLARE NSString* const NSURLUbiquitousItemDownloadingErrorKey = @"NSURLUbiquitousItemDownloadingErrorKey";
GS_DECLARE NSString* const NSURLUbiquitousItemUploadingErrorKey = @"NSURLUbiquitousItemUploadingErrorKey";
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_10, GS_API_LATEST)
GS_DECLARE NSString* const NSURLGenerationIdentifierKey = @"NSURLGenerationIdentifierKey";
GS_DECLARE NSString* const NSURLDocumentIdentifierKey = @"NSURLDocumentIdentifierKey";
GS_DECLARE NSString* const NSURLAddedToDirectoryDateKey = @"NSURLAddedToDirectoryDateKey";
GS_DECLARE NSString* const NSURLQuarantinePropertiesKey = @"NSURLQuarantinePropertiesKey";
GS_DECLARE NSString* const NSThumbnail1024x1024SizeKey = @"NSThumbnail1024x1024SizeKey";
GS_DECLARE NSString* const NSURLUbiquitousItemDownloadRequestedKey = @"NSURLUbiquitousItemDownloadRequestedKey";
GS_DECLARE NSString* const NSURLUbiquitousItemContainerDisplayNameKey = @"NSURLUbiquitousItemContainerDisplayNameKey";
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
GS_DECLARE NSString* const NSURLIsApplicationKey = @"NSURLIsApplicationKey";
GS_DECLARE NSString* const NSURLApplicationIsScriptableKey = @"NSURLApplicationIsScriptableKey";
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)
GS_DECLARE NSString* const NSURLFileResourceTypeNamedPipe = @"NSURLFileResourceTypeNamedPipe";
GS_DECLARE NSString* const NSURLFileResourceTypeCharacterSpecial = @"NSURLFileResourceTypeCharacterSpecial";
GS_DECLARE NSString* const NSURLFileResourceTypeDirectory = @"NSURLFileResourceTypeDirectory";
GS_DECLARE NSString* const NSURLFileResourceTypeBlockSpecial = @"NSURLFileResourceTypeBlockSpecial";
GS_DECLARE NSString* const NSURLFileResourceTypeRegular = @"NSURLFileResourceTypeRegular";
GS_DECLARE NSString* const NSURLFileResourceTypeSymbolicLink = @"NSURLFileResourceTypeSymbolicLink";
GS_DECLARE NSString* const NSURLFileResourceTypeSocket = @"NSURLFileResourceTypeSocket";
GS_DECLARE NSString* const NSURLFileResourceTypeUnknown = @"NSURLFileResourceTypeUnknown";
#endif

/* NSURLError */
GS_DECLARE NSString* const NSURLErrorDomain = @"NSURLErrorDomain";
GS_DECLARE NSString* const NSErrorFailingURLStringKey = @"NSErrorFailingURLStringKey";

/** Possible values for Ubiquitous Item Downloading Key **/
#if OS_API_VERSION(MAC_OS_X_VERSION_10_9, GS_API_LATEST)
GS_DECLARE NSString* const NSURLUbiquitousItemDownloadingStatusNotDownloaded = @"NSURLUbiquitousItemDownloadingStatusNotDownloaded";
GS_DECLARE NSString* const NSURLUbiquitousItemDownloadingStatusDownloaded = @"NSURLUbiquitousItemDownloadingStatusDownloaded";
GS_DECLARE NSString* const NSURLUbiquitousItemDownloadingStatusCurrent = @"NSURLUbiquitousItemDownloadingStatusCurrent";
#endif

/* RunLoop modes */
GS_DECLARE NSString* const NSConnectionReplyMode = @"NSConnectionReplyMode";

/* NSValueTransformer constants */
GS_DECLARE NSString* const NSNegateBooleanTransformerName = @"NSNegateBoolean";
GS_DECLARE NSString* const NSIsNilTransformerName = @"NSIsNil";
GS_DECLARE NSString* const NSIsNotNilTransformerName = @"NSIsNotNil"; 
GS_DECLARE NSString* const NSUnarchiveFromDataTransformerName = @"NSUnarchiveFromData";

/* Standard domains */
GS_DECLARE NSString* const NSArgumentDomain = @"NSArgumentDomain";

GS_DECLARE NSString* const NSGlobalDomain = @"NSGlobalDomain";

GS_DECLARE NSString* const NSRegistrationDomain = @"NSRegistrationDomain";

GS_DECLARE NSString* const GSConfigDomain = @"GSConfigDomain";


/* Public notification */
GS_DECLARE NSString* const NSUserDefaultsDidChangeNotification = @"NSUserDefaultsDidChangeNotification";


/* Keys for language-dependent information */
GS_DECLARE NSString* const NSWeekDayNameArray = @"NSWeekDayNameArray";

GS_DECLARE NSString* const NSShortWeekDayNameArray = @"NSShortWeekDayNameArray";

GS_DECLARE NSString* const NSMonthNameArray = @"NSMonthNameArray";

GS_DECLARE NSString* const NSShortMonthNameArray = @"NSShortMonthNameArray";

GS_DECLARE NSString* const NSTimeFormatString = @"NSTimeFormatString";

GS_DECLARE NSString* const NSDateFormatString = @"NSDateFormatString";

GS_DECLARE NSString* const NSShortDateFormatString = @"NSShortDateFormatString";

GS_DECLARE NSString* const NSTimeDateFormatString = @"NSTimeDateFormatString";

GS_DECLARE NSString* const NSShortTimeDateFormatString = @"NSShortTimeDateFormatString";

GS_DECLARE NSString* const NSCurrencySymbol = @"NSCurrencySymbol";

GS_DECLARE NSString* const NSDecimalSeparator = @"NSDecimalSeparator";

GS_DECLARE NSString* const NSThousandsSeparator = @"NSThousandsSeparator";

GS_DECLARE NSString* const NSInternationalCurrencyString = @"NSInternationalCurrencyString";

GS_DECLARE NSString* const NSCurrencyString = @"NSCurrencyString";

GS_DECLARE NSString* const NSNegativeCurrencyFormatString = @"NSNegativeCurrencyFormatString";

GS_DECLARE NSString* const NSPositiveCurrencyFormatString = @"NSPositiveCurrencyFormatString";

GS_DECLARE NSString* const NSDecimalDigits = @"NSDecimalDigits";

GS_DECLARE NSString* const NSAMPMDesignation = @"NSAMPMDesignation";


GS_DECLARE NSString* const NSHourNameDesignations = @"NSHourNameDesignations";

GS_DECLARE NSString* const NSYearMonthWeekDesignations = @"NSYearMonthWeekDesignations";

GS_DECLARE NSString* const NSEarlierTimeDesignations = @"NSEarlierTimeDesignations";

GS_DECLARE NSString* const NSLaterTimeDesignations = @"NSLaterTimeDesignations";

GS_DECLARE NSString* const NSThisDayDesignations = @"NSThisDayDesignations";

GS_DECLARE NSString* const NSNextDayDesignations = @"NSNextDayDesignations";

GS_DECLARE NSString* const NSNextNextDayDesignations = @"NSNextNextDayDesignations";

GS_DECLARE NSString* const NSPriorDayDesignations = @"NSPriorDayDesignations";

GS_DECLARE NSString* const NSDateTimeOrdering = @"NSDateTimeOrdering";


/* These are in OPENSTEP 4.2 */
GS_DECLARE NSString* const NSLanguageCode = @"NSLanguageCode";

GS_DECLARE NSString* const NSLanguageName = @"NSLanguageName";

GS_DECLARE NSString* const NSFormalName = @"NSFormalName";

/* For GNUstep */
GS_DECLARE NSString* const GSLocale = @"GSLocale";
GS_DECLARE NSString *const GSCACertificateFilePath = @"GSCACertificateFilePath";


/*
 * Keys for the NSDictionary returned by [NSConnection -statistics]
 */
/* These in OPENSTEP 4.2 */
GS_DECLARE NSString* const NSConnectionRepliesReceived = @"NSConnectionRepliesReceived";

GS_DECLARE NSString* const NSConnectionRepliesSent = @"NSConnectionRepliesSent";

GS_DECLARE NSString* const NSConnectionRequestsReceived = @"NSConnectionRequestsReceived";

GS_DECLARE NSString* const NSConnectionRequestsSent = @"NSConnectionRequestsSent";

/* These Are GNUstep extras */
GS_DECLARE NSString* const NSConnectionLocalCount = @"NSConnectionLocalCount";

GS_DECLARE NSString* const NSConnectionProxyCount = @"NSConnectionProxyCount";

/* Class description notification */
GS_DECLARE NSString* const NSClassDescriptionNeededForClassNotification = @"NSClassDescriptionNeededForClassNotification";

/* NSArchiver */
GS_DECLARE NSString* const NSInconsistentArchiveException = @"NSInconsistentArchiveException";

/* NSBundle */
GS_DECLARE NSString* const NSBundleDidLoadNotification = @"NSBundleDidLoadNotification";
GS_DECLARE NSString* const NSShowNonLocalizedStrings = @"NSShowNonLocalizedStrings";
GS_DECLARE NSString* const NSLoadedClasses = @"NSLoadedClasses";

/* NSConnection */
GS_DECLARE NSString* const NSDestinationInvalidException = @"NSDestinationInvalidException";
GS_DECLARE NSString* const NSFailedAuthenticationException = @"NSFailedAuthenticationExceptions";
GS_DECLARE NSString* const NSObjectInaccessibleException = @"NSObjectInaccessibleException";
GS_DECLARE NSString* const NSObjectNotAvailableException = @"NSObjectNotAvailableException";

/* NSDate */
GS_DECLARE NSString* const NSSystemClockDidChangeNotification = @"NSSystemClockDidChangeNotification";

/* NSExtensionItem */
GS_DECLARE NSString* const NSExtensionItemAttributedTitleKey = @"NSExtensionItemAttributedTitleKey";
GS_DECLARE NSString* const NSExtensionItemAttributedContentTextKey = @"NSExtensionItemAttributedContentTextKey";
GS_DECLARE NSString* const NSExtensionItemAttachmentsKey = @"NSExtensionItemAttachmentsKey";

/* NSFileHandle */
GS_DECLARE NSString* const NSFileHandleNotificationDataItem = @"NSFileHandleNotificationDataItem";
GS_DECLARE NSString* const NSFileHandleNotificationFileHandleItem = @"NSFileHandleNotificationFileHandleItem";
GS_DECLARE NSString* const NSFileHandleNotificationMonitorModes = @"NSFileHandleNotificationMonitorModes";
GS_DECLARE NSString* const NSFileHandleConnectionAcceptedNotification = @"NSFileHandleConnectionAcceptedNotification";
GS_DECLARE NSString* const NSFileHandleDataAvailableNotification = @"NSFileHandleDataAvailableNotification";
GS_DECLARE NSString* const NSFileHandleReadCompletionNotification = @"NSFileHandleReadCompletionNotification";
GS_DECLARE NSString* const NSFileHandleReadToEndOfFileCompletionNotification = @"NSFileHandleReadToEndOfFileCompletionNotification";
GS_DECLARE NSString* const NSFileHandleOperationException = @"NSFileHandleOperationException";

/* NSFileHandle GNUstep additions */
GS_DECLARE NSString* const GSFileHandleConnectCompletionNotification = @"GSFileHandleConnectCompletionNotification";
GS_DECLARE NSString* const GSFileHandleWriteCompletionNotification = @"GSFileHandleWriteCompletionNotification";
GS_DECLARE NSString* const GSFileHandleNotificationError = @"GSFileHandleNotificationError";

/* NSFileHandle constants to control TLS/SSL (options) */
GS_DECLARE NSString* const GSTLSCAFile = @"GSTLSCAFile";
GS_DECLARE NSString* const GSTLSCertificateFile = @"GSTLSCertificateFile";
GS_DECLARE NSString* const GSTLSCertificateKeyFile = @"GSTLSCertificateKeyFile";
GS_DECLARE NSString* const GSTLSCertificateKeyPassword = @"GSTLSCertificateKeyPassword";
GS_DECLARE NSString* const GSTLSDebug = @"GSTLSDebug";
GS_DECLARE NSString* const GSTLSIssuers = @"GSTLSIssuers";
GS_DECLARE NSString* const GSTLSOwners = @"GSTLSOwners";
GS_DECLARE NSString* const GSTLSPriority = @"GSTLSPriority";
GS_DECLARE NSString* const GSTLSRemoteHosts = @"GSTLSRemoteHosts";
GS_DECLARE NSString* const GSTLSRevokeFile = @"GSTLSRevokeFile";
GS_DECLARE NSString* const GSTLSServerName = @"GSTLSServerName";
GS_DECLARE NSString* const GSTLSVerify = @"GSTLSVerify";

/* NSFileManager */
GS_DECLARE NSString* const NSFileAppendOnly = @"NSFileAppendOnly";
GS_DECLARE NSString* const NSFileCreationDate = @"NSFileCreationDate";
GS_DECLARE NSString* const NSFileDeviceIdentifier = @"NSFileDeviceIdentifier";
GS_DECLARE NSString* const NSFileExtensionHidden = @"NSFileExtensionHidden";
GS_DECLARE NSString* const NSFileGroupOwnerAccountID = @"NSFileGroupOwnerAccountID";
GS_DECLARE NSString* const NSFileGroupOwnerAccountName = @"NSFileGroupOwnerAccountName";
GS_DECLARE NSString* const NSFileHFSCreatorCode = @"NSFileHFSCreatorCode";
GS_DECLARE NSString* const NSFileHFSTypeCode = @"NSFileHFSTypeCode";
GS_DECLARE NSString* const NSFileImmutable = @"NSFileImmutable";
GS_DECLARE NSString* const NSFileModificationDate = @"NSFileModificationDate";
GS_DECLARE NSString* const NSFileOwnerAccountID = @"NSFileOwnerAccountID";
GS_DECLARE NSString* const NSFileOwnerAccountName = @"NSFileOwnerAccountName";
GS_DECLARE NSString* const NSFilePosixPermissions = @"NSFilePosixPermissions";
GS_DECLARE NSString* const NSFileReferenceCount = @"NSFileReferenceCount";
GS_DECLARE NSString* const NSFileSize = @"NSFileSize";
GS_DECLARE NSString* const NSFileSystemFileNumber = @"NSFileSystemFileNumber";
GS_DECLARE NSString* const NSFileSystemFreeNodes = @"NSFileSystemFreeNodes";
GS_DECLARE NSString* const NSFileSystemFreeSize = @"NSFileSystemFreeSize";
GS_DECLARE NSString* const NSFileSystemNodes = @"NSFileSystemNodes";
GS_DECLARE NSString* const NSFileSystemNumber = @"NSFileSystemNumber";
GS_DECLARE NSString* const NSFileSystemSize = @"NSFileSystemSize";
GS_DECLARE NSString* const NSFileType = @"NSFileType";
GS_DECLARE NSString* const NSFileTypeBlockSpecial = @"NSFileTypeBlockSpecial";
GS_DECLARE NSString* const NSFileTypeCharacterSpecial = @"NSFileTypeCharacterSpecial";
GS_DECLARE NSString* const NSFileTypeDirectory = @"NSFileTypeDirectory";
GS_DECLARE NSString* const NSFileTypeFifo = @"NSFileTypeFifo";
GS_DECLARE NSString* const NSFileTypeRegular = @"NSFileTypeRegular";
GS_DECLARE NSString* const NSFileTypeSocket = @"NSFileTypeSocket";
GS_DECLARE NSString* const NSFileTypeSymbolicLink = @"NSFileTypeSymbolicLink";
GS_DECLARE NSString* const NSFileTypeUnknown = @"NSFileTypeUnknown";

/* NSHTTPCookie */
GS_DECLARE NSString* const NSHTTPCookieComment = @"Comment";
GS_DECLARE NSString* const NSHTTPCookieCommentURL = @"CommentURL";
GS_DECLARE NSString* const NSHTTPCookieDiscard = @"Discard";
GS_DECLARE NSString* const NSHTTPCookieDomain = @"Domain";
GS_DECLARE NSString* const NSHTTPCookieExpires = @"Expires";
GS_DECLARE NSString* const NSHTTPCookieMaximumAge = @"MaximumAge";
GS_DECLARE NSString* const NSHTTPCookieName = @"Name";
GS_DECLARE NSString* const NSHTTPCookieOriginURL = @"OriginURL";
GS_DECLARE NSString* const NSHTTPCookiePath = @"Path";
GS_DECLARE NSString* const NSHTTPCookiePort = @"Port";
GS_DECLARE NSString* const NSHTTPCookieSecure = @"Secure";
GS_DECLARE NSString* const NSHTTPCookieValue = @"Value";
GS_DECLARE NSString* const NSHTTPCookieVersion = @"Version";

/* NSCookieStorage */
GS_DECLARE NSString* const NSHTTPCookieManagerAcceptPolicyChangedNotification = @"NSHTTPCookieManagerAcceptPolicyChangedNotification";
GS_DECLARE NSString* const NSHTTPCookieManagerCookiesChangedNotification = @"NSHTTPCookieManagerCookiesChangedNotification";

/* NSItemProvider */
GS_DECLARE NSString* const NSItemProviderPreferredImageSizeKey = @"NSItemProviderPreferredImageSizeKey";
GS_DECLARE NSString* const NSExtensionJavaScriptPreprocessingResultsKey = @"NSExtensionJavaScriptPreprocessingResultsKey"; 
GS_DECLARE NSString* const NSExtensionJavaScriptFinalizeArgumentKey = @"NSExtensionJavaScriptFinalizeArgumentKey";
GS_DECLARE NSString* const NSItemProviderErrorDomain = @"NSItemProviderErrorDomain";

/* NSKeyedArchiver */
GS_DECLARE NSString* const NSInvalidArchiveOperationException = @"NSInvalidArchiveOperationException";

/* NSKeyedUnarchiver */
GS_DECLARE NSString* const NSInvalidUnarchiveOperationException = @"NSInvalidUnarchiveOperationException";

/* NSKeyValueCoding
 * For backward compatibility NSUndefinedKeyException is actually the same
 * as the older NSUnknownKeyException
 */
GS_DECLARE NSString* const NSUnknownKeyException = @"NSUnknownKeyException";
GS_DECLARE NSString* const NSUndefinedKeyException = @"NSUnknownKeyException";

/* NSKeyValueObserving */
GS_DECLARE NSString* const NSKeyValueChangeIndexesKey = @"indexes";
GS_DECLARE NSString* const NSKeyValueChangeKindKey = @"kind";
GS_DECLARE NSString* const NSKeyValueChangeNewKey = @"new";
GS_DECLARE NSString* const NSKeyValueChangeOldKey = @"old";
GS_DECLARE NSString* const NSKeyValueChangeNotificationIsPriorKey = @"notificationIsPrior";

/* NSLocale */
GS_DECLARE NSString* const NSCurrentLocaleDidChangeNotification = @"NSCurrentLocaleDidChangeNotification";

/* NSLocale Component Keys */
GS_DECLARE NSString* const NSLocaleIdentifier = @"NSLocaleIdentifier";
GS_DECLARE NSString* const NSLocaleLanguageCode = @"NSLocaleLanguageCode";
GS_DECLARE NSString* const NSLocaleCountryCode = @"NSLocaleCountryCode";
GS_DECLARE NSString* const NSLocaleScriptCode = @"NSLocaleScriptCode";
GS_DECLARE NSString* const NSLocaleVariantCode = @"NSLocaleVariantCode";
GS_DECLARE NSString* const NSLocaleExemplarCharacterSet = @"NSLocaleExemplarCharacterSet";
GS_DECLARE NSString* const NSLocaleCalendarIdentifier = @"calendar";
GS_DECLARE NSString* const NSLocaleCalendar = @"NSLocaleCalendar";
GS_DECLARE NSString* const NSLocaleCollationIdentifier = @"collation";
GS_DECLARE NSString* const NSLocaleUsesMetricSystem = @"NSLocaleUsesMetricSystem";
GS_DECLARE NSString* const NSLocaleMeasurementSystem = @"NSLocaleMeasurementSystem";
GS_DECLARE NSString* const NSLocaleDecimalSeparator = @"NSLocaleDecimalSeparator";
GS_DECLARE NSString* const NSLocaleGroupingSeparator = @"NSLocaleGroupingSeparator";
GS_DECLARE NSString* const NSLocaleCurrencySymbol = @"NSLocaleCurrencySymbol";
GS_DECLARE NSString* const NSLocaleCurrencyCode = @"NSLocaleCurrencyCode";
GS_DECLARE NSString* const NSLocaleCollatorIdentifier = @"NSLocaleCollatorIdentifier";
GS_DECLARE NSString* const NSLocaleQuotationBeginDelimiterKey = @"NSLocaleQuotationBeginDelimiterKey";
GS_DECLARE NSString* const NSLocaleQuotationEndDelimiterKey = @"NSLocaleQuotationEndDelimiterKey";
GS_DECLARE NSString* const NSLocaleAlternateQuotationBeginDelimiterKey = @"NSLocaleAlternateQuotationBeginDelimiterKey";
GS_DECLARE NSString* const NSLocaleAlternateQuotationEndDelimiterKey = @"NSLocaleAlternateQuotationEndDelimiterKey";

/* NSLocale Calendar Keys */
GS_DECLARE NSString* const NSGregorianCalendar = @"gregorian";
GS_DECLARE NSString* const NSBuddhistCalendar = @"buddhist";
GS_DECLARE NSString* const NSChineseCalendar = @"chinese";
GS_DECLARE NSString* const NSHebrewCalendar = @"hebrew";
GS_DECLARE NSString* const NSIslamicCalendar = @"islamic";
GS_DECLARE NSString* const NSIslamicCivilCalendar = @"islamic-civil";
GS_DECLARE NSString* const NSJapaneseCalendar = @"japanese";
GS_DECLARE NSString* const NSRepublicOfChinaCalendar = @"roc";
GS_DECLARE NSString* const NSPersianCalendar = @"persian";
GS_DECLARE NSString* const NSIndianCalendar = @"indian";
GS_DECLARE NSString* const NSISO8601Calendar = @"";

/* NSLocale New Calendar ID Keys */
GS_DECLARE NSString* const NSCalendarIdentifierGregorian = @"gregorian";
GS_DECLARE NSString* const NSCalendarIdentifierBuddhist = @"buddhist";
GS_DECLARE NSString* const NSCalendarIdentifierChinese = @"chinese";
GS_DECLARE NSString* const NSCalendarIdentifierCoptic = @"coptic";
GS_DECLARE NSString* const NSCalendarIdentifierEthiopicAmeteMihret = @"ethiopic-amete-mihret";
GS_DECLARE NSString* const NSCalendarIdentifierEthiopicAmeteAlem = @"ethiopic-amete-alem";
GS_DECLARE NSString* const NSCalendarIdentifierHebrew = @"hebrew";
GS_DECLARE NSString* const NSCalendarIdentifierISO8601 = @"";
GS_DECLARE NSString* const NSCalendarIdentifierIndian = @"indian";
GS_DECLARE NSString* const NSCalendarIdentifierIslamic = @"islamic";
GS_DECLARE NSString* const NSCalendarIdentifierIslamicCivil = @"islamic-civil";
GS_DECLARE NSString* const NSCalendarIdentifierJapanese = @"japanese";
GS_DECLARE NSString* const NSCalendarIdentifierPersian = @"persian";
GS_DECLARE NSString* const NSCalendarIdentifierRepublicOfChina = @"roc";
GS_DECLARE NSString* const NSCalendarIdentifierIslamicTabular = @"islamic-tabular";
GS_DECLARE NSString* const NSCalendarIdentifierIslamicUmmAlQura = @"islamic-umm-al-qura";

/* NSMetadata */
GS_DECLARE NSString* const NSMetadataQueryUserHomeScope = @"NSMetadataQueryUserHomeScope";
GS_DECLARE NSString* const NSMetadataQueryLocalComputerScope = @"NSMetadataQueryLocalComputerScope";
GS_DECLARE NSString* const NSMetadataQueryNetworkScope = @"NSMetadataQueryNetworkScope";
GS_DECLARE NSString* const NSMetadataQueryUbiquitousDocumentsScope = @"NSMetadataQueryUbiquitousDocumentsScope";
GS_DECLARE NSString* const NSMetadataQueryUbiquitousDataScope = @"NSMetadataQueryUbiquitousDataScope";
GS_DECLARE NSString* const NSMetadataQueryDidFinishGatheringNotification = @"NSMetadataQueryDidFinishGatheringNotification";
GS_DECLARE NSString* const NSMetadataQueryDidStartGatheringNotification = @"NSMetadataQueryDidStartGatheringNotification";
GS_DECLARE NSString* const NSMetadataQueryDidUpdateNotification = @"NSMetadataQueryDidUpdateNotification";
GS_DECLARE NSString* const NSMetadataQueryGatheringProgressNotification = @"NSMetadataQueryGatheringProgressNotification";

/* NSNetServices */
GS_DECLARE NSString* const NSNetServicesErrorCode = @"NSNetServicesErrorCode";
GS_DECLARE NSString* const NSNetServicesErrorDomain = @"NSNetServicesErrorDomain";

/* NSPersonNameComponentsFormatter */
GS_DECLARE NSString* const NSPersonNameComponentKey = @"NSPersonNameComponentKey";
GS_DECLARE NSString* const NSPersonNameComponentGivenName = @"NSPersonNameComponentGivenName";
GS_DECLARE NSString* const NSPersonNameComponentFamilyName = @"NSPersonNameComponentFamilyName";
GS_DECLARE NSString* const NSPersonNameComponentMiddleName = @"NSPersonNameComponentMiddleName";
GS_DECLARE NSString* const NSPersonNameComponentPrefix = @"NSPersonNameComponentPrefix";
GS_DECLARE NSString* const NSPersonNameComponentSuffix = @"NSPersonNameComponentSuffix";
GS_DECLARE NSString* const NSPersonNameComponentNickname = @"NSPersonNameComponentNickname";
GS_DECLARE NSString* const NSPersonNameComponentDelimiter = @"NSPersonNameComponentDelimiter";

/* NSPort */
GS_DECLARE NSString* const NSInvalidReceivePortException = @"NSInvalidReceivePortException";
GS_DECLARE NSString* const NSInvalidSendPortException = @"NSInvalidSendPortException";
GS_DECLARE NSString* const NSPortReceiveException = @"NSPortReceiveException";
GS_DECLARE NSString* const NSPortSendException = @"NSPortSendException";
GS_DECLARE NSString* const NSPortTimeoutException = @"NSPortTimeoutException";

/* NSSpellServer */
GS_DECLARE NSString* const NSGrammarRange = @"NSGrammarRange";
GS_DECLARE NSString* const NSGrammarUserDescription = @"NSGrammarUserDescription";
GS_DECLARE NSString* const NSGrammarCorrections = @"NSGrammarCorrections";

/* NSTimeZone */
GS_DECLARE NSString* const NSSystemTimeZoneDidChangeNotification = @"NSSystemTimeZoneDidChangeNotification";

/* NSURLCredentialStorage */
GS_DECLARE NSString* const NSURLCredentialStorageChangedNotification = @"NSURLCredentialStorageChangedNotification";

/* NSURLHandle */
GS_DECLARE NSString* const NSHTTPPropertyStatusCodeKey = @"NSHTTPPropertyStatusCodeKey";
GS_DECLARE NSString* const NSHTTPPropertyStatusReasonKey = @"NSHTTPPropertyStatusReasonKey";
GS_DECLARE NSString* const NSHTTPPropertyServerHTTPVersionKey = @"NSHTTPPropertyServerHTTPVersionKey";
GS_DECLARE NSString* const NSHTTPPropertyRedirectionHeadersKey = @"NSHTTPPropertyRedirectionHeadersKey";
GS_DECLARE NSString* const NSHTTPPropertyErrorPageDataKey = @"NSHTTPPropertyErrorPageDataKey";

/* NSURLHandle GNUstep extras */
GS_DECLARE NSString* const GSHTTPPropertyMethodKey = @"GSHTTPPropertyMethodKey";
GS_DECLARE NSString* const GSHTTPPropertyLocalHostKey = @"GSHTTPPropertyLocalHostKey";
GS_DECLARE NSString* const GSHTTPPropertyProxyHostKey = @"GSHTTPPropertyProxyHostKey";
GS_DECLARE NSString* const GSHTTPPropertyProxyPortKey = @"GSHTTPPropertyProxyPortKey";
GS_DECLARE NSString* const GSHTTPPropertyCertificateFileKey = @"GSHTTPPropertyCertificateFileKey";
GS_DECLARE NSString* const GSHTTPPropertyKeyFileKey = @"GSHTTPPropertyKeyFileKey";
GS_DECLARE NSString* const GSHTTPPropertyPasswordKey = @"GSHTTPPropertyPasswordKey";

/* NSURLProtectionSpace */
GS_DECLARE NSString* const NSURLProtectionSpaceFTPProxy = @"ftp";	
GS_DECLARE NSString* const NSURLProtectionSpaceHTTPProxy = @"http";
GS_DECLARE NSString* const NSURLProtectionSpaceHTTPSProxy = @"https";
GS_DECLARE NSString* const NSURLProtectionSpaceSOCKSProxy = @"SOCKS";
GS_DECLARE NSString* const NSURLAuthenticationMethodDefault = @"NSURLAuthenticationMethodDefault";
GS_DECLARE NSString* const NSURLAuthenticationMethodHTMLForm = @"NSURLAuthenticationMethodHTMLForm";
GS_DECLARE NSString* const NSURLAuthenticationMethodHTTPBasic = @"NSURLAuthenticationMethodHTTPBasic";
GS_DECLARE NSString* const NSURLAuthenticationMethodHTTPDigest = @"NSURLAuthenticationMethodHTTPDigest";
GS_DECLARE NSString* const NSURLAuthenticationMethodNTLM = @"NSURLAuthenticationMethodNTLM";
GS_DECLARE NSString* const NSURLAuthenticationMethodNegotiate  = @"NSURLAuthenticationMethodNegotiate";
GS_DECLARE NSString* const NSURLAuthenticationMethodClientCertificate = @"NSURLAuthenticationMethodClientCertificate";
GS_DECLARE NSString* const NSURLAuthenticationMethodServerTrust = @"NSURLAuthenticationMethodServerTrust";

/* NSUserNotification */
GS_DECLARE NSString* const NSUserNotificationDefaultSoundName = @"NSUserNotificationDefaultSoundName";

/* NSStream+GNUstepBase */
GS_DECLARE NSString* const GSStreamLocalAddressKey = @"GSStreamLocalAddressKey";
GS_DECLARE NSString* const GSStreamLocalPortKey = @"GSStreamLocalPortKey";
GS_DECLARE NSString* const GSStreamRemoteAddressKey = @"GSStreamRemoteAddressKey";
GS_DECLARE NSString* const GSStreamRemotePortKey = @"GSStreamRemotePortKey";

/* NSError */
GS_DECLARE NSString* const NSFilePathErrorKey = @"NSFilePath";
GS_DECLARE NSString* const NSLocalizedDescriptionKey = @"NSLocalizedDescriptionKey";
GS_DECLARE NSString* const NSStringEncodingErrorKey = @"NSStringEncodingErrorKey";
GS_DECLARE NSString* const NSURLErrorKey = @"NSURLErrorKey";
GS_DECLARE NSString* const NSUnderlyingErrorKey = @"NSUnderlyingErrorKey";

GS_DECLARE NSString* const NSLocalizedFailureReasonErrorKey = @"NSLocalizedFailureReasonErrorKey";
GS_DECLARE NSString* const NSLocalizedRecoveryOptionsErrorKey = @"NSLocalizedRecoveryOptionsErrorKey";
GS_DECLARE NSString* const NSLocalizedRecoverySuggestionErrorKey = @"NSLocalizedRecoverySuggestionErrorKey";
GS_DECLARE NSString* const NSRecoveryAttempterErrorKey = @"NSRecoveryAttempterErrorKey";

GS_DECLARE NSString* const NSURLErrorFailingURLErrorKey = @"NSErrorFailingURLKey";
GS_DECLARE NSString* const NSURLErrorFailingURLStringErrorKey = @"NSErrorFailingURLStringKey";

GS_DECLARE NSErrorDomain const NSMACHErrorDomain = @"NSMACHErrorDomain";
GS_DECLARE NSErrorDomain const NSOSStatusErrorDomain = @"NSOSStatusErrorDomain";
GS_DECLARE NSErrorDomain const NSPOSIXErrorDomain = @"NSPOSIXErrorDomain";
GS_DECLARE NSErrorDomain const NSCocoaErrorDomain = @"NSCocoaErrorDomain";

/* NSExtensionContext */
GS_DECLARE NSString* const NSExtensionItemsAndErrorsKey = @"NSExtensionItemsAndErrorsKey";
GS_DECLARE NSString* const NSExtensionHostWillEnterForegroundNotification = @"NSExtensionHostWillEnterForegroundNotification";
GS_DECLARE NSString* const NSExtensionHostDidEnterBackgroundNotification = @"NSExtensionHostDidEnterBackgroundNotification";
GS_DECLARE NSString* const NSExtensionHostWillResignActiveNotification = @"NSExtensionHostWillResignActiveNotification";
GS_DECLARE NSString* const NSExtensionHostDidBecomeActiveNotification = @"NSExtensionHostDidBecomeActiveNotification";

/* NSInvocationOperation */
GS_DECLARE NSString* const NSInvocationOperationVoidResultException = @"NSInvocationOperationVoidResultException";
GS_DECLARE NSString* const NSInvocationOperationCancelledException = @"NSInvcationOperationCancelledException";

/* NSXMLParser */
GS_DECLARE NSString* const NSXMLParserErrorDomain = @"NSXMLParserErrorDomain";



/* For bug in gcc 3.1. See NSByteOrder.h */
void _gcc3_1_hack(void){}
