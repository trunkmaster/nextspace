/*
   externs.m

   External data

   Copyright (C) 1997-2017 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: August 1997

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/

#import "config.h"
#import <Foundation/NSString.h>
#import <Foundation/NSObjCRuntime.h>

#import "AppKit/NSApplication.h"
#import "AppKit/NSEvent.h"
#import "AppKit/NSAppearance.h"
#import "AppKit/NSFontCollection.h"
#import "AppKit/NSTextFinder.h"
#import "AppKit/NSCollectionView.h"

// Global strings
APPKIT_DECLARE APPKIT_DECLARE NSString *NSModalPanelRunLoopMode = @"NSModalPanelRunLoopMode";
APPKIT_DECLARE APPKIT_DECLARE NSString *NSEventTrackingRunLoopMode = @"NSEventTrackingRunLoopMode";

APPKIT_DECLARE const double NSAppKitVersionNumber = NSAppKitVersionNumber10_4;

//
// Global Exception Strings
//
APPKIT_DECLARE NSExceptionName NSAbortModalException = @"NSAbortModalException";
APPKIT_DECLARE NSExceptionName NSAbortPrintingException = @"NSAbortPrintingException";
APPKIT_DECLARE NSExceptionName NSAppKitIgnoredException = @"NSAppKitIgnoredException";
APPKIT_DECLARE NSExceptionName NSAppKitVirtualMemoryException = @"NSAppKitVirtualMemoryException";
APPKIT_DECLARE NSExceptionName NSBadBitmapParametersException = @"NSBadBitmapParametersException";
APPKIT_DECLARE NSExceptionName NSBadComparisonException = @"NSBadComparisonException";
APPKIT_DECLARE NSExceptionName NSBadRTFColorTableException = @"NSBadRTFColorTableException";
APPKIT_DECLARE NSExceptionName NSBadRTFDirectiveException = @"NSBadRTFDirectiveException";
APPKIT_DECLARE NSExceptionName NSBadRTFFontTableException = @"NSBadRTFFontTableException";
APPKIT_DECLARE NSExceptionName NSBadRTFStyleSheetException = @"NSBadRTFStyleSheetException";
APPKIT_DECLARE NSExceptionName NSBrowserIllegalDelegateException = @"NSBrowserIllegalDelegateException";
APPKIT_DECLARE NSExceptionName NSColorListIOException = @"NSColorListIOException";
APPKIT_DECLARE NSExceptionName NSColorListNotEditableException = @"NSColorListNotEditableException";
APPKIT_DECLARE NSExceptionName NSDraggingException = @"NSDraggingException";
APPKIT_DECLARE NSExceptionName NSFontUnavailableException = @"NSFontUnavailableException";
APPKIT_DECLARE NSExceptionName NSIllegalSelectorException = @"NSIllegalSelectorException";
APPKIT_DECLARE NSExceptionName NSImageCacheException = @"NSImageCacheException";
APPKIT_DECLARE NSExceptionName NSNibLoadingException = @"NSNibLoadingException";
APPKIT_DECLARE NSExceptionName NSPPDIncludeNotFoundException = @"NSPPDIncludeNotFoundException";
APPKIT_DECLARE NSExceptionName NSPPDIncludeStackOverflowException = @"NSPPDIncludeStackOverflowException";
APPKIT_DECLARE NSExceptionName NSPPDIncludeStackUnderflowException = @"NSPPDIncludeStackUnderflowException";
APPKIT_DECLARE NSExceptionName NSPPDParseException = @"NSPPDParseException";
APPKIT_DECLARE NSExceptionName NSPrintOperationExistsException = @"NSPrintOperationExistsException";
APPKIT_DECLARE NSExceptionName NSPrintPackageException = @"NSPrintPackageException";
APPKIT_DECLARE NSExceptionName NSPrintingCommunicationException = @"NSPrintingCommunicationException";
APPKIT_DECLARE NSExceptionName NSRTFPropertyStackOverflowException = @"NSRTFPropertyStackOverflowException";
APPKIT_DECLARE NSExceptionName NSTIFFException = @"NSTIFFException";
APPKIT_DECLARE NSExceptionName NSTextLineTooLongException = @"NSTextLineTooLongException";
APPKIT_DECLARE NSExceptionName NSTextNoSelectionException = @"NSTextNoSelectionException";
APPKIT_DECLARE NSExceptionName NSTextReadException = @"NSTextReadException";
APPKIT_DECLARE NSExceptionName NSTextWriteException = @"NSTextWriteException";
APPKIT_DECLARE NSExceptionName NSTypedStreamVersionException = @"NSTypedStreamVersionException";
APPKIT_DECLARE NSExceptionName NSWindowServerCommunicationException = @"NSWindowServerCommunicationException";
APPKIT_DECLARE NSExceptionName NSWordTablesReadException = @"NSWordTablesReadException";
APPKIT_DECLARE NSExceptionName NSWordTablesWriteException = @"NSWordTablesWriteException";

APPKIT_DECLARE NSExceptionName GSWindowServerInternalException = @"WindowServerInternal";

// NSAnimation
APPKIT_DECLARE NSString *NSAnimationProgressMarkNotification = @"NSAnimationProgressMarkNotification";
APPKIT_DECLARE NSString *NSAnimationProgressMark = @"NSAnimationProgressMark";
APPKIT_DECLARE NSString *NSAnimationTriggerOrderIn = @"NSAnimationTriggerOrderIn"; 
APPKIT_DECLARE NSString *NSAnimationTriggerOrderOut = @"NSAnimationTriggerOrderOut"; 

// Application notifications
APPKIT_DECLARE NSString *NSApplicationDidBecomeActiveNotification = @"NSApplicationDidBecomeActiveNotification";
APPKIT_DECLARE NSString *NSApplicationDidChangeScreenParametersNotification = @"NSApplicationDidChangeScreenParametersNotification";
APPKIT_DECLARE NSString *NSApplicationDidFinishLaunchingNotification = @"NSApplicationDidFinishLaunchingNotification";
APPKIT_DECLARE NSString *NSApplicationDidHideNotification = @"NSApplicationDidHideNotification";
APPKIT_DECLARE NSString *NSApplicationDidResignActiveNotification = @"NSApplicationDidResignActiveNotification";
APPKIT_DECLARE NSString *NSApplicationDidUnhideNotification = @"NSApplicationDidUnhideNotification";
APPKIT_DECLARE NSString *NSApplicationDidUpdateNotification = @"NSApplicationDidUpdateNotification";
APPKIT_DECLARE NSString *NSApplicationWillBecomeActiveNotification = @"NSApplicationWillBecomeActiveNotification";
APPKIT_DECLARE NSString *NSApplicationWillFinishLaunchingNotification = @"NSApplicationWillFinishLaunchingNotification";
APPKIT_DECLARE NSString *NSApplicationWillTerminateNotification = @"NSApplicationWillTerminateNotification";
APPKIT_DECLARE NSString *NSApplicationWillHideNotification = @"NSApplicationWillHideNotification";
APPKIT_DECLARE NSString *NSApplicationWillResignActiveNotification = @"NSApplicationWillResignActiveNotification";
APPKIT_DECLARE NSString *NSApplicationWillUnhideNotification = @"NSApplicationWillUnhideNotification";
APPKIT_DECLARE NSString *NSApplicationWillUpdateNotification = @"NSApplicationWillUpdateNotification";

// NSBitmapImageRep Global strings
APPKIT_DECLARE NSString *NSImageCompressionMethod = @"NSImageCompressionMethod";
APPKIT_DECLARE NSString *NSImageCompressionFactor = @"NSImageCompressionFactor";
APPKIT_DECLARE NSString *NSImageDitherTransparency = @"NSImageDitherTransparency";
APPKIT_DECLARE NSString *NSImageRGBColorTable = @"NSImageRGBColorTable";
APPKIT_DECLARE NSString *NSImageInterlaced = @"NSImageInterlaced";
APPKIT_DECLARE NSString *NSImageColorSyncProfileData = @"NSImageColorSyncProfileData";  // Mac OS X only
//APPKIT_DECLARE NSString *GSImageICCProfileData = @"GSImageICCProfileData";  // if & when GNUstep supports color management
APPKIT_DECLARE NSString *NSImageFrameCount = @"NSImageFrameCount";
APPKIT_DECLARE NSString *NSImageCurrentFrame = @"NSImageCurrentFrame";
APPKIT_DECLARE NSString *NSImageCurrentFrameDuration = @"NSImageCurrentFrameDuration";
APPKIT_DECLARE NSString *NSImageLoopCount = @"NSImageLoopCount";
APPKIT_DECLARE NSString *NSImageGamma = @"NSImageGamma";
APPKIT_DECLARE NSString *NSImageProgressive = @"NSImageProgressive";
APPKIT_DECLARE NSString *NSImageEXIFData = @"NSImageEXIFData";  // No support yet in GNUstep

// NSBrowser notification
APPKIT_DECLARE NSString *NSBrowserColumnConfigurationDidChangeNotification = @"NSBrowserColumnConfigurationDidChange";

// NSColor Global strings
APPKIT_DECLARE NSString *NSCalibratedWhiteColorSpace = @"NSCalibratedWhiteColorSpace";
APPKIT_DECLARE NSString *NSCalibratedBlackColorSpace = @"NSCalibratedBlackColorSpace";
APPKIT_DECLARE NSString *NSCalibratedRGBColorSpace = @"NSCalibratedRGBColorSpace";
APPKIT_DECLARE NSString *NSDeviceWhiteColorSpace = @"NSDeviceWhiteColorSpace";
APPKIT_DECLARE NSString *NSDeviceBlackColorSpace = @"NSDeviceBlackColorSpace";
APPKIT_DECLARE NSString *NSDeviceRGBColorSpace = @"NSDeviceRGBColorSpace";
APPKIT_DECLARE NSString *NSDeviceCMYKColorSpace = @"NSDeviceCMYKColorSpace";
APPKIT_DECLARE NSString *NSNamedColorSpace = @"NSNamedColorSpace";
APPKIT_DECLARE NSString *NSPatternColorSpace = @"NSPatternColorSpace";
APPKIT_DECLARE NSString *NSCustomColorSpace = @"NSCustomColorSpace";

// NSColor Global gray values
APPKIT_DECLARE const CGFloat NSBlack = 0;
APPKIT_DECLARE const CGFloat NSDarkGray = .333;
APPKIT_DECLARE const CGFloat NSGray = 0.5;
APPKIT_DECLARE const CGFloat NSLightGray = .667;
APPKIT_DECLARE const CGFloat NSWhite = 1;

APPKIT_DECLARE const CGFloat NSFontWeightUltraLight = -0.8;
APPKIT_DECLARE const CGFloat NSFontWeightThin = -0.6;
APPKIT_DECLARE const CGFloat NSFontWeightLight = -0.4;
APPKIT_DECLARE const CGFloat NSFontWeightRegular = 0;
APPKIT_DECLARE const CGFloat NSFontWeightMedium = 0.23;
APPKIT_DECLARE const CGFloat NSFontWeightSemibold = 0.3;
APPKIT_DECLARE const CGFloat NSFontWeightBold = 0.4;
APPKIT_DECLARE const CGFloat NSFontWeightHeavy = 0.56;
APPKIT_DECLARE const CGFloat NSFontWeightBlack = 0.62;

// NSColor notification
APPKIT_DECLARE NSString *NSSystemColorsDidChangeNotification = @"NSSystemColorsDidChangeNotification";

// NSColorList notifications
APPKIT_DECLARE NSString *NSColorListDidChangeNotification = @"NSColorListDidChangeNotification";

// NSColorPanel notifications
APPKIT_DECLARE NSString *NSColorPanelColorDidChangeNotification = @"NSColorPanelColorDidChangeNotification";

// NSComboBox notifications
APPKIT_DECLARE NSString *NSComboBoxWillPopUpNotification = @"NSComboBoxWillPopUpNotification";
APPKIT_DECLARE NSString *NSComboBoxWillDismissNotification = @"NSComboBoxWillDismissNotification";
APPKIT_DECLARE NSString *NSComboBoxSelectionDidChangeNotification = @"NSComboBoxSelectionDidChangeNotification";
APPKIT_DECLARE NSString *NSComboBoxSelectionIsChangingNotification = @"NSComboBoxSelectionIsChangingNotification";

// NSControl notifications
APPKIT_DECLARE NSString *NSControlTextDidBeginEditingNotification = @"NSControlTextDidBeginEditingNotification";
APPKIT_DECLARE NSString *NSControlTextDidEndEditingNotification = @"NSControlTextDidEndEditingNotification";
APPKIT_DECLARE NSString *NSControlTextDidChangeNotification = @"NSControlTextDidChangeNotification";

// NSDataLink global strings
APPKIT_DECLARE NSString *NSDataLinkFilenameExtension = @"dlf";

// NSDrawer notifications
APPKIT_DECLARE NSString *NSDrawerDidCloseNotification = @"NSDrawerDidCloseNotification";
APPKIT_DECLARE NSString *NSDrawerDidOpenNotification = @"NSDrawerDidOpenNotification";
APPKIT_DECLARE NSString *NSDrawerWillCloseNotification = @"NSDrawerWillCloseNotification";
APPKIT_DECLARE NSString *NSDrawerWillOpenNotification = @"NSDrawerWillOpenNotification";

// NSForm private notification
APPKIT_DECLARE NSString *_NSFormCellDidChangeTitleWidthNotification 
= @"_NSFormCellDidChangeTitleWidthNotification";

// NSGraphicContext constants
APPKIT_DECLARE NSString *NSGraphicsContextDestinationAttributeName = @"NSGraphicsContextDestinationAttributeName";
APPKIT_DECLARE NSString *NSGraphicsContextPDFFormat = @"NSGraphicsContextPDFFormat";
APPKIT_DECLARE NSString *NSGraphicsContextPSFormat = @"NSGraphicsContextPSFormat";
APPKIT_DECLARE NSString *NSGraphicsContextRepresentationFormatAttributeName = @"NSGraphicsContextRepresentationFormatAttributeName";

// NSHelpManager notifications;
APPKIT_DECLARE NSString *NSContextHelpModeDidActivateNotification = @"NSContextHelpModeDidActivateNotification";
APPKIT_DECLARE NSString *NSContextHelpModeDidDeactivateNotification = @"NSContextHelpModeDidDeactivateNotification";

// NSFont Global Strings
APPKIT_DECLARE NSString *NSAFMAscender = @"Ascender";
APPKIT_DECLARE NSString *NSAFMCapHeight = @"CapHeight";
APPKIT_DECLARE NSString *NSAFMCharacterSet = @"CharacterSet";
APPKIT_DECLARE NSString *NSAFMDescender = @"Descender";
APPKIT_DECLARE NSString *NSAFMEncodingScheme = @"EncodingScheme";
APPKIT_DECLARE NSString *NSAFMFamilyName = @"FamilyName";
APPKIT_DECLARE NSString *NSAFMFontName = @"FontName";
APPKIT_DECLARE NSString *NSAFMFormatVersion = @"FormatVersion";
APPKIT_DECLARE NSString *NSAFMFullName = @"FullName";
APPKIT_DECLARE NSString *NSAFMItalicAngle = @"ItalicAngle";
APPKIT_DECLARE NSString *NSAFMMappingScheme = @"MappingScheme";
APPKIT_DECLARE NSString *NSAFMNotice = @"Notice";
APPKIT_DECLARE NSString *NSAFMUnderlinePosition = @"UnderlinePosition";
APPKIT_DECLARE NSString *NSAFMUnderlineThickness = @"UnderlineThickness";
APPKIT_DECLARE NSString *NSAFMVersion = @"Version";
APPKIT_DECLARE NSString *NSAFMWeight = @"Weight";
APPKIT_DECLARE NSString *NSAFMXHeight = @"XHeight";

// NSFontDescriptor global strings
APPKIT_DECLARE NSString *NSFontFamilyAttribute = @"NSFontFamilyAttribute";
APPKIT_DECLARE NSString *NSFontNameAttribute = @"NSFontNameAttribute";
APPKIT_DECLARE NSString *NSFontFaceAttribute = @"NSFontFaceAttribute";
APPKIT_DECLARE NSString *NSFontSizeAttribute = @"NSFontSizeAttribute"; 
APPKIT_DECLARE NSString *NSFontVisibleNameAttribute = @"NSFontVisibleNameAttribute"; 
APPKIT_DECLARE NSString *NSFontColorAttribute = @"NSFontColorAttribute";
APPKIT_DECLARE NSString *NSFontMatrixAttribute = @"NSFontMatrixAttribute";
APPKIT_DECLARE NSString *NSFontVariationAttribute = @"NSCTFontVariationAttribute";
APPKIT_DECLARE NSString *NSFontCharacterSetAttribute = @"NSCTFontCharacterSetAttribute";
APPKIT_DECLARE NSString *NSFontCascadeListAttribute = @"NSCTFontCascadeListAttribute";
APPKIT_DECLARE NSString *NSFontTraitsAttribute = @"NSCTFontTraitsAttribute";
APPKIT_DECLARE NSString *NSFontFixedAdvanceAttribute = @"NSCTFontFixedAdvanceAttribute";

APPKIT_DECLARE NSString *NSFontSymbolicTrait = @"NSCTFontSymbolicTrait";
APPKIT_DECLARE NSString *NSFontWeightTrait = @"NSCTFontWeightTrait";
APPKIT_DECLARE NSString *NSFontWidthTrait = @"NSCTFontProportionTrait";
APPKIT_DECLARE NSString *NSFontSlantTrait = @"NSCTFontSlantTrait";

APPKIT_DECLARE NSString *NSFontVariationAxisIdentifierKey = @"NSCTFontVariationAxisIdentifier";
APPKIT_DECLARE NSString *NSFontVariationAxisMinimumValueKey = @"NSCTFontVariationAxisMinimumValue";
APPKIT_DECLARE NSString *NSFontVariationAxisMaximumValueKey = @"NSCTFontVariationAxisMaximumValue";
APPKIT_DECLARE NSString *NSFontVariationAxisDefaultValueKey = @"NSCTFontVariationAxisDefaultValue";
APPKIT_DECLARE NSString *NSFontVariationAxisNameKey = @"NSCTFontVariationAxisName";

// NSScreen Global device dictionary key strings
APPKIT_DECLARE NSString *NSDeviceResolution = @"NSDeviceResolution";
APPKIT_DECLARE NSString *NSDeviceColorSpaceName = @"NSDeviceColorSpaceName";
APPKIT_DECLARE NSString *NSDeviceBitsPerSample = @"NSDeviceBitsPerSample";
APPKIT_DECLARE NSString *NSDeviceIsScreen = @"NSDeviceIsScreen";
APPKIT_DECLARE NSString *NSDeviceIsPrinter = @"NSDeviceIsPrinter";
APPKIT_DECLARE NSString *NSDeviceSize = @"NSDeviceSize";

// NSImageRep notifications
APPKIT_DECLARE NSString *NSImageRepRegistryChangedNotification = @"NSImageRepRegistryChangedNotification";

// Pasteboard Type Globals
APPKIT_DECLARE NSString *const NSPasteboardTypeString = @"NSStringPboardType";
APPKIT_DECLARE NSString *const NSStringPboardType = @"NSStringPboardType";

APPKIT_DECLARE NSString *const NSPasteboardTypeColor = @"NSColorPboardType";
APPKIT_DECLARE NSString *const NSColorPboardType = @"NSColorPboardType";

APPKIT_DECLARE NSString *const NSPasteboardTypeFont = @"NSFontPboardType";
APPKIT_DECLARE NSString *const NSFontPboardType = @"NSFontPboardType";

APPKIT_DECLARE NSString *const NSPasteboardTypeRuler = @"NSRulerPboardType";
APPKIT_DECLARE NSString *const NSRulerPboardType = @"NSRulerPboardType";

APPKIT_DECLARE NSString *const NSPasteboardTypeTabularText = @"NSTabularTextPboardType";
APPKIT_DECLARE NSString *const NSTabularTextPboardType = @"NSTabularTextPboardType";

APPKIT_DECLARE NSString *const NSPasteboardTypeRTF = @"NSRTFPboardType";
APPKIT_DECLARE NSString *const NSRTFPboardType = @"NSRTFPboardType";

APPKIT_DECLARE NSString *const NSPasteboardTypeRTFD = @"NSRTFDPboardType";
APPKIT_DECLARE NSString *const NSRTFDPboardType = @"NSRTFDPboardType";

APPKIT_DECLARE NSString *const NSPasteboardTypeTIFF = @"NSTIFFPboardType";
APPKIT_DECLARE NSString *const NSTIFFPboardType = @"NSTIFFPboardType";

APPKIT_DECLARE NSString *const NSPasteboardTypePDF = @"NSPDFPboardType";
APPKIT_DECLARE NSString *const NSPDFPboardType = @"NSPDFPboardType";

APPKIT_DECLARE NSString *const NSPasteboardTypeHTML = @"NSHTMLPboardType";
APPKIT_DECLARE NSString *const NSHTMLPboardType = @"NSHTMLPboardType";

APPKIT_DECLARE NSString *NSPasteboardTypePNG = @"NSPasteboardTypePNG";
APPKIT_DECLARE NSString *NSPasteboardTypeSound = @"NSPasteboardTypeSound";
APPKIT_DECLARE NSString *NSPasteboardTypeMultipleTextSelection = @"NSPasteboardTypeMultipleTextSelection";
APPKIT_DECLARE NSString *NSPasteboardTypeTextFinderOptions = @"NSPasteboardTypeTextFinderOptions";

APPKIT_DECLARE NSString *NSFileContentsPboardType = @"NSFileContentsPboardType";
APPKIT_DECLARE NSString *NSFilenamesPboardType = @"NSFilenamesPboardType";
APPKIT_DECLARE NSString *NSPostScriptPboardType = @"NSPostScriptPboardType";
APPKIT_DECLARE NSString *NSDataLinkPboardType = @"NSDataLinkPboardType";
APPKIT_DECLARE NSString *NSGeneralPboardType = @"NSGeneralPboardType";
APPKIT_DECLARE NSString *NSPICTPboardType = @"NSPICTPboardType";
APPKIT_DECLARE NSString *NSURLPboardType = @"NSURLPboardType";
APPKIT_DECLARE NSString *NSVCardPboardType = @"NSVCardPboardType";
APPKIT_DECLARE NSString *NSFilesPromisePboardType = @"NSFilesPromisePboardType";

// Pasteboard Name Globals
APPKIT_DECLARE NSString *NSDragPboard = @"NSDragPboard";
APPKIT_DECLARE NSString *NSFindPboard = @"NSFindPboard";
APPKIT_DECLARE NSString *NSFontPboard = @"NSFontPboard";
APPKIT_DECLARE NSString *NSGeneralPboard = @"NSGeneralPboard";
APPKIT_DECLARE NSString *NSRulerPboard = @"NSRulerPboard";

//
// Pasteboard Exceptions
//
APPKIT_DECLARE NSString *NSPasteboardCommunicationException = @"NSPasteboardCommunicationException";

APPKIT_DECLARE NSString *_NXSmartPaste = @"NeXT smart paste pasteboard type";

// Printing Information Dictionary Keys
APPKIT_DECLARE NSString *NSPrintAllPages = @"NSPrintAllPages";
APPKIT_DECLARE NSString *NSPrintBottomMargin = @"NSBottomMargin";
APPKIT_DECLARE NSString *NSPrintCopies = @"NSCopies";
APPKIT_DECLARE NSString *NSPrintFaxCoverSheetName = @"NSPrintFaxCoverSheetName";
APPKIT_DECLARE NSString *NSPrintFaxHighResolution = @"NSPrintFaxHighResolution";
APPKIT_DECLARE NSString *NSPrintFaxModem = @"NSPrintFaxModem";
APPKIT_DECLARE NSString *NSPrintFaxReceiverNames = @"NSPrintFaxReceiverNames";
APPKIT_DECLARE NSString *NSPrintFaxReceiverNumbers = @"NSPrintFaxReceiverNumbers";
APPKIT_DECLARE NSString *NSPrintFaxReturnReceipt = @"NSPrintFaxReturnReceipt";
APPKIT_DECLARE NSString *NSPrintFaxSendTime = @"NSPrintFaxSendTime";
APPKIT_DECLARE NSString *NSPrintFaxTrimPageEnds = @"NSPrintFaxTrimPageEnds";
APPKIT_DECLARE NSString *NSPrintFaxUseCoverSheet = @"NSPrintFaxUseCoverSheet";
APPKIT_DECLARE NSString *NSPrintFirstPage = @"NSFirstPage";
APPKIT_DECLARE NSString *NSPrintHorizontalPagination = @"NSHorizontalPagination";
APPKIT_DECLARE NSString *NSPrintHorizontallyCentered = @"NSHorizontallyCentered";
APPKIT_DECLARE NSString *NSPrintJobDisposition = @"NSJobDisposition";
APPKIT_DECLARE NSString *NSPrintJobFeatures = @"NSJobFeatures";
APPKIT_DECLARE NSString *NSPrintLastPage = @"NSLastPage";
APPKIT_DECLARE NSString *NSPrintLeftMargin = @"NSLeftMargin";
APPKIT_DECLARE NSString *NSPrintManualFeed = @"NSPrintManualFeed";
APPKIT_DECLARE NSString *NSPrintMustCollate = @"NSMustCollate";
APPKIT_DECLARE NSString *NSPrintOrientation = @"NSOrientation";
APPKIT_DECLARE NSString *NSPrintPagesPerSheet = @"NSPagesPerSheet";
APPKIT_DECLARE NSString *NSPrintPaperFeed = @"NSPaperFeed";
APPKIT_DECLARE NSString *NSPrintPaperName = @"NSPaperName";
APPKIT_DECLARE NSString *NSPrintPaperSize = @"NSPaperSize";
APPKIT_DECLARE NSString *NSPrintPrinter = @"NSPrinter";
APPKIT_DECLARE NSString *NSPrintReversePageOrder = @"NSReversePageOrder";
APPKIT_DECLARE NSString *NSPrintRightMargin = @"NSRightMargin";
APPKIT_DECLARE NSString *NSPrintSavePath = @"NSSavePath";
APPKIT_DECLARE NSString *NSPrintScalingFactor = @"NSScalingFactor";
APPKIT_DECLARE NSString *NSPrintTopMargin = @"NSTopMargin";
APPKIT_DECLARE NSString *NSPrintVerticalPagination = @"NSVerticalPagination";
APPKIT_DECLARE NSString *NSPrintVerticallyCentered = @"NSVerticallyCentered";
APPKIT_DECLARE NSString *NSPrintPagesAcross = @"NSPagesAcross";
APPKIT_DECLARE NSString *NSPrintPagesDown = @"NSPagesDown";
APPKIT_DECLARE NSString *NSPrintTime = @"NSPrintTime";
APPKIT_DECLARE NSString *NSPrintDetailedErrorReporting = @"NSDetailedErrorReporting";
APPKIT_DECLARE NSString *NSPrintFaxNumber = @"NSFaxNumber";
APPKIT_DECLARE NSString *NSPrintPrinterName = @"NSPrinterName";
APPKIT_DECLARE NSString *NSPrintHeaderAndFooter = @"NSPrintHeaderAndFooter";

APPKIT_DECLARE NSString *NSPrintPageDirection = @"NSPrintPageDirection";

// Print Job Disposition Values
APPKIT_DECLARE NSString  *NSPrintCancelJob = @"NSPrintCancelJob";
APPKIT_DECLARE NSString  *NSPrintFaxJob = @"NSPrintFaxJob";
APPKIT_DECLARE NSString  *NSPrintPreviewJob = @"NSPrintPreviewJob";
APPKIT_DECLARE NSString  *NSPrintSaveJob = @"NSPrintSaveJob";
APPKIT_DECLARE NSString  *NSPrintSpoolJob = @"NSPrintSpoolJob";

// Print Panel
APPKIT_DECLARE NSString *NSPrintPanelAccessorySummaryItemNameKey = @"name";
APPKIT_DECLARE NSString *NSPrintPanelAccessorySummaryItemDescriptionKey = @"description";
APPKIT_DECLARE NSString *NSPrintPhotoJobStyleHint = @"Photo";

// NSSplitView notifications
APPKIT_DECLARE NSString *NSSplitViewDidResizeSubviewsNotification =
@"NSSplitViewDidResizeSubviewsNotification";
APPKIT_DECLARE NSString *NSSplitViewWillResizeSubviewsNotification =
@"NSSplitViewWillResizeSubviewsNotification";

// NSTableView notifications
APPKIT_DECLARE NSString *NSTableViewColumnDidMove = @"NSTableViewColumnDidMoveNotification";
APPKIT_DECLARE NSString *NSTableViewColumnDidResize = @"NSTableViewColumnDidResizeNotification";
APPKIT_DECLARE NSString *NSTableViewSelectionDidChange = @"NSTableViewSelectionDidChangeNotification";
APPKIT_DECLARE NSString *NSTableViewSelectionIsChanging = @"NSTableViewSelectionIsChangingNotification";

// NSText notifications
APPKIT_DECLARE NSString *NSTextDidBeginEditingNotification = @"NSTextDidBeginEditingNotification";
APPKIT_DECLARE NSString *NSTextDidEndEditingNotification = @"NSTextDidEndEditingNotification";
APPKIT_DECLARE NSString *NSTextDidChangeNotification = @"NSTextDidChangeNotification";

// NSTextStorage Notifications
APPKIT_DECLARE NSString *NSTextStorageWillProcessEditingNotification = @"NSTextStorageWillProcessEditingNotification";
APPKIT_DECLARE NSString *NSTextStorageDidProcessEditingNotification = @"NSTextStorageDidProcessEditingNotification";

// NSTextView notifications
APPKIT_DECLARE NSString *NSTextViewDidChangeSelectionNotification = @"NSTextViewDidChangeSelectionNotification";
APPKIT_DECLARE NSString *NSTextViewWillChangeNotifyingTextViewNotification = @"NSTextViewWillChangeNotifyingTextViewNotification";
APPKIT_DECLARE NSString *NSTextViewDidChangeTypingAttributesNotification = @"NSTextViewDidChangeTypingAttributesNotification";

// NSView notifications
APPKIT_DECLARE NSString *NSViewFocusDidChangeNotification = @"NSViewFocusDidChangeNotification";
APPKIT_DECLARE NSString *NSViewFrameDidChangeNotification = @"NSViewFrameDidChangeNotification";
APPKIT_DECLARE NSString *NSViewBoundsDidChangeNotification = @"NSViewBoundsDidChangeNotification";
APPKIT_DECLARE NSString *NSViewGlobalFrameDidChangeNotification = @"NSViewGlobalFrameDidChangeNotification";

// NSViewAnimation 
APPKIT_DECLARE NSString *NSViewAnimationTargetKey     = @"NSViewAnimationTargetKey";
APPKIT_DECLARE NSString *NSViewAnimationStartFrameKey = @"NSViewAnimationStartFrameKey";
APPKIT_DECLARE NSString *NSViewAnimationEndFrameKey   = @"NSViewAnimationEndFrameKey";
APPKIT_DECLARE NSString *NSViewAnimationEffectKey     = @"NSViewAnimationEffectKey";
APPKIT_DECLARE NSString *NSViewAnimationFadeInEffect  = @"NSViewAnimationFadeInEffect";
APPKIT_DECLARE NSString *NSViewAnimationFadeOutEffect = @"NSViewAnimationFadeOutEffect";


// NSMenu notifications
NSString* const NSMenuDidSendActionNotification = @"NSMenuDidSendActionNotification";
NSString* const NSMenuWillSendActionNotification = @"NSMenuWillSendActionNotification";
NSString* const NSMenuDidAddItemNotification = @"NSMenuDidAddItemNotification";
NSString* const NSMenuDidRemoveItemNotification = @"NSMenuDidRemoveItemNotification";
NSString* const NSMenuDidChangeItemNotification = @"NSMenuDidChangeItemNotification";
NSString* const NSMenuDidBeginTrackingNotification = @"NSMenuDidBeginTrackingNotification";
NSString* const NSMenuDidEndTrackingNotification = @"NSMenuDidEndTrackingNotification";

// NSPopUpButton notification
APPKIT_DECLARE NSString *NSPopUpButtonWillPopUpNotification = @"NSPopUpButtonWillPopUpNotification";
APPKIT_DECLARE NSString *NSPopUpButtonCellWillPopUpNotification = @"NSPopUpButtonCellWillPopUpNotification";

// NSPopover notifications
APPKIT_DECLARE NSString *NSPopoverWillShowNotification = @"NSPopoverWillShowNotification";
APPKIT_DECLARE NSString *NSPopoverDidShowNotification = @"NSPopoverDidShowNotification";
APPKIT_DECLARE NSString *NSPopoverWillCloseNotification = @"NSPopoverWillCloseNotification";
APPKIT_DECLARE NSString *NSPopoverDidCloseNotification = @"NSPopoverDidCloseNotification";

// NSPopover keys
APPKIT_DECLARE NSString *NSPopoverCloseReasonKey = @"NSPopoverCloseReasonKey";
APPKIT_DECLARE NSString *NSPopoverCloseReasonStandard = @"NSPopoverCloseReasonStandard";
APPKIT_DECLARE NSString *NSPopoverCloseReasonDetachToWindow = @"NSPopoverCloseReasonDetachToWindow";

// NSTable notifications
APPKIT_DECLARE NSString *NSTableViewSelectionDidChangeNotification = @"NSTableViewSelectionDidChangeNotification";
APPKIT_DECLARE NSString *NSTableViewColumnDidMoveNotification = @"NSTableViewColumnDidMoveNotification";
APPKIT_DECLARE NSString *NSTableViewColumnDidResizeNotification = @"NSTableViewColumnDidResizeNotification";
APPKIT_DECLARE NSString *NSTableViewSelectionIsChangingNotification = @"NSTableViewSelectionIsChangingNotification";

// NSOutlineView notifications
APPKIT_DECLARE NSString *NSOutlineViewSelectionDidChangeNotification = @"NSOutlineViewSelectionDidChangeNotification";
APPKIT_DECLARE NSString *NSOutlineViewColumnDidMoveNotification = @"NSOutlineViewColumnDidMoveNotification";
APPKIT_DECLARE NSString *NSOutlineViewColumnDidResizeNotification = @"NSOutlineViewColumnDidResizeNotification";
APPKIT_DECLARE NSString *NSOutlineViewSelectionIsChangingNotification = @"NSOutlineViewSelectionIsChangingNotification";
APPKIT_DECLARE NSString *NSOutlineViewItemDidExpandNotification = @"NSOutlineViewItemDidExpandNotification";
APPKIT_DECLARE NSString *NSOutlineViewItemDidCollapseNotification = @"NSOutlineViewItemDidCollapseNotification";
APPKIT_DECLARE NSString *NSOutlineViewItemWillExpandNotification = @"NSOutlineViewItemWillExpandNotification";
APPKIT_DECLARE NSString *NSOutlineViewItemWillCollapseNotification = @"NSOutlineViewItemWillCollapseNotification";

// NSWindow notifications
APPKIT_DECLARE NSString *NSWindowDidBecomeKeyNotification = @"NSWindowDidBecomeKeyNotification";
APPKIT_DECLARE NSString *NSWindowDidBecomeMainNotification = @"NSWindowDidBecomeMainNotification";
APPKIT_DECLARE NSString *NSWindowDidChangeScreenNotification = @"NSWindowDidChangeScreenNotification";
APPKIT_DECLARE NSString *NSWindowDidChangeScreenProfileNotification = @"NSWindowDidChangeScreenProfileNotification";
APPKIT_DECLARE NSString *NSWindowDidDeminiaturizeNotification = @"NSWindowDidDeminiaturizeNotification";
APPKIT_DECLARE NSString *NSWindowDidEndSheetNotification = @"NSWindowDidEndSheetNotification";
APPKIT_DECLARE NSString *NSWindowDidExposeNotification = @"NSWindowDidExposeNotification";
APPKIT_DECLARE NSString *NSWindowDidMiniaturizeNotification = @"NSWindowDidMiniaturizeNotification";
APPKIT_DECLARE NSString *NSWindowDidMoveNotification = @"NSWindowDidMoveNotification";
APPKIT_DECLARE NSString *NSWindowDidResignKeyNotification = @"NSWindowDidResignKeyNotification";
APPKIT_DECLARE NSString *NSWindowDidResignMainNotification = @"NSWindowDidResignMainNotification";
APPKIT_DECLARE NSString *NSWindowDidResizeNotification = @"NSWindowDidResizeNotification";
APPKIT_DECLARE NSString *NSWindowDidUpdateNotification = @"NSWindowDidUpdateNotification";
APPKIT_DECLARE NSString *NSWindowWillBeginSheetNotification = @"NSWindowWillBeginSheetNotification";
APPKIT_DECLARE NSString *NSWindowWillCloseNotification = @"NSWindowWillCloseNotification";
APPKIT_DECLARE NSString *NSWindowWillMiniaturizeNotification = @"NSWindowWillMiniaturizeNotification";
APPKIT_DECLARE NSString *NSWindowWillMoveNotification = @"NSWindowWillMoveNotification";

// Workspace File Type Globals
APPKIT_DECLARE NSString *NSPlainFileType = @"NSPlainFileType";
APPKIT_DECLARE NSString *NSDirectoryFileType = @"NSDirectoryFileType";
APPKIT_DECLARE NSString *NSApplicationFileType = @"NSApplicationFileType";
APPKIT_DECLARE NSString *NSFilesystemFileType = @"NSFilesystemFileType";
APPKIT_DECLARE NSString *NSShellCommandFileType = @"NSShellCommandFileType";

// Workspace File Operation Globals
APPKIT_DECLARE NSString *NSWorkspaceCompressOperation = @"compress";
APPKIT_DECLARE NSString *NSWorkspaceCopyOperation = @"copy";
APPKIT_DECLARE NSString *NSWorkspaceDecompressOperation = @"decompress";
APPKIT_DECLARE NSString *NSWorkspaceDecryptOperation = @"decrypt";
APPKIT_DECLARE NSString *NSWorkspaceDestroyOperation = @"destroy";
APPKIT_DECLARE NSString *NSWorkspaceDuplicateOperation = @"duplicate";
APPKIT_DECLARE NSString *NSWorkspaceEncryptOperation = @"encrypt";
APPKIT_DECLARE NSString *NSWorkspaceLinkOperation = @"link";
APPKIT_DECLARE NSString *NSWorkspaceMoveOperation = @"move";
APPKIT_DECLARE NSString *NSWorkspaceRecycleOperation = @"recycle";

// NSWorkspace notifications
APPKIT_DECLARE NSString *NSWorkspaceDidLaunchApplicationNotification = @"NSWorkspaceDidLaunchApplicationNotification";
APPKIT_DECLARE NSString *NSWorkspaceDidMountNotification = @"NSWorkspaceDidMountNotification";
APPKIT_DECLARE NSString *NSWorkspaceDidPerformFileOperationNotification = @"NSWorkspaceDidPerformFileOperationNotification";
APPKIT_DECLARE NSString *NSWorkspaceDidTerminateApplicationNotification = @"NSWorkspaceDidTerminateApplicationNotification";
APPKIT_DECLARE NSString *NSWorkspaceDidUnmountNotification = @"NSWorkspaceDidUnmountNotification";
APPKIT_DECLARE NSString *NSWorkspaceWillLaunchApplicationNotification = @"NSWorkspaceWillLaunchApplicationNotification";
APPKIT_DECLARE NSString *NSWorkspaceWillPowerOffNotification = @"NSWorkspaceWillPowerOffNotification";
APPKIT_DECLARE NSString *NSWorkspaceWillUnmountNotification = @"NSWorkspaceWillUnmountNotification";
APPKIT_DECLARE NSString *NSWorkspaceDidWakeNotification = @"NSWorkspaceDidWakeNotification";
APPKIT_DECLARE NSString *NSWorkspaceSessionDidBecomeActiveNotification = @"NSWorkspaceSessionDidBecomeActiveNotification";
APPKIT_DECLARE NSString *NSWorkspaceSessionDidResignActiveNotification = @"NSWorkspaceSessionDidResignActiveNotification";
APPKIT_DECLARE NSString *NSWorkspaceWillSleepNotification = @"NSWorkspaceWillSleepNotification";

/*
 *	NSStringDrawing NSAttributedString additions
 */
