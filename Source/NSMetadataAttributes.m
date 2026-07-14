/* Implementation of class NSMetadataAttributes
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: heron
   Date: Tue Oct 29 00:53:11 EDT 2019

   This file is part of the GNUstep Library.
   
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

#import "Foundation/NSMetadataAttributes.h"
#import "Foundation/NSString.h"

GS_DECLARE NSString *const NSMetadataItemAcquisitionMakeKey = @"NSMetadataItemAcquisitionMakeKey";
GS_DECLARE NSString *const NSMetadataItemAcquisitionModelKey = @"NSMetadataItemAcquisitionModelKey";
GS_DECLARE NSString *const NSMetadataItemAlbumKey = @"NSMetadataItemAlbumKey";
GS_DECLARE NSString *const NSMetadataItemAltitudeKey = @"NSMetadataItemAltitudeKey";
GS_DECLARE NSString *const NSMetadataItemApertureKey = @"NSMetadataItemApertureKey";
GS_DECLARE NSString *const NSMetadataItemAppleLoopDescriptorsKey = @"NSMetadataItemAppleLoopDescriptorsKey";
GS_DECLARE NSString *const NSMetadataItemAppleLoopsKeyFilterTypeKey = @"NSMetadataItemAppleLoopsKeyFilterTypeKey";
GS_DECLARE NSString *const NSMetadataItemAppleLoopsLoopModeKey = @"NSMetadataItemAppleLoopsLoopModeKey";
GS_DECLARE NSString *const NSMetadataItemAppleLoopsRootKeyKey = @"NSMetadataItemAppleLoopsRootKeyKey";
GS_DECLARE NSString *const NSMetadataItemApplicationCategoriesKey = @"NSMetadataItemApplicationCategoriesKey";
GS_DECLARE NSString *const NSMetadataItemAttributeChangeDateKey = @"NSMetadataItemAttributeChangeDateKey";
GS_DECLARE NSString *const NSMetadataItemAudiencesKey = @"NSMetadataItemAudiencesKey";
GS_DECLARE NSString *const NSMetadataItemAudioBitRateKey = @"NSMetadataItemAudioBitRateKey";
GS_DECLARE NSString *const NSMetadataItemAudioChannelCountKey = @"NSMetadataItemAudioChannelCountKey";
GS_DECLARE NSString *const NSMetadataItemAudioEncodingApplicationKey = @"NSMetadataItemAudioEncodingApplicationKey";
GS_DECLARE NSString *const NSMetadataItemAudioSampleRateKey = @"NSMetadataItemAudioSampleRateKey";
GS_DECLARE NSString *const NSMetadataItemAudioTrackNumberKey = @"NSMetadataItemAudioTrackNumberKey";
GS_DECLARE NSString *const NSMetadataItemAuthorAddressesKey = @"NSMetadataItemAuthorAddressesKey";
GS_DECLARE NSString *const NSMetadataItemAuthorEmailAddressesKey = @"NSMetadataItemAuthorEmailAddressesKey";
GS_DECLARE NSString *const NSMetadataItemAuthorsKey = @"NSMetadataItemAuthorsKey";
GS_DECLARE NSString *const NSMetadataItemBitsPerSampleKey = @"NSMetadataItemBitsPerSampleKey";
GS_DECLARE NSString *const NSMetadataItemCameraOwnerKey = @"NSMetadataItemCameraOwnerKey";
GS_DECLARE NSString *const NSMetadataItemCFBundleIdentifierKey = @"NSMetadataItemCFBundleIdentifierKey";
GS_DECLARE NSString *const NSMetadataItemCityKey = @"NSMetadataItemCityKey";
GS_DECLARE NSString *const NSMetadataItemCodecsKey = @"NSMetadataItemCodecsKey";
GS_DECLARE NSString *const NSMetadataItemColorSpaceKey = @"NSMetadataItemColorSpaceKey";
GS_DECLARE NSString *const NSMetadataItemCommentKey = @"NSMetadataItemCommentKey";
GS_DECLARE NSString *const NSMetadataItemComposerKey = @"NSMetadataItemComposerKey";
GS_DECLARE NSString *const NSMetadataItemContactKeywordsKey = @"NSMetadataItemContactKeywordsKey";
GS_DECLARE NSString *const NSMetadataItemContentCreationDateKey = @"NSMetadataItemContentCreationDateKey";
GS_DECLARE NSString *const NSMetadataItemContentModificationDateKey = @"NSMetadataItemContentModificationDateKey";
GS_DECLARE NSString *const NSMetadataItemContentTypeKey = @"NSMetadataItemContentTypeKey";
GS_DECLARE NSString *const NSMetadataItemContentTypeTreeKey = @"NSMetadataItemContentTypeTreeKey";
GS_DECLARE NSString *const NSMetadataItemContributorsKey = @"NSMetadataItemContributorsKey";
GS_DECLARE NSString *const NSMetadataItemCopyrightKey = @"NSMetadataItemCopyrightKey";
GS_DECLARE NSString *const NSMetadataItemCountryKey = @"NSMetadataItemCountryKey";
GS_DECLARE NSString *const NSMetadataItemCoverageKey = @"NSMetadataItemCoverageKey";
GS_DECLARE NSString *const NSMetadataItemCreatorKey = @"NSMetadataItemCreatorKey";
GS_DECLARE NSString *const NSMetadataItemDateAddedKey = @"NSMetadataItemDateAddedKey";
GS_DECLARE NSString *const NSMetadataItemDeliveryTypeKey = @"NSMetadataItemDeliveryTypeKey";
GS_DECLARE NSString *const NSMetadataItemDescriptionKey = @"NSMetadataItemDescriptionKey";
GS_DECLARE NSString *const NSMetadataItemDirectorKey = @"NSMetadataItemDirectorKey";
GS_DECLARE NSString *const NSMetadataItemDisplayNameKey = @"NSMetadataItemDisplayNameKey";
GS_DECLARE NSString *const NSMetadataItemDownloadedDateKey = @"NSMetadataItemDownloadedDateKey";
GS_DECLARE NSString *const NSMetadataItemDueDateKey = @"NSMetadataItemDueDateKey";
GS_DECLARE NSString *const NSMetadataItemDurationSecondsKey = @"NSMetadataItemDurationSecondsKey";
GS_DECLARE NSString *const NSMetadataItemEditorsKey = @"NSMetadataItemEditorsKey";
GS_DECLARE NSString *const NSMetadataItemEmailAddressesKey = @"NSMetadataItemEmailAddressesKey";
GS_DECLARE NSString *const NSMetadataItemEncodingApplicationsKey = @"NSMetadataItemEncodingApplicationsKey";
GS_DECLARE NSString *const NSMetadataItemExecutableArchitecturesKey = @"NSMetadataItemExecutableArchitecturesKey";
GS_DECLARE NSString *const NSMetadataItemExecutablePlatformKey = @"NSMetadataItemExecutablePlatformKey";
GS_DECLARE NSString *const NSMetadataItemEXIFGPSVersionKey = @"NSMetadataItemEXIFGPSVersionKey";
GS_DECLARE NSString *const NSMetadataItemEXIFVersionKey = @"NSMetadataItemEXIFVersionKey";
GS_DECLARE NSString *const NSMetadataItemExposureModeKey = @"NSMetadataItemExposureModeKey";
GS_DECLARE NSString *const NSMetadataItemExposureProgramKey = @"NSMetadataItemExposureProgramKey";
GS_DECLARE NSString *const NSMetadataItemExposureTimeSecondsKey = @"NSMetadataItemExposureTimeSecondsKey";
GS_DECLARE NSString *const NSMetadataItemExposureTimeStringKey = @"NSMetadataItemExposureTimeStringKey";
GS_DECLARE NSString *const NSMetadataItemFinderCommentKey = @"NSMetadataItemFinderCommentKey";
GS_DECLARE NSString *const NSMetadataItemFlashOnOffKey = @"NSMetadataItemFlashOnOffKey";
GS_DECLARE NSString *const NSMetadataItemFNumberKey = @"NSMetadataItemFNumberKey";
GS_DECLARE NSString *const NSMetadataItemFocalLength35mmKey = @"NSMetadataItemFocalLength35mmKey";
GS_DECLARE NSString *const NSMetadataItemFocalLengthKey = @"NSMetadataItemFocalLengthKey";
GS_DECLARE NSString *const NSMetadataItemFontsKey = @"NSMetadataItemFontsKey";
GS_DECLARE NSString *const NSMetadataItemFSContentChangeDateKey = @"NSMetadataItemFSContentChangeDateKey";
GS_DECLARE NSString *const NSMetadataItemFSCreationDateKey = @"NSMetadataItemFSCreationDateKey";
GS_DECLARE NSString *const NSMetadataItemFSNameKey = @"NSMetadataItemFSNameKey";
GS_DECLARE NSString *const NSMetadataItemFSSizeKey = @"NSMetadataItemFSSizeKey";
GS_DECLARE NSString *const NSMetadataItemGenreKey = @"NSMetadataItemGenreKey";
GS_DECLARE NSString *const NSMetadataItemGPSAreaInformationKey = @"NSMetadataItemGPSAreaInformationKey";
GS_DECLARE NSString *const NSMetadataItemGPSDateStampKey = @"NSMetadataItemGPSDateStampKey";
GS_DECLARE NSString *const NSMetadataItemGPSDestBearingKey = @"NSMetadataItemGPSDestBearingKey";
GS_DECLARE NSString *const NSMetadataItemGPSDestDistanceKey = @"NSMetadataItemGPSDestDistanceKey";
GS_DECLARE NSString *const NSMetadataItemGPSDestLatitudeKey = @"NSMetadataItemGPSDestLatitudeKey";
GS_DECLARE NSString *const NSMetadataItemGPSDestLongitudeKey = @"NSMetadataItemGPSDestLongitudeKey";
GS_DECLARE NSString *const NSMetadataItemGPSDifferentalKey = @"NSMetadataItemGPSDifferentalKey";
GS_DECLARE NSString *const NSMetadataItemGPSDOPKey = @"NSMetadataItemGPSDOPKey";
GS_DECLARE NSString *const NSMetadataItemGPSMapDatumKey = @"NSMetadataItemGPSMapDatumKey";
GS_DECLARE NSString *const NSMetadataItemGPSMeasureModeKey = @"NSMetadataItemGPSMeasureModeKey";
GS_DECLARE NSString *const NSMetadataItemGPSProcessingMethodKey = @"NSMetadataItemGPSProcessingMethodKey";
GS_DECLARE NSString *const NSMetadataItemGPSStatusKey = @"NSMetadataItemGPSStatusKey";
GS_DECLARE NSString *const NSMetadataItemGPSTrackKey = @"NSMetadataItemGPSTrackKey";
GS_DECLARE NSString *const NSMetadataItemHasAlphaChannelKey = @"NSMetadataItemHasAlphaChannelKey";
GS_DECLARE NSString *const NSMetadataItemHeadlineKey = @"NSMetadataItemHeadlineKey";
GS_DECLARE NSString *const NSMetadataItemIdentifierKey = @"NSMetadataItemIdentifierKey";
GS_DECLARE NSString *const NSMetadataItemImageDirectionKey = @"NSMetadataItemImageDirectionKey";
GS_DECLARE NSString *const NSMetadataItemInformationKey = @"NSMetadataItemInformationKey";
GS_DECLARE NSString *const NSMetadataItemInstantMessageAddressesKey = @"NSMetadataItemInstantMessageAddressesKey";
GS_DECLARE NSString *const NSMetadataItemInstructionsKey = @"NSMetadataItemInstructionsKey";
GS_DECLARE NSString *const NSMetadataItemIsApplicationManagedKey = @"NSMetadataItemIsApplicationManagedKey";
GS_DECLARE NSString *const NSMetadataItemIsGeneralMIDISequenceKey = @"NSMetadataItemIsGeneralMIDISequenceKey";
GS_DECLARE NSString *const NSMetadataItemIsLikelyJunkKey = @"NSMetadataItemIsLikelyJunkKey";
GS_DECLARE NSString *const NSMetadataItemISOSpeedKey = @"NSMetadataItemISOSpeedKey";
GS_DECLARE NSString *const NSMetadataItemIsUbiquitousKey = @"NSMetadataItemIsUbiquitousKey";
GS_DECLARE NSString *const NSMetadataItemKeySignatureKey = @"NSMetadataItemKeySignatureKey";
GS_DECLARE NSString *const NSMetadataItemKeywordsKey = @"NSMetadataItemKeywordsKey";
GS_DECLARE NSString *const NSMetadataItemKindKey = @"NSMetadataItemKindKey";
GS_DECLARE NSString *const NSMetadataItemLanguagesKey = @"NSMetadataItemLanguagesKey";
GS_DECLARE NSString *const NSMetadataItemLastUsedDateKey = @"NSMetadataItemLastUsedDateKey";
GS_DECLARE NSString *const NSMetadataItemLatitudeKey = @"NSMetadataItemLatitudeKey";
GS_DECLARE NSString *const NSMetadataItemLayerNamesKey = @"NSMetadataItemLayerNamesKey";
GS_DECLARE NSString *const NSMetadataItemLensModelKey = @"NSMetadataItemLensModelKey";
GS_DECLARE NSString *const NSMetadataItemLongitudeKey = @"NSMetadataItemLongitudeKey";
GS_DECLARE NSString *const NSMetadataItemLyricistKey = @"NSMetadataItemLyricistKey";
GS_DECLARE NSString *const NSMetadataItemMaxApertureKey = @"NSMetadataItemMaxApertureKey";
GS_DECLARE NSString *const NSMetadataItemMediaTypesKey = @"NSMetadataItemMediaTypesKey";
GS_DECLARE NSString *const NSMetadataItemMeteringModeKey = @"NSMetadataItemMeteringModeKey";
GS_DECLARE NSString *const NSMetadataItemMusicalGenreKey = @"NSMetadataItemMusicalGenreKey";
GS_DECLARE NSString *const NSMetadataItemMusicalInstrumentCategoryKey = @"NSMetadataItemMusicalInstrumentCategoryKey";
GS_DECLARE NSString *const NSMetadataItemMusicalInstrumentNameKey = @"NSMetadataItemMusicalInstrumentNameKey";
GS_DECLARE NSString *const NSMetadataItemNamedLocationKey = @"NSMetadataItemNamedLocationKey";
GS_DECLARE NSString *const NSMetadataItemNumberOfPagesKey = @"NSMetadataItemNumberOfPagesKey";
GS_DECLARE NSString *const NSMetadataItemOrganizationsKey = @"NSMetadataItemOrganizationsKey";
GS_DECLARE NSString *const NSMetadataItemOrientationKey = @"NSMetadataItemOrientationKey";
GS_DECLARE NSString *const NSMetadataItemOriginalFormatKey = @"NSMetadataItemOriginalFormatKey";
GS_DECLARE NSString *const NSMetadataItemOriginalSourceKey = @"NSMetadataItemOriginalSourceKey";
GS_DECLARE NSString *const NSMetadataItemPageHeightKey = @"NSMetadataItemPageHeightKey";
GS_DECLARE NSString *const NSMetadataItemPageWidthKey = @"NSMetadataItemPageWidthKey";
GS_DECLARE NSString *const NSMetadataItemParticipantsKey = @"NSMetadataItemParticipantsKey";
GS_DECLARE NSString *const NSMetadataItemPathKey = @"NSMetadataItemPathKey";
GS_DECLARE NSString *const NSMetadataItemPerformersKey = @"NSMetadataItemPerformersKey";
GS_DECLARE NSString *const NSMetadataItemPhoneNumbersKey = @"NSMetadataItemPhoneNumbersKey";
GS_DECLARE NSString *const NSMetadataItemPixelCountKey = @"NSMetadataItemPixelCountKey";
GS_DECLARE NSString *const NSMetadataItemPixelHeightKey = @"NSMetadataItemPixelHeightKey";
GS_DECLARE NSString *const NSMetadataItemPixelWidthKey = @"NSMetadataItemPixelWidthKey";
GS_DECLARE NSString *const NSMetadataItemProducerKey = @"NSMetadataItemProducerKey";
GS_DECLARE NSString *const NSMetadataItemProfileNameKey = @"NSMetadataItemProfileNameKey";
GS_DECLARE NSString *const NSMetadataItemProjectsKey = @"NSMetadataItemProjectsKey";
GS_DECLARE NSString *const NSMetadataItemPublishersKey = @"NSMetadataItemPublishersKey";
GS_DECLARE NSString *const NSMetadataItemRecipientAddressesKey = @"NSMetadataItemRecipientAddressesKey";
GS_DECLARE NSString *const NSMetadataItemRecipientEmailAddressesKey = @"NSMetadataItemRecipientEmailAddressesKey";
GS_DECLARE NSString *const NSMetadataItemRecipientsKey = @"NSMetadataItemRecipientsKey";
GS_DECLARE NSString *const NSMetadataItemRecordingDateKey = @"NSMetadataItemRecordingDateKey";
GS_DECLARE NSString *const NSMetadataItemRecordingYearKey = @"NSMetadataItemRecordingYearKey";
GS_DECLARE NSString *const NSMetadataItemRedEyeOnOffKey = @"NSMetadataItemRedEyeOnOffKey";
GS_DECLARE NSString *const NSMetadataItemResolutionHeightDPIKey = @"NSMetadataItemResolutionHeightDPIKey";
GS_DECLARE NSString *const NSMetadataItemResolutionWidthDPIKey = @"NSMetadataItemResolutionWidthDPIKey";
GS_DECLARE NSString *const NSMetadataItemRightsKey = @"NSMetadataItemRightsKey";
GS_DECLARE NSString *const NSMetadataItemSecurityMethodKey = @"NSMetadataItemSecurityMethodKey";
GS_DECLARE NSString *const NSMetadataItemSpeedKey = @"NSMetadataItemSpeedKey";
GS_DECLARE NSString *const NSMetadataItemStarRatingKey = @"NSMetadataItemStarRatingKey";
GS_DECLARE NSString *const NSMetadataItemStateOrProvinceKey = @"NSMetadataItemStateOrProvinceKey";
GS_DECLARE NSString *const NSMetadataItemStreamableKey = @"NSMetadataItemStreamableKey";
GS_DECLARE NSString *const NSMetadataItemSubjectKey = @"NSMetadataItemSubjectKey";
GS_DECLARE NSString *const NSMetadataItemTempoKey = @"NSMetadataItemTempoKey";
GS_DECLARE NSString *const NSMetadataItemTextContentKey = @"NSMetadataItemTextContentKey";
GS_DECLARE NSString *const NSMetadataItemThemeKey = @"NSMetadataItemThemeKey";
GS_DECLARE NSString *const NSMetadataItemTimeSignatureKey = @"NSMetadataItemTimeSignatureKey";
GS_DECLARE NSString *const NSMetadataItemTimestampKey = @"NSMetadataItemTimestampKey";
GS_DECLARE NSString *const NSMetadataItemTitleKey = @"NSMetadataItemTitleKey";
GS_DECLARE NSString *const NSMetadataItemTotalBitRateKey = @"NSMetadataItemTotalBitRateKey";
GS_DECLARE NSString *const NSMetadataItemURLKey = @"NSMetadataItemURLKey";
GS_DECLARE NSString *const NSMetadataItemVersionKey = @"NSMetadataItemVersionKey";
GS_DECLARE NSString *const NSMetadataItemVideoBitRateKey = @"NSMetadataItemVideoBitRateKey";
GS_DECLARE NSString *const NSMetadataItemWhereFromsKey = @"NSMetadataItemWhereFromsKey";
GS_DECLARE NSString *const NSMetadataItemWhiteBalanceKey = @"NSMetadataItemWhiteBalanceKey";
GS_DECLARE NSString *const NSMetadataUbiquitousItemContainerDisplayNameKey = @"NSMetadataUbiquitousItemContainerDisplayNameKey";
GS_DECLARE NSString *const NSMetadataUbiquitousItemDownloadingErrorKey = @"NSMetadataUbiquitousItemDownloadingErrorKey";
GS_DECLARE NSString *const NSMetadataUbiquitousItemDownloadingStatusCurrent = @"NSMetadataUbiquitousItemDownloadingStatusCurrent";
GS_DECLARE NSString *const NSMetadataUbiquitousItemDownloadingStatusDownloaded = @"NSMetadataUbiquitousItemDownloadingStatusDownloaded";
GS_DECLARE NSString *const NSMetadataUbiquitousItemDownloadingStatusKey = @"NSMetadataUbiquitousItemDownloadingStatusKey";
GS_DECLARE NSString *const NSMetadataUbiquitousItemDownloadingStatusNotDownloaded = @"NSMetadataUbiquitousItemDownloadingStatusNotDownloaded";
GS_DECLARE NSString *const NSMetadataUbiquitousItemDownloadRequestedKey = @"NSMetadataUbiquitousItemDownloadRequestedKey";
GS_DECLARE NSString *const NSMetadataUbiquitousItemHasUnresolvedConflictsKey = @"NSMetadataUbiquitousItemHasUnresolvedConflictsKey";
GS_DECLARE NSString *const NSMetadataUbiquitousItemIsDownloadedKey = @"NSMetadataUbiquitousItemIsDownloadedKey";
GS_DECLARE NSString *const NSMetadataUbiquitousItemIsDownloadingKey = @"NSMetadataUbiquitousItemIsDownloadingKey";
GS_DECLARE NSString *const NSMetadataUbiquitousItemIsExternalDocumentKey = @"NSMetadataUbiquitousItemIsExternalDocumentKey";
GS_DECLARE NSString *const NSMetadataUbiquitousItemIsSharedKey = @"NSMetadataUbiquitousItemIsSharedKey";
GS_DECLARE NSString *const NSMetadataUbiquitousItemIsUploadedKey = @"NSMetadataUbiquitousItemIsUploadedKey";
GS_DECLARE NSString *const NSMetadataUbiquitousItemIsUploadingKey = @"NSMetadataUbiquitousItemIsUploadingKey";
GS_DECLARE NSString *const NSMetadataUbiquitousItemPercentDownloadedKey = @"NSMetadataUbiquitousItemPercentDownloadedKey";
GS_DECLARE NSString *const NSMetadataUbiquitousItemPercentUploadedKey = @"NSMetadataUbiquitousItemPercentUploadedKey";
GS_DECLARE NSString *const NSMetadataUbiquitousItemUploadingErrorKey = @"NSMetadataUbiquitousItemUploadingErrorKey";
GS_DECLARE NSString *const NSMetadataUbiquitousItemURLInLocalContainerKey = @"NSMetadataUbiquitousItemURLInLocalContainerKey";
GS_DECLARE NSString *const NSMetadataUbiquitousSharedItemCurrentUserPermissionsKey = @"NSMetadataUbiquitousSharedItemCurrentUserPermissionsKey";
GS_DECLARE NSString *const NSMetadataUbiquitousSharedItemCurrentUserRoleKey = @"NSMetadataUbiquitousSharedItemCurrentUserRoleKey";
GS_DECLARE NSString *const NSMetadataUbiquitousSharedItemMostRecentEditorNameComponentsKey = @"NSMetadataUbiquitousSharedItemMostRecentEditorNameComponentsKey";
GS_DECLARE NSString *const NSMetadataUbiquitousSharedItemOwnerNameComponentsKey = @"NSMetadataUbiquitousSharedItemOwnerNameComponentsKey";
GS_DECLARE NSString *const NSMetadataUbiquitousSharedItemPermissionsReadOnly = @"NSMetadataUbiquitousSharedItemPermissionsReadOnly";
GS_DECLARE NSString *const NSMetadataUbiquitousSharedItemPermissionsReadWrite = @"NSMetadataUbiquitousSharedItemPermissionsReadWrite";
GS_DECLARE NSString *const NSMetadataUbiquitousSharedItemRoleOwner = @"NSMetadataUbiquitousSharedItemRoleOwner";
GS_DECLARE NSString *const NSMetadataUbiquitousSharedItemRoleParticipant = @"NSMetadataUbiquitousSharedItemRoleParticipant";
