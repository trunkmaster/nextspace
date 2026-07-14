#
# GNUmakefile
#
ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif

ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

PACKAGE_NAME = ProjectCenter
export PACKAGE_NAME
include $(GNUSTEP_MAKEFILES)/common.make

#
# Main application
#
VERSION = 0.7.0
APP_NAME = ProjectCenter
ProjectCenter_APPLICATION_ICON = Images/ProjectCenter.tiff

#
# SVN information for releases
#
CVS_MODULE_NAME = projectcenter
SVN_MODULE_NAME = projectcenter
SVN_BASE_URL = svn+ssh://svn.gna.org/svn/gnustep/apps

#
# Subprojects
#
SUBPROJECTS = \
	Framework \
	Modules

#
# Resource files
#
ProjectCenter_RESOURCE_FILES = \
Resources/Info-gnustep.plist \
Images/ProjectCenter.tiff \
Images/FileProject.tiff \
Images/Build.tiff \
Images/Clean.tiff \
Images/Debug.tiff \
Images/Files.tiff \
Images/Find.tiff \
Images/Inspector.tiff \
Images/Install.tiff \
Images/MultiFiles.tiff \
Images/Options.tiff \
Images/Run.tiff \
Images/Stop.tiff \
Images/ProjectCenter_add.tiff \
Images/ProjectCenter_cvs.tiff \
Images/ProjectCenter_dist.tiff \
Images/ProjectCenter_documentation.tiff \
Images/ProjectCenter_profile.tiff \
Images/ProjectCenter_rpm.tiff \
Images/ProjectCenter_uml.tiff \
Images/classSuitcase.tiff \
Images/classSuitcaseH.tiff \
Images/genericSuitcase.tiff \
Images/genericSuitcaseH.tiff \
Images/headerSuitcase.tiff \
Images/headerSuitcaseH.tiff \
Images/helpSuitcase.tiff \
Images/helpSuitcaseH.tiff \
Images/iconSuitcase.tiff \
Images/iconSuitcaseH.tiff \
Images/librarySuitcase.tiff \
Images/librarySuitcaseH.tiff \
Images/nibSuitcase.tiff \
Images/nibSuitcaseH.tiff \
Images/otherSuitcase.tiff \
Images/otherSuitcaseH.tiff \
Images/projectSuitcase.tiff \
Images/projectSuitcaseH.tiff \
Images/soundSuitcase.tiff \
Images/soundSuitcaseH.tiff \
Images/subprojectSuitcase.tiff \
Images/subprojectSuitcaseH.tiff \
Modules/Projects/Aggregate/Aggregate.project \
Modules/Projects/Application/Application.project \
Modules/Projects/Bundle/Bundle.project \
Modules/Projects/Framework/Framework.project \
Modules/Projects/Library/Library.project \
Modules/Projects/ResourceSet/ResourceSet.project \
Modules/Projects/Tool/Tool.project \
Modules/Editors/ProjectCenter/ProjectCenter.editor \
Modules/Parsers/ProjectCenter/ProjectCenter.parser \
Modules/Debuggers/ProjectCenter/ProjectCenter.debugger \
Modules/Preferences/Build/Build.preferences \
Modules/Preferences/Saving/Saving.preferences \
Modules/Preferences/Misc/Misc.preferences \
Modules/Preferences/EditorFSC/EditorFSC.preferences

#
# Localization
#
ProjectCenter_LOCALIZED_RESOURCE_FILES = \
ProjectCenter.gorm \
Info.gorm \
Preferences.gorm

ProjectCenter_LANGUAGES = \
English


#
# Header files
#
ProjectCenter_HEADERS = \
Headers/PCAppController.h \
Headers/PCInfoController.h \
Headers/PCMenuController.h \
Headers/PCPrefController.h

#
# Class files
#
ProjectCenter_OBJC_FILES = \
PCAppController.m \
PCInfoController.m \
PCMenuController.m \
PCPrefController.m \
ProjectCenter_main.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make
-include GNUmakefile.postamble
include $(GNUSTEP_MAKEFILES)/Master/nsis.make