APPKIT_DECLARE NSString *NSAttachmentAttributeName = @"NSAttachment";
APPKIT_DECLARE NSString *NSBackgroundColorAttributeName = @"NSBackgroundColor";
APPKIT_DECLARE NSString *NSBaselineOffsetAttributeName = @"NSBaselineOffset";
APPKIT_DECLARE NSString *NSCursorAttributeName = @"NSCursor";
APPKIT_DECLARE NSString *NSExpansionAttributeName = @"NSExpansion";
APPKIT_DECLARE NSString *NSFontAttributeName = @"NSFont";
APPKIT_DECLARE NSString *NSForegroundColorAttributeName = @"NSColor";
APPKIT_DECLARE NSString *NSKernAttributeName = @"NSKern";
APPKIT_DECLARE NSString *NSLigatureAttributeName = @"NSLigature";
APPKIT_DECLARE NSString *NSLinkAttributeName = @"NSLink";
APPKIT_DECLARE NSString *NSObliquenessAttributeName = @"NSObliqueness";
APPKIT_DECLARE NSString *NSParagraphStyleAttributeName = @"NSParagraphStyle";
APPKIT_DECLARE NSString *NSShadowAttributeName = @"NSShadow";
APPKIT_DECLARE NSString *NSStrikethroughColorAttributeName = @"NSStrikethroughColor";
APPKIT_DECLARE NSString *NSStrikethroughStyleAttributeName = @"NSStrikethrough";
APPKIT_DECLARE NSString *NSStrokeColorAttributeName = @"NSStrokeColor";
APPKIT_DECLARE NSString *NSStrokeWidthAttributeName = @"NSStrokeWidth";
APPKIT_DECLARE NSString *NSSuperscriptAttributeName = @"NSSuperScript";
APPKIT_DECLARE NSString *NSToolTipAttributeName = @"NSToolTip";
APPKIT_DECLARE NSString *NSUnderlineColorAttributeName = @"NSUnderlineColor";
APPKIT_DECLARE NSString *NSUnderlineStyleAttributeName = @"NSUnderline";

