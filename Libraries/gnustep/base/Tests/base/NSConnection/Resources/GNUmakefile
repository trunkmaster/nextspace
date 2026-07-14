include $(GNUSTEP_MAKEFILES)/common.make
BUNDLE_NAME=TestConnection
TestConnection_NEEDS_GUI = NO
TestConnection_OBJC_FILES=Connection.m

TEST_TOOL_NAME=Client Server
Client_NEEDS_GUI = NO
Client_OBJC_FILES=Client.m
Server_NEEDS_GUI = NO
Server_OBJC_FILES=Server.m

include $(GNUSTEP_MAKEFILES)/bundle.make
include $(GNUSTEP_MAKEFILES)/test-tool.make

check:: all
