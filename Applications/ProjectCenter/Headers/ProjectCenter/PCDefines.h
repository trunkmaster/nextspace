/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2000-2010 Free Software Foundation

   Authors: Philippe C.D. Robert
            Serg Stoyan

   This file is part of GNUstep.

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

#ifndef _PCDefines_h_
#define _PCDefines_h_

#define PC_EXTERN       extern
#define PRIVATE_EXTERN  __private_extern__

#define Compiler                        @"Compiler"
#define BundlePaths                     @"BundlePaths"

#define PCAppDidInitNotification        @"PCAppDidInit"
#define PCAppWillTerminateNotification  @"PCAppWillTerminate"

#define NIB_NOT_FOUND_EXCEPTION         @"NibNotFoundException"
#define UNKNOWN_PROJECT_TYPE_EXCEPTION  @"UnknownProjectTypeException"
#define NOT_A_PROJECT_TYPE_EXCEPTION    @"NoProjectTypeCreatorException"
#define PROJECT_CREATION_EXCEPTION      @"ProjectCreationException"
#define PROJECT_OPEN_FAILED_EXCEPTION   @"ProjectOpenFailedException"
#define PROJECT_SAVE_FAILED_EXCEPTION   @"ProjectSaveFailedException"
#define BUNDLE_MANAGER_EXCEPTION        @"BundleManagerException"

//=============================================================================
// ==== MacOS X portability defines
//=============================================================================
#ifndef GNUSTEP

#define RETAIN(object)          [object retain]
#define RELEASE(object)         [object release]
#define AUTORELEASE(object)     [object autorelease]
#define TEST_RELEASE(object)    ({ if (object) [object release]; })
#define ASSIGN(object,value)    ({\
id __value = (id)(value); \
id __object = (id)(object); \
if (__value != __object) \
  { \
    if (__value != nil) \
      { \
        [__value retain]; \
      } \
    object = __value; \
    if (__object != nil) \
      { \
        [__object release]; \
      } \
  } \
})
#define DESTROY(object) ({ \
  if (object) \
    { \
      id __o = object; \
      object = nil; \
      [__o release]; \
    } \
})

#define NSLocalizedString(key, comment) \
  [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:nil]

#define _(X) NSLocalizedString (X, @"")

#endif // GNUSTEP_BASE_VERSION

//
// ==== From PCProject.h
//
#ifndef IMAGE
#define IMAGE(X) [NSImage imageNamed:(X)]
#endif

//=============================================================================
// ==== Not used yet
//=============================================================================

#define TOUCHED_NOTHING		(0)
#define TOUCHED_EVERYTHING	(1 << 0)
#define TOUCHED_PROJECT_NAME	(1 << 1)
#define TOUCHED_LANGUAGE	(1 << 2)
#define TOUCHED_PROJECT_TYPE	(1 << 3)
#define TOUCHED_INSTALL_DIR	(1 << 4)
#define TOUCHED_ICON_NAMES	(1 << 5)
#define TOUCHED_FILES		(1 << 6)
#define TOUCHED_MAINNIB		(1 << 7)
#define TOUCHED_PRINCIPALCLASS	(1 << 8)
#define TOUCHED_TARGETS		(1 << 9)
#define TOUCHED_PB_PROJECT	(1 << 10)
#define TOUCHED_SYST_EXT	(1 << 11)
#define TOUCHED_EXTENSION	(1 << 12)
#define TOUCHED_PATHS		(1 << 13)

typedef int PCProjInfoBits;

//=============================================================================
// ==== Project keys
//=============================================================================

#import <Foundation/Foundation.h>

static NSString * const PCLastEditing          = @"LAST_EDITING";
static NSString * const PCWindows              = @"PC_WINDOWS";