APPKIT_DECLARE NSString *NSTextAlternativesAttributeName = @"NSTextAlternatives";
APPKIT_DECLARE NSString *NSWritingDirectionAttributeName = @"NSWritingDirection";

APPKIT_DECLARE NSString *NSCharacterShapeAttributeName = @"NSCharacterShape";
APPKIT_DECLARE NSString *NSGlyphInfoAttributeName = @"NSGlyphInfo";

APPKIT_DECLARE NSString *NSPaperSizeDocumentAttribute = @"PaperSize";
APPKIT_DECLARE NSString *NSLeftMarginDocumentAttribute = @"LeftMargin";
APPKIT_DECLARE NSString *NSRightMarginDocumentAttribute = @"RightMargin";
APPKIT_DECLARE NSString *NSTopMarginDocumentAttribute = @"TopMargin";
APPKIT_DECLARE NSString *NSBottomMarginDocumentAttribute = @"BottomMargin";
APPKIT_DECLARE NSString *NSHyphenationFactorDocumentAttribute = @"HyphenationFactor";
APPKIT_DECLARE NSString *NSDocumentTypeDocumentAttribute = @"DocumentType";
APPKIT_DECLARE NSString *NSCharacterEncodingDocumentAttribute = @"CharacterEncoding";
APPKIT_DECLARE NSString *NSViewSizeDocumentAttribute = @"ViewSize";
APPKIT_DECLARE NSString *NSViewZoomDocumentAttribute = @"ViewZoom";
APPKIT_DECLARE NSString *NSViewModeDocumentAttribute = @"ViewMode";
APPKIT_DECLARE NSString *NSBackgroundColorDocumentAttribute = @"BackgroundColor";
APPKIT_DECLARE NSString *NSCocoaVersionDocumentAttribute = @"CocoaVersion";
APPKIT_DECLARE NSString *NSReadOnlyDocumentAttribute = @"ReadOnly";
APPKIT_DECLARE NSString *NSConvertedDocumentAttribute = @"Converted";
APPKIT_DECLARE NSString *NSDefaultTabIntervalDocumentAttribute = @"DefaultTabInterval";
APPKIT_DECLARE NSString *NSTitleDocumentAttribute = @"Title";
APPKIT_DECLARE NSString *NSCompanyDocumentAttribute = @"Company";
APPKIT_DECLARE NSString *NSCopyrightDocumentAttribute = @"Copyright";
APPKIT_DECLARE NSString *NSSubjectDocumentAttribute = @"Subject";
APPKIT_DECLARE NSString *NSAuthorDocumentAttribute = @"Author";
APPKIT_DECLARE NSString *NSKeywordsDocumentAttribute = @"Keywords";
APPKIT_DECLARE NSString *NSCommentDocumentAttribute = @"Comment";
APPKIT_DECLARE NSString *NSEditorDocumentAttribute = @"Editor";
APPKIT_DECLARE NSString *NSCreationTimeDocumentAttribute = @"CreationTime";
APPKIT_DECLARE NSString *NSModificationTimeDocumentAttribute = @"ModificationTime";

