# export compile options for langd with command:
# $ cmake .. -DCMAKE_EXPORT_COMPILE_COMMANDS=1

cmake_minimum_required(VERSION 3.12)
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules)

project(CFNetwork
        VERSION 129.20
        LANGUAGES C CXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED YES)
set(CMAKE_POSITION_INDEPENDENT_CODE YES)

# compile_commands.json
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_THREAD_PREFER_PTHREAD TRUE)
set(THREADS_PREFER_PTHREAD_FLAG OFF)
find_package(Threads REQUIRED)

include (FindPkgConfig)
pkg_check_modules(AVAHI_COMPAT REQUIRED avahi-compat-libdns_sd)
if(AVAHI_COMPAT_FOUND)
  set(CFNETWORK_LDLAGS "${CFNETWORK_LDLAGS} -ldns_sd")
endif()

include(GNUInstallDirs)
include(CoreFoundationAddFramework)

# for getaddrinfo_a
add_compile_definitions($<$<COMPILE_LANGUAGE:C>:_GNU_SOURCE>)
add_compile_definitions($<$<COMPILE_LANGUAGE:C>:HAVE_GETADDRINFO_A>)

add_compile_options($<$<COMPILE_LANGUAGE:C>:-fblocks>)
add_compile_options($<$<COMPILE_LANGUAGE:C>:-Wno-void-pointer-to-int-cast>)
add_compile_options($<$<COMPILE_LANGUAGE:C>:-Wno-pointer-to-int-cast>)
add_compile_options($<$<COMPILE_LANGUAGE:C>:-Wno-int-to-void-pointer-cast>)

add_framework(CFNetwork
                ${FRAMEWORK_LIBRARY_TYPE}
              FRAMEWORK_DIRECTORY
                CFNetwork_FRAMEWORK_DIRECTORY
              PRIVATE_HEADERS
                CFNetworkPriv.h
                # FTP
                FTP/CFFTPStreamPriv.h
                # Host
                Host/CFHostPriv.h
                # HTTP
                HTTP/CFHTTPConnectionPriv.h
                HTTP/CFHTTPMessagePriv.h
                HTTP/CFHTTPServerPriv.h
                HTTP/CFHTTPStreamPriv.h
                HTTP/CFHTTPInternal.h
                HTTP/CFHTTPConnectionInternal.h
                # NetDiagnostics
                NetDiagnostics/CFNetDiagnosticsPriv.h
                # NetServices
                NetServices/CFNetServicesPriv.h
                # Stream
                Stream/CFSocketStreamPriv.h
                # SharedCode
                SharedCode/CFServerPriv.h
                SharedCode/CFNetworkThreadSupport.h
                SharedCode/CFNetworkSchedule.h
                SharedCode/CFNetConnection.h
                # Proxies
                Proxies/ProxySupport.h
              PUBLIC_HEADERS
                AvailabilityMacros.h
                CFNetwork.h
                CFNetworkDefs.h
                # FTP
                FTP/CFFTPStream.h
                # Host
                Host/CFHost.h
                # HTTP
                HTTP/CFHTTPAuthentication.h
                HTTP/CFHTTPMessage.h
                HTTP/CFHTTPStream.h
                # NetDiagnostics
                NetDiagnostics/CFNetDiagnostics.h
                # NetServices
                NetServices/CFNetServices.h
                # Stream
                Stream/CFSocketStream.h
              SOURCES
                CFNetwork.c 
                # SharedCode
                SharedCode/CFServer.c
                SharedCode/CFNetConnection.c
                SharedCode/CFNetworkSchedule.c
                SharedCode/CFNetworkThreadSupport.c
                # Host
                Host/CFHost.c
                # FTP
                FTP/CFFTPStream.c 
                # HTTP
                HTTP/CFHTTPAuthentication.c
                HTTP/CFHTTPConnection.c
                HTTP/CFHTTPFilter.c
                HTTP/CFHTTPMessage.c
                HTTP/CFHTTPServer.c
                HTTP/CFHTTPStream.c
                # NetDiagnostics
                NetDiagnostics/CFNetDiagnosticPing.c
                NetDiagnostics/CFNetDiagnostics.c
                NetDiagnostics/CFNetDiagnosticsProtocolUser.c
                # NetServices
                NetServices/CFNetServices.c
                NetServices/CFNetServiceBrowser.c
                NetServices/CFNetServiceMonitor.c
                NetServices/DeprecatedDNSServiceDiscovery.c
                # Proxies
                Proxies/ProxySupport.c
                # Stream
                Stream/CFSocketStream.c
                Stream/CFStreamError.c
                # URL
                URL/_CFURLAccess.c
                # Unsupported
                #JavaScriptGlue.c
                #libresolv.c
)

if(BUILD_SHARED_LIBS)
  set(FRAMEWORK_LIBRARY_TYPE SHARED)
else()
  set(FRAMEWORK_LIBRARY_TYPE STATIC)
endif()

# Use -DCMAKE_C_FLAGS and -DCMAKE_CXX_FLAGS to specify this
separate_arguments(CFNETWORK_CFLAGS UNIX_COMMAND "${CFNETWORK_CFLAGS}")
target_compile_options(CFNetwork PRIVATE ${CFNETWORK_CFLAGS})

# Use -DCMAKE_SHARED_LINKER_FLAGS to specify this
separate_arguments(CFNETWORK_LDLAGS UNIX_COMMAND "${CFNETWORK_LDLAGS}")
target_link_options(CFNetwork PRIVATE ${CFNETWORK_LDLAGS})

target_include_directories(${PROJECT_NAME}
  PRIVATE
    ${PROJECT_SOURCE_DIR}
    ${CFNetwork_FRAMEWORK_DIRECTORY}
)

target_link_libraries(${PROJECT_NAME}
  PRIVATE
    Threads::Threads
    CoreFoundation)

set_target_properties(${PROJECT_NAME}
  PROPERTIES
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
)

install(
  TARGETS
    CFNetwork
  DESTINATION 
    "${CMAKE_INSTALL_FULL_LIBDIR}"
)

# Needed to avoid double slash "//" when CMAKE_INSTALL_PREFIX set to "/" and DESTDIR used to relocate whole installation.
# Double slash raise CMake error "file called with network path DESTINATION //System/Library/Frameworks".
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

install(DIRECTORY
     ${CFNetwork_FRAMEWORK_DIRECTORY}
   DESTINATION
     ${CMAKE_INSTALL_PREFIX}/Frameworks
   USE_SOURCE_PERMISSIONS
  #  PATTERN PrivateHeaders EXCLUDE
)