static NSString * const PCClasses              = @"CLASS_FILES";
static NSString * const PCHeaders              = @"HEADER_FILES";
static NSString * const PCOtherSources         = @"OTHER_SOURCES";
static NSString * const PCInterfaces           = @"INTERFACES";
static NSString * const PCImages               = @"IMAGES";
static NSString * const PCOtherResources       = @"OTHER_RESOURCES";
static NSString * const PCSubprojects          = @"SUBPROJECTS";
static NSString * const PCDocuFiles            = @"DOCU_FILES";
static NSString * const PCSupportingFiles      = @"SUPPORTING_FILES";
static NSString * const PCLibraries            = @"LIBRARIES";
static NSString * const PCNonProject           = @"NON_PROJECT_FILES";
static NSString * const PCGSMarkupFiles	       = @"INTERFACES";
static NSString * const PCLanguage	       = @"LANGUAGE";
static NSString * const PCUserLanguages	       = @"USER_LANGUAGES";
static NSString * const PCLocalizedResources   = @"LOCALIZED_RESOURCES";

static NSString * const PCBuildTool            = @"BUILDTOOL";
static NSString * const PCCompilerOptions      = @"COMPILEROPTIONS";
static NSString * const PCPreprocessorOptions  = @"CPPOPTIONS";
static NSString * const PCCreationDate         = @"CREATION_DATE";
static NSString * const PCInstallDomain        = @"INSTALLDOMAIN";
static NSString * const PCLinkerOptions        = @"LINKEROPTIONS";
static NSString * const PCObjCCompilerOptions  = @"OBJC_COMPILEROPTIONS";
static NSString * const PCPrincipalClass       = @"PRINCIPAL_CLASS";
static NSString * const PCAuthors              = @"PROJECT_AUTHORS";
static NSString * const PCBundleIdentifier     = @"BUNDLE_IDENTIFIER";
static NSString * const PCCopyright            = @"PROJECT_COPYRIGHT";
static NSString * const PCCopyrightDescription = @"PROJECT_COPYRIGHT_DESC";
static NSString * const PCProjectCreator       = @"PROJECT_CREATOR";
static NSString * const PCDescription          = @"PROJECT_DESCRIPTION";
static NSString * const PCDocumentExtensions   = @"PROJECT_DOCUMENTEXTENSIONS";
static NSString * const PCDocumentTypes        = @"PROJECT_DOCUMENTTYPES";
static NSString * const PCGroup                = @"PROJECT_GROUP";
static NSString * const PCProjectMaintainer    = @"PROJECT_MAINTAINER";
static NSString * const PCProjectName          = @"PROJECT_NAME";
static NSString * const PCRelease              = @"PROJECT_RELEASE";
static NSString * const PCSummary              = @"PROJECT_SUMMARY";
static NSString * const PCProjectType          = @"PROJECT_TYPE";
static NSString * const PCURL                  = @"PROJECT_URL";
static NSString * const PCSearchHeaders        = @"SEARCH_HEADER_DIRS";
static NSString * const PCSearchLibs           = @"SEARCH_LIB_DIRS";

// Project Builder options
static NSString * const PCBuilderTargets       = @"BUILDER_TARGETS";
static NSString * const PCBuilderArguments     = @"BUILDER_ARGS";
static NSString * const PCBuilderDebug         = @"BUILDER_DEBUG";
static NSString * const PCBuilderStrip         = @"BUILDER_STRIP";
static NSString * const PCBuilderVerbose       = @"BUILDER_VERBOSE";
static NSString * const PCBuilderSharedLibs    = @"BUILDER_SHARED_LIBS";

// Application specific
static NSString * const PCAppIcon              = @"APPLICATIONICON";
static NSString * const PCMainInterfaceFile    = @"MAININTERFACE";
static NSString * const PCHelpFile             = @"HELP_FILE";
static NSString * const PCDocumentBasedApp     = @"APP_DOCUMENT_BASED";
static NSString * const PCAppType              = @"APP_TYPE";

// Library specific
static NSString * const PCPublicHeaders        = @"PUBLIC_HEADERS";
static NSString * const PCHeadersInstallDir    = @"HEADERS_INSTALL_DIR";

// Bundle specific
static NSString * const PCBundleExtension      = @"BUNDLE_EXTENSION";

// Tool specific
static NSString * const PCToolIcon             = @"TOOLICON";

static NSString * const PCPackageName          = @"PACKAGE_NAME";
static NSString * const PCLibraryVar           = @"LIBRARY_VAR";

// Will be removed (compatibility)
static NSString * const PCProjectBuilderClass  = @"PROJECT_BUILDER"; 

#endif // _PCDEFINES_H_