APPKIT_DECLARE NSString *NSTextInsertionUndoableAttributeName =   @"NSTextInsertionUndoableAttributeName";

APPKIT_DECLARE const unsigned NSUnderlineByWordMask = 0x01;

APPKIT_DECLARE NSString *NSSpellingStateAttributeName = @"NSSpellingState";
APPKIT_DECLARE const unsigned NSSpellingStateSpellingFlag = 1;
APPKIT_DECLARE const unsigned NSSpellingStateGrammarFlag = 2;

APPKIT_DECLARE NSString *NSSpellCheckerDidChangeAutomaticSpellingCorrectionNotification = @"NSSpellCheckerDidChangeAutomaticSpellingCorrectionNotification";
APPKIT_DECLARE NSString *NSSpellCheckerDidChangeAutomaticTextReplacementNotification = @"NSSpellCheckerDidChangeAutomaticTextReplacementNotification";
APPKIT_DECLARE NSString *NSSpellCheckerDidChangeAutomaticQuoteSubstitutionNotification = @"NSSpellCheckerDidChangeAutomaticQuoteSubstitutionNotification";
APPKIT_DECLARE NSString *NSSpellCheckerDidChangeAutomaticDashSubstitutionNotification = @"NSSpellCheckerDidChangeAutomaticDashSubstitutionNotification";


