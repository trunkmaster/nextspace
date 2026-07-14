#
# GNUmakefile
#
# Here are the several types of modules (bundles):
#
# Project types:
#	- Aggregate
#	- Application
#	- Bundle
#	- Framework
#	- Library
#	- ResourceSet
#	- Tool
# Editors:
#	- ProjectCenter -- default PC editor
# Parsers:
#	- ObjectiveC -- that's it!
#

PACKAGE_NAME = ProjectCenter
include $(GNUSTEP_MAKEFILES)/common.make

#
# Subprojects
#
SUBPROJECTS = \
        Projects/Aggregate   	\
        Projects/Application 	\
        Projects/Bundle      	\
	Projects/Framework   	\
        Projects/Library     	\
	Projects/ResourceSet 	\
        Projects/Tool        	\
	\
	Editors/ProjectCenter	\
	\
	Parsers/ProjectCenter   \
	\
	Preferences/Build       \
	Preferences/Saving      \
	Preferences/Misc        \
	Preferences/EditorFSC

SUBPROJECTS += Debuggers/ProjectCenter


include $(GNUSTEP_MAKEFILES)/aggregate.make