APPKIT_DECLARE NSString *NSPlainTextDocumentType = @"NSPlainText";
APPKIT_DECLARE NSString *NSRTFTextDocumentType = @"NSRTF";
APPKIT_DECLARE NSString *NSRTFDTextDocumentType = @"NSRTFD";
APPKIT_DECLARE NSString *NSMacSimpleTextDocumentType = @"NSMacSimpleText";
APPKIT_DECLARE NSString *NSHTMLTextDocumentType = @"NSHTML";
APPKIT_DECLARE NSString *NSDocFormatTextDocumentType = @"NSDocFormat";
APPKIT_DECLARE NSString *NSWordMLTextDocumentType = @"NSWordML";
APPKIT_DECLARE NSString *NSOfficeOpenXMLTextDocumentType = @"NSOfficeOpenXML";
APPKIT_DECLARE NSString *NSOpenDocumentTextDocumentType = @"NSOpenDocumentText";

APPKIT_DECLARE NSString *NSExcludedElementsDocumentAttribute = @"ExcludedElements";
APPKIT_DECLARE NSString *NSTextEncodingNameDocumentAttribute = @"TextEncodingName";
APPKIT_DECLARE NSString *NSPrefixSpacesDocumentAttribute = @"PrefixSpaces";

APPKIT_DECLARE NSString *NSBaseURLDocumentOption = @"BaseURL";
APPKIT_DECLARE NSString *NSCharacterEncodingDocumentOption = @"CharacterEncoding";
APPKIT_DECLARE NSString *NSDefaultAttributesDocumentOption = @"DefaultAttributes";
APPKIT_DECLARE NSString *NSDocumentTypeDocumentOption = @"DocumentType";
APPKIT_DECLARE NSString *NSTextEncodingNameDocumentOption = @"TextEncodingName";
APPKIT_DECLARE NSString *NSTextSizeMultiplierDocumentOption = @"TextSizeMultiplier";
APPKIT_DECLARE NSString *NSTimeoutDocumentOption = @"Timeout";
APPKIT_DECLARE NSString *NSWebPreferencesDocumentOption = @"WebPreferences";
APPKIT_DECLARE NSString *NSWebResourceLoadDelegateDocumentOption = @"WebResourceLoadDelegate";

// NSTextTab
APPKIT_DECLARE NSString *NSTabColumnTerminatorsAttributeName = @"NSTabColumnTerminatorsAttributeName"; 

// Private Exports
APPKIT_DECLARE NSString *NSMarkedClauseSegmentAttributeName = @"NSMarkedClauseSegmentAttributeName";
APPKIT_DECLARE NSString *NSTextInputReplacementRangeAttributeName = @"NSTextInputReplacementRangeAttributeName";

// NSToolbar notifications
APPKIT_DECLARE NSString *NSToolbarDidRemoveItemNotification = @"NSToolbarDidRemoveItemNotification";
APPKIT_DECLARE NSString *NSToolbarWillAddItemNotification = @"NSToolbarWillAddItemNotification";

// NSToolbarItem constants
APPKIT_DECLARE NSString *NSToolbarSeparatorItemIdentifier = @"NSToolbarSeparatorItem";
APPKIT_DECLARE NSString *NSToolbarSpaceItemIdentifier = @"NSToolbarSpaceItem";
APPKIT_DECLARE NSString *NSToolbarFlexibleSpaceItemIdentifier = @"NSToolbarFlexibleSpaceItem";
APPKIT_DECLARE NSString *NSToolbarShowColorsItemIdentifier = @"NSToolbarShowColorsItem";
APPKIT_DECLARE NSString *NSToolbarShowFontsItemIdentifier = @"NSToolbarShowFontsItem";
APPKIT_DECLARE NSString *NSToolbarCustomizeToolbarItemIdentifier = @"NSToolbarCustomizeToolbarItem";
APPKIT_DECLARE NSString *NSToolbarPrintItemIdentifier = @"NSToolbarPrintItem";

APPKIT_DECLARE NSString *NSImageNameTrashEmpty = @"NSImageTrashEmpty";
APPKIT_DECLARE NSString *NSImageNameTrashFull = @"NSImageTrashFull";

// Misc named images
APPKIT_DECLARE NSString *NSImageNameMultipleDocuments = @"NSImageNameMultipleDocuments";

/*
 * NSTextView userInfo for notifications 
 */
APPKIT_DECLARE NSString *NSOldSelectedCharacterRange = @"NSOldSelectedCharacterRange";

/* NSFont matrix */
APPKIT_DECLARE const CGFloat NSFontIdentityMatrix[] = {1, 0, 0, 1, 0, 0};

/* Drawing engine externs */
APPKIT_DECLARE NSString *NSBackendContext = @"NSBackendContext";

typedef int NSWindowDepth;

/**** Color function externs ****/
/* Since these are constants it was not possible
   to do the OR directly.  If you change the
   _GS*BitValue numbers, please remember to
   change the corresponding depth values */
APPKIT_DECLARE const NSWindowDepth _GSGrayBitValue = 256;
APPKIT_DECLARE const NSWindowDepth _GSRGBBitValue = 512;
APPKIT_DECLARE const NSWindowDepth _GSCMYKBitValue = 1024;
APPKIT_DECLARE const NSWindowDepth _GSNamedBitValue = 2048;
APPKIT_DECLARE const NSWindowDepth _GSCustomBitValue = 4096;
APPKIT_DECLARE const NSWindowDepth NSDefaultDepth = 0;            // GRAY = 256, RGB = 512
APPKIT_DECLARE const NSWindowDepth NSTwoBitGrayDepth = 258;       // 0100000010 GRAY | 2bps
APPKIT_DECLARE const NSWindowDepth NSEightBitGrayDepth = 264;     // 0100001000 GRAY | 8bps
APPKIT_DECLARE const NSWindowDepth NSEightBitRGBDepth = 514;      // 1000000010 RGB  | 2bps
APPKIT_DECLARE const NSWindowDepth NSTwelveBitRGBDepth = 516;     // 1000000100 RGB  | 4bps
APPKIT_DECLARE const NSWindowDepth GSSixteenBitRGBDepth = 517;    // 1000000101 RGB  | 5bps GNUstep specific
APPKIT_DECLARE const NSWindowDepth NSTwentyFourBitRGBDepth = 520; // 1000001000 RGB  | 8bps
APPKIT_DECLARE const NSWindowDepth _GSWindowDepths[7] = { 258, 264, 514, 516, 517, 520, 0 };

/* End of color functions externs */

// NSKeyValueBinding
APPKIT_DECLARE NSString *NSObservedObjectKey = @"NSObservedObject";
APPKIT_DECLARE NSString *NSObservedKeyPathKey = @"NSObservedKeyPath";
APPKIT_DECLARE NSString *NSOptionsKey = @"NSOptions";

APPKIT_DECLARE NSString *NSAllowsEditingMultipleValuesSelectionBindingOption = @"NSAllowsEditingMultipleValuesSelection";
APPKIT_DECLARE NSString *NSAllowsNullArgumentBindingOption = @"NSAllowsNullArgument";
APPKIT_DECLARE NSString *NSConditionallySetsEditableBindingOption = @"NSConditionallySetsEditable";
APPKIT_DECLARE NSString *NSConditionallySetsEnabledBindingOption = @"NSConditionallySetsEnabled";
APPKIT_DECLARE NSString *NSConditionallySetsHiddenBindingOption = @"NSConditionallySetsHidden";
APPKIT_DECLARE NSString *NSContinuouslyUpdatesValueBindingOption = @"NSContinuouslyUpdatesValue";
APPKIT_DECLARE NSString *NSCreatesSortDescriptorBindingOption = @"NSCreatesSortDescriptor";
APPKIT_DECLARE NSString *NSDeletesObjectsOnRemoveBindingsOption = @"NSDeletesObjectsOnRemove";
APPKIT_DECLARE NSString *NSDisplayNameBindingOption = @"NSDisplayName";
APPKIT_DECLARE NSString *NSDisplayPatternBindingOption = @"NSDisplayPattern";
APPKIT_DECLARE NSString *NSHandlesContentAsCompoundValueBindingOption = @"NSHandlesContentAsCompoundValue";
APPKIT_DECLARE NSString *NSInsertsNullPlaceholderBindingOption = @"NSInsertsNullPlaceholder";
APPKIT_DECLARE NSString *NSInvokesSeparatelyWithArrayObjectsBindingOption = @"NSInvokesSeparatelyWithArrayObjects";
APPKIT_DECLARE NSString *NSMultipleValuesPlaceholderBindingOption = @"NSMultipleValuesPlaceholder";
APPKIT_DECLARE NSString *NSNoSelectionPlaceholderBindingOption = @"NSNoSelectionPlaceholder";
APPKIT_DECLARE NSString *NSNotApplicablePlaceholderBindingOption = @"NSNotApplicablePlaceholder";
APPKIT_DECLARE NSString *NSNullPlaceholderBindingOption = @"NSNullPlaceholder";
APPKIT_DECLARE NSString *NSPredicateFormatBindingOption = @"NSPredicateFormat";
APPKIT_DECLARE NSString *NSRaisesForNotApplicableKeysBindingOption = @"NSRaisesForNotApplicableKeys";
APPKIT_DECLARE NSString *NSSelectorNameBindingOption = @"NSSelectorName";
APPKIT_DECLARE NSString *NSSelectsAllWhenSettingContentBindingOption = @"NSSelectsAllWhenSettingContent";
APPKIT_DECLARE NSString *NSValidatesImmediatelyBindingOption = @"NSValidatesImmediately";
APPKIT_DECLARE NSString *NSValueTransformerNameBindingOption = @"NSValueTransformerName";
APPKIT_DECLARE NSString *NSValueTransformerBindingOption = @"NSValueTransformer";
 
APPKIT_DECLARE NSString *NSAlignmentBinding = @"alignment";
APPKIT_DECLARE NSString *NSContentArrayBinding = @"contentArray";
APPKIT_DECLARE NSString *NSContentBinding = @"content";
APPKIT_DECLARE NSString *NSContentDictionaryBinding = @"contentDictionary";
APPKIT_DECLARE NSString *NSContentObjectBinding = @"contentObject";
APPKIT_DECLARE NSString *NSContentValuesBinding = @"contentValues";
APPKIT_DECLARE NSString *NSEditableBinding = @"editable";
APPKIT_DECLARE NSString *NSEnabledBinding = @"enabled";
APPKIT_DECLARE NSString *NSExcludedKeysBinding = @"excludedKeys";
APPKIT_DECLARE NSString *NSFontBinding = @"font";
APPKIT_DECLARE NSString *NSFontNameBinding = @"fontName";
APPKIT_DECLARE NSString *NSFontSizeBinding = @"fontSize";
APPKIT_DECLARE NSString *NSHiddenBinding = @"hidden";
APPKIT_DECLARE NSString *NSIncludedKeysBinding = @"includedKeys";
APPKIT_DECLARE NSString *NSInitialKeyBinding = @"initialKey";
APPKIT_DECLARE NSString *NSInitialValueBinding = @"initialValue";
APPKIT_DECLARE NSString *NSLocalizedKeyDictionaryBinding = @"localizedKeyDictionary";
APPKIT_DECLARE NSString *NSSelectedIndexBinding = @"selectedIndex";
APPKIT_DECLARE NSString *NSSelectedObjectBinding = @"selectedObject";
APPKIT_DECLARE NSString *NSSelectedTagBinding = @"selectedTag";
APPKIT_DECLARE NSString *NSSelectedValueBinding = @"selectedValue";
APPKIT_DECLARE NSString *NSSelectionIndexesBinding = @"selectionIndexes";
APPKIT_DECLARE NSString *NSSelectionIndexPathsBinding = @"selectionIndexPaths";
APPKIT_DECLARE NSString *NSSortDescriptorsBinding = @"sortDescriptors";
APPKIT_DECLARE NSString *NSTextColorBinding = @"textColor";
APPKIT_DECLARE NSString *NSTitleBinding = @"title";
APPKIT_DECLARE NSString *NSToolTipBinding = @"toolTip";
APPKIT_DECLARE NSString *NSValueBinding = @"value";

// FIXME: Need to define class _NSStateMarker!
APPKIT_DECLARE id NSMultipleValuesMarker = @"<MULTIPLE VALUES MARKER>";
APPKIT_DECLARE id NSNoSelectionMarker = @"<NO SELECTION MARKER>";
APPKIT_DECLARE id NSNotApplicableMarker = @"<NOT APPLICABLE MARKER>";


// NSNib
APPKIT_DECLARE NSString *NSNibTopLevelObjects = @"NSTopLevelObjects";
APPKIT_DECLARE NSString *NSNibOwner = @"NSOwner";

// NSImage directly mapped NS named images constants
APPKIT_DECLARE NSString *NSImageNameUserAccounts = @"NSUserAccounts";
APPKIT_DECLARE NSString *NSImageNamePreferencesGeneral = @"NSPreferencesGeneral";
APPKIT_DECLARE NSString *NSImageNameAdvanced = @"NSAdvanced";
APPKIT_DECLARE NSString *NSImageNameInfo = @"NSInfo";
APPKIT_DECLARE NSString *NSImageNameFontPanel = @"NSFontPanel";
APPKIT_DECLARE NSString *NSImageNameColorPanel = @"NSColorPanel";
APPKIT_DECLARE NSString *NSImageNameCaution = @"NSCaution";

// NSRuleEditor
APPKIT_DECLARE NSString *const NSRuleEditorPredicateLeftExpression = @"NSRuleEditorPredicateLeftExpression";
APPKIT_DECLARE NSString *const NSRuleEditorPredicateRightExpression = @"NSRuleEditorPredicateRightExpression";
APPKIT_DECLARE NSString *const NSRuleEditorPredicateComparisonModifier = @"NSRuleEditorPredicateComparisonModifier";
APPKIT_DECLARE NSString *const NSRuleEditorPredicateOptions = @"NSRuleEditorPredicateOptions";
APPKIT_DECLARE NSString *const NSRuleEditorPredicateOperatorType = @"NSRuleEditorPredicateOperatorType";
APPKIT_DECLARE NSString *const NSRuleEditorPredicateCustomSelector = @"NSRuleEditorPredicateCustomSelector";
APPKIT_DECLARE NSString *const NSRuleEditorPredicateCompoundType = @"NSRuleEditorPredicateCompoundType";

APPKIT_DECLARE NSString *NSRuleEditorRowsDidChangeNotification = @"NSRuleEditorRowsDidChangeNotification";

// NSAppearance
const NSAppearanceName NSAppearanceNameAqua = @"NSAppearanceNameAqua";
const NSAppearanceName NSAppearanceNameDarkAqua = @"NSAppearanceNameDarkAqua";
const NSAppearanceName NSAppearanceNameVibrantLight = @"NSAppearanceNameVibrantLight";
const NSAppearanceName NSAppearanceNameVibrantDark = @"NSAppearanceNameVibrantDark";
const NSAppearanceName NSAppearanceNameAccessibilityHighContrastAqua = @"NSAppearanceNameAccessibilityHighContrastAqua";
const NSAppearanceName NSAppearanceNameAccessibilityHighContrastDarkAqua = @"NSAppearanceNameAccessibilityHighContrastDarkAqua";
const NSAppearanceName NSAppearanceNameAccessibilityHighContrastVibrantLight = @"NSAppearanceNameAccessibilityHighContrastVibrantLight";
const NSAppearanceName NSAppearanceNameAccessibilityHighContrastVibrantDark = @"NSAppearanceNameAccessibilityHighContrastVibrantDark";
const NSAppearanceName NSAppearanceNameLightContent = @"NSAppearanceNameLightContent";

// Values for NSFontCollectionAction
APPKIT_DECLARE NSFontCollectionActionTypeKey const NSFontCollectionWasShown = @"NSFontCollectionWasShown";
APPKIT_DECLARE NSFontCollectionActionTypeKey const NSFontCollectionWasHidden = @"NSFontCollectionWasHidden";
APPKIT_DECLARE NSFontCollectionActionTypeKey const NSFontCollectionWasRenamed = @"NSFontCollectionWasRenamed";

// Standard named collections
APPKIT_DECLARE NSFontCollectionName const NSFontCollectionAllFonts = @"NSFontCollectionAllFonts";
APPKIT_DECLARE NSFontCollectionName const NSFontCollectionUser = @"NSFontCollectionUser";
APPKIT_DECLARE NSFontCollectionName const NSFontCollectionFavorites = @"NSFontCollectionFavorites";
APPKIT_DECLARE NSFontCollectionName const NSFontCollectionRecentlyUsed = @"NSFontCollectionRecentlyUsed";

// Collections
APPKIT_DECLARE NSFontCollectionMatchingOptionKey const NSFontCollectionIncludeDisabledFontsOption = @"NSFontCollectionIncludeDisabledFontsOption";
APPKIT_DECLARE NSFontCollectionMatchingOptionKey const NSFontCollectionRemoveDuplicatesOption = @"NSFontCollectionRemoveDuplicatesOption";
APPKIT_DECLARE NSFontCollectionMatchingOptionKey const NSFontCollectionDisallowAutoActivationOption = @"NSFontCollectionDisallowAutoActivationOption";

// Speech recognition...
APPKIT_DECLARE const NSString *GSSpeechRecognizerDidRecognizeWordNotification = @"GSSpeechRecognizerDidRecognizeWordNotification"; 

// NSTextInputContext notifications
APPKIT_DECLARE NSString *NSTextInputContextKeyboardSelectionDidChangeNotification = @"NSTextInputContextKeyboardSelectionDidChangeNotification";

APPKIT_DECLARE NSPasteboardTypeTextFinderOptionKey const NSTextFinderCaseInsensitiveKey = @"NSTextFinderCaseInsensitiveKey";
APPKIT_DECLARE NSPasteboardTypeTextFinderOptionKey const NSTextFinderMatchingTypeKey = @"NSTextFinderMatchingTypeKey";

APPKIT_DECLARE CGFloat const NSGridViewSizeForContent = 0.0;

// NSCollectionView constants
APPKIT_DECLARE NSCollectionViewSupplementaryElementKind const NSCollectionElementKindInterItemGapIndicator = @"NSCollectionElementKindInterItemGapIndicator";
APPKIT_DECLARE NSCollectionViewSupplementaryElementKind const NSCollectionElementKindSectionHeader = @"UICollectionElementKindSectionHeader";
APPKIT_DECLARE NSCollectionViewSupplementaryElementKind const NSCollectionElementKindSectionFooter = @"UICollectionElementKindSectionFooter";

extern void __objc_gui_force_linking (void);

void
__objc_gui_force_linking (void)
{
  extern void __objc_gui_linking (void);
  __objc_gui_linking ();
}
