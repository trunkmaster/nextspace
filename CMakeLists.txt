cmake_minimum_required(VERSION 3.16)

project(libobjc C ASM CXX)

if (NOT "${CMAKE_C_COMPILER_ID}" MATCHES Clang*)
	message(WARNING "WARNING: It is strongly recommended that you compile with clang")
elseif (WIN32 AND "${CMAKE_C_COMPILER_FRONTEND_VARIANT}" STREQUAL "MSVC")
	message(WARNING "WARNING: It is strongly recommended that you compile with clang (clang-cl is not supported)")
endif()

# fix up CMake Objective-C compiler detection on Windows before enabling languages below
if (WIN32)
	foreach(lang IN ITEMS C CXX)
		set(CMAKE_OBJ${lang}_COMPILER_FORCED ON)
		foreach(runtimeLibrary IN ITEMS MultiThreaded MultiThreadedDLL MultiThreadedDebug MultiThreadedDebugDLL)
			set(CMAKE_OBJ${lang}_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_${runtimeLibrary} ${CMAKE_${lang}_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY_${runtimeLibrary}})
		endforeach()
	endforeach()
endif()

enable_language(OBJC OBJCXX)

if (MINGW)
	# Make sure ObjC++ source code uses the C++ implicit include directories.  This is needed, for example, to make sure we use the right
	# C++ headers when using clang but linking with libstdc++.
	set(CMAKE_OBJCXX_IMPLICIT_INCLUDE_DIRECTORIES ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES})
endif ()

INCLUDE (CheckCXXSourceCompiles)
INCLUDE (FetchContent)
INCLUDE (CheckSymbolExists)

set(libobjc_VERSION 4.6)


if (MSVC)
	set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /EHas")
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /EHas")
	set(CMAKE_C_FLAGS_DEBUG "/Z7 ${CMAKE_C_FLAGS_DEBUG}")
	set(CMAKE_SHARED_LINKER_FLAGS "/DEBUG /INCREMENTAL:NO ${CMAKE_SHARED_LINKER_FLAGS}")
	set(CMAKE_EXE_LINKER_FLAGS "/DEBUG /INCREMENTAL:NO ${CMAKE_EXE_LINKER_FLAGS}")
	set(objc_LINK_FLAGS "/DEBUG /INCREMENTAL:NO ${objc_LINK_FLAGS}")
endif()

message(STATUS "Architecture as detected by CMake: ${CMAKE_SYSTEM_PROCESSOR}")

# Build configuration
add_compile_definitions(GNUSTEP __OBJC_RUNTIME_INTERNAL__=1 __OBJC_BOOL)

set(CMAKE_CXX_STANDARD 17)

set(libobjc_ASM_SRCS 
	block_trampolines.S
	objc_msgSend.S)
set(libobjc_OBJCXX_SRCS 
	arc.mm
	)
set(libobjc_OBJC_SRCS 
	NSBlocks.m
	associate.m
	blocks_runtime_np.m
	properties.m)
set(libobjc_C_SRCS 
	alias_table.c
	block_to_imp.c
	builtin_classes.c
	caps.c
	category_loader.c
	class_table.c
	dtable.c
	encoding2.c
	gc_none.c
	hooks.c
	ivar.c
	loader.c
	mutation.m
	protocol.c
	runtime.c
	sarray2.c
	sendmsg2.c
	fast_paths.m
	)
set(libobjc_HDRS
	objc/Availability.h
	objc/Object.h
	objc/Protocol.h
	objc/capabilities.h
	objc/developer.h
	objc/encoding.h
	objc/hooks.h
	objc/message.h
	objc/objc-api.h
	objc/objc-arc.h
	objc/objc-auto.h
	objc/objc-class.h
	objc/objc-exception.h
	objc/objc-runtime.h
	objc/objc-visibility.h
	objc/objc.h
	objc/runtime-deprecated.h
	objc/runtime.h
	objc/slot.h
	${PROJECT_BINARY_DIR}/objc/objc-config.h)

set(libobjc_CXX_SRCS
	selector_table.cc
	)
# Windows does not use DWARF EH, except when using the GNU ABI (MinGW)
if (WIN32 AND NOT MINGW)
	list(APPEND libobjc_CXX_SRCS eh_win32_msvc.cc)
elseif (NOT MINGW)
	list(APPEND libobjc_C_SRCS eh_personality.c)
endif ()

find_package(tsl-robin-map)

if (NOT tsl-robin-map_FOUND)
	FetchContent_Declare(
		robinmap
		GIT_REPOSITORY https://github.com/Tessil/robin-map/
		GIT_TAG        v1.4.0)

	FetchContent_MakeAvailable(robinmap)
endif()

if (WIN32)
	set(OLD_ABI_COMPAT_DEFAULT false)
else()
	set(OLD_ABI_COMPAT_DEFAULT true)
endif()

option(TYPE_DEPENDENT_DISPATCH "Enable type-dependent dispatch" ON)
option(ENABLE_TRACING 
	"Enable tracing support (slower, not recommended for deployment)" OFF)
option(OLDABI_COMPAT 
	"Enable compatibility with GCC and old GNUstep ABIs"
	${OLD_ABI_COMPAT_DEFAULT})
option(LEGACY_COMPAT "Enable legacy compatibility features" OFF)
option(DEBUG_ARC_COMPAT
	"Log warnings for classes that don't hit ARC fast paths" OFF)
option(ENABLE_OBJCXX "Enable support for Objective-C++" ON)
option(TESTS "Enable building the tests")
option(EMBEDDED_BLOCKS_RUNTIME "Include an embedded blocks runtime, rather than relying on libBlocksRuntime to supply it" ON)
option(STRICT_APPLE_COMPATIBILITY "Use strict Apple compatibility, always defining BOOL as signed char" OFF)

# For release builds, we disable spamming the terminal with warnings about
# selector type mismatches
add_compile_definitions($<$<CONFIG:Release>:NO_SELECTOR_MISMATCH_WARNINGS>)
add_compile_definitions($<$<BOOL:${TYPE_DEPENDENT_DISPATCH}>:TYPE_DEPENDENT_DISPATCH>)
add_compile_definitions($<$<BOOL:${ENABLE_TRACING}>:WITH_TRACING=1>)
add_compile_definitions($<$<BOOL:${DEBUG_ARC_COMPAT}>:DEBUG_ARC_COMPAT>)
add_compile_definitions($<$<BOOL:${STRICT_APPLE_COMPATIBILITY}>:STRICT_APPLE_COMPATIBILITY>)

configure_file(objc/objc-config.h.in objc/objc-config.h @ONLY)
include_directories("${PROJECT_BINARY_DIR}/objc/")

if (OLDABI_COMPAT)
	list(APPEND libobjc_C_SRCS legacy.c abi_version.c statics_loader.c)
	add_definitions(-DOLDABI_COMPAT=1)
endif()

if (LEGACY_COMPAT)
	list(APPEND libobjc_C_SRCS legacy_malloc.c)
else ()
	add_definitions(-DNO_LEGACY)
endif ()

set(LIBOBJC_NAME "objc" CACHE STRING 
	"Name of the Objective-C runtime library (e.g. objc2 for libobjc2)")

set(INCLUDE_DIRECTORY "objc" CACHE STRING 
	"Subdirectory of the include path to install the headers.")

add_compile_options($<$<STREQUAL:${CMAKE_SYSTEM_PROCESSOR},i686>:-march=i586>)

# PowerPC 32-bit does not support native 64-bit atomic operations,
# which is used in safe caching.
# You must also update the guard in objc/runtime.h, when updating
# this macro.
if (CMAKE_SYSTEM_PROCESSOR STREQUAL "ppc" OR CMAKE_SYSTEM_PROCESSOR STREQUAL "ppcle")
	add_definitions(-DNO_SAFE_CACHING)
endif()

set(INSTALL_TARGETS objc)

if(WIN32)
	if(CMAKE_SIZEOF_VOID_P EQUAL 8)
		set(ASM_TARGET -m64)
	else()
		set(ASM_TARGET -m32)
	endif()
endif()


if (WIN32 AND NOT MINGW)
	set(ASSEMBLER ${CMAKE_ASM_COMPILER} CACHE STRING "Assembler to use with Visual Studio (must be gcc / clang!)")
	message(STATUS "Using custom build commands to work around CMake bugs")
	message(STATUS "ASM compiler: ${ASSEMBLER}")
	# CMake is completely broken when you try to build assembly files on Windows.
	add_custom_command(OUTPUT block_trampolines.obj
		COMMAND echo ${ASSEMBLER} ${ASM_TARGET} -c "${CMAKE_SOURCE_DIR}/block_trampolines.S" -o "${CMAKE_BINARY_DIR}/block_trampolines.obj"
		COMMAND ${ASSEMBLER} ${ASM_TARGET} -c "${CMAKE_SOURCE_DIR}/block_trampolines.S" -o "${CMAKE_BINARY_DIR}/block_trampolines.obj"
		MAIN_DEPENDENCY block_trampolines.S
	)
	add_custom_command(OUTPUT objc_msgSend.obj
		COMMAND echo ${ASSEMBLER} ${ASM_TARGET} -c "${CMAKE_SOURCE_DIR}/objc_msgSend.S" -o "${CMAKE_BINARY_DIR}/objc_msgSend.obj"
		COMMAND ${ASSEMBLER} ${ASM_TARGET} -c "${CMAKE_SOURCE_DIR}/objc_msgSend.S" -o "${CMAKE_BINARY_DIR}/objc_msgSend.obj"
		MAIN_DEPENDENCY objc_msgSend.S
		DEPENDS objc_msgSend.aarch64.S objc_msgSend.arm.S objc_msgSend.mips.S objc_msgSend.x86-32.S objc_msgSend.x86-64.S
	)
	set(libobjc_ASM_OBJS block_trampolines.obj objc_msgSend.obj)
endif()



if (WIN32 AND NOT MINGW)
	message(STATUS "Using MSVC-compatible exception model")
elseif (MINGW)
	message(STATUS "Using MinGW-compatible exception model")
	list(APPEND libobjc_CXX_SRCS objcxx_eh.cc objcxx_eh_mingw.cc)
else ()
	set(EH_PERSONALITY_FLAGS "")
	if (CMAKE_CXX_COMPILER_TARGET)
		list(APPEND EH_PERSONALITY_FLAGS "${CMAKE_CXX_COMPILE_OPTIONS_TARGET}${CMAKE_CXX_COMPILER_TARGET}")
	endif ()
	add_custom_command(OUTPUT eh_trampoline.S
		COMMAND ${CMAKE_CXX_COMPILER} ARGS ${EH_PERSONALITY_FLAGS} -fPIC -S "${CMAKE_SOURCE_DIR}/eh_trampoline.cc" -o - -fexceptions -fno-inline | sed "s/__gxx_personality_v0/test_eh_personality/g" > "${CMAKE_BINARY_DIR}/eh_trampoline.S"
		MAIN_DEPENDENCY eh_trampoline.cc)
	list(APPEND libobjc_ASM_SRCS eh_trampoline.S)
	list(APPEND libobjc_CXX_SRCS objcxx_eh.cc)
	# Find libm for linking, as some versions of libc++ don't link against it
	find_library(M_LIBRARY m)
endif ()

if (EMBEDDED_BLOCKS_RUNTIME)
	set(libBlocksRuntime_COMPATIBILITY_HDRS
		Block.h
		Block_private.h
		)
	list(APPEND libobjc_OBJC_SRCS blocks_runtime.m)
	list(APPEND libobjc_HDRS objc/blocks_private.h)
	list(APPEND libobjc_HDRS objc/blocks_runtime.h)
	add_definitions(-DEMBEDDED_BLOCKS_RUNTIME)
else ()
	find_library(BLOCKS_RUNTIME_LIBRARY BlocksRuntime)
	if (BLOCKS_RUNTIME_LIBRARY)
		set(CMAKE_REQUIRED_LIBRARIES ${BLOCKS_RUNTIME_LIBRARY})
		check_symbol_exists(_Block_use_RR2 "Block_private.h" HAVE_BLOCK_USE_RR2)
		if (HAVE_BLOCK_USE_RR2)
			add_definitions(-DHAVE_BLOCK_USE_RR2)
		else ()
			message(FATAL_ERROR "libBlocksRuntime does not contain _Block_use_RR2(). Enable EMBEDDED_BLOCKS_RUNTIME to use the built-in blocks runtime.")
		endif ()
		unset(CMAKE_REQUIRED_LIBRARIES)
	else ()
		message(FATAL_ERROR "libBlocksRuntime not found. Enable EMBEDDED_BLOCKS_RUNTIME to use the built-in blocks runtime.")
	endif ()
endif ()

add_library(objc SHARED ${libobjc_C_SRCS} ${libobjc_ASM_SRCS} ${libobjc_OBJC_SRCS} ${libobjc_OBJCXX_SRCS} ${libobjc_ASM_OBJS})
target_compile_options(objc PRIVATE "$<$<OR:$<COMPILE_LANGUAGE:OBJC>,$<COMPILE_LANGUAGE:OBJCXX>>:-Wno-gnu-folding-constant;-Wno-deprecated-objc-isa-usage;-Wno-objc-root-class;-fobjc-runtime=gnustep-2.0>$<$<COMPILE_LANGUAGE:C>:-Xclang;-fexceptions;-Wno-gnu-folding-constant>")

list(APPEND libobjc_CXX_SRCS ${libobjcxx_CXX_SRCS})
target_sources(objc PRIVATE ${libobjc_CXX_SRCS})

include(FindThreads)
target_link_libraries(objc PUBLIC Threads::Threads)
# Link against ntdll.dll for RtlRaiseException
if (WIN32 AND NOT MINGW)
	target_link_libraries(objc PUBLIC ntdll.dll)
endif()

target_link_libraries(objc PRIVATE tsl::robin_map)

set_target_properties(objc PROPERTIES
	LINKER_LANGUAGE C
	SOVERSION ${libobjc_VERSION}
	OUTPUT_NAME ${LIBOBJC_NAME}
	LINK_FLAGS "${objc_LINK_FLAGS}"
	)

set_property(TARGET PROPERTY NO_SONAME true)

option(BUILD_STATIC_LIBOBJC "Build the static version of libobjc" OFF)
if (BUILD_STATIC_LIBOBJC)
	add_library(objc-static STATIC ${libobjc_C_SRCS} ${libobjc_ASM_SRCS} ${libobjc_OBJC_SRCS} ${libobjc_CXX_SRCS})
	set_target_properties(objc-static PROPERTIES
		POSITION_INDEPENDENT_CODE true
		OUTPUT_NAME ${LIBOBJC_NAME})
	list(APPEND INSTALL_TARGETS objc-static)
endif ()

# Explicitly link libm, as an implicit dependency of the C++ runtime
if (M_LIBRARY)
	target_link_libraries(objc PUBLIC ${M_LIBRARY})
endif ()

if (BLOCKS_RUNTIME_LIBRARY)
	target_link_libraries(objc PUBLIC ${BLOCKS_RUNTIME_LIBRARY})
endif ()

# Make weak symbols work on OS X
if (APPLE)
	set(CMAKE_SHARED_LIBRARY_CREATE_C_FLAGS
		"${CMAKE_SHARED_LIBRARY_CREATE_C_FLAGS} -undefined dynamic_lookup")
	set(CMAKE_C_LINK_FLAGS "${CMAKE_C_LINK_FLAGS} -Wl,-undefined,dynamic_lookup")
	set(CMAKE_CXX_LINK_FLAGS "${CMAKE_CXX_LINK_FLAGS} -Wl,-undefined,dynamic_lookup")
endif ()

#
# Installation
#


find_program(GNUSTEP_CONFIG gnustep-config)
if (GNUSTEP_CONFIG)
	execute_process(
        COMMAND ${GNUSTEP_CONFIG} --installation-domain-for=libobjc2
		OUTPUT_VARIABLE DEFAULT_INSTALL_TYPE
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
endif ()


# If we have GNUstep environment variables, then default to installing in the
# GNUstep local environment.
if (DEFAULT_INSTALL_TYPE)
else ()
	set(DEFAULT_INSTALL_TYPE "NONE")
endif ()

if (NOT CMAKE_INSTALL_LIBDIR)
	set(CMAKE_INSTALL_LIBDIR lib)
endif ()

if (NOT CMAKE_INSTALL_BINDIR)
	set(CMAKE_INSTALL_BINDIR bin)
endif ()

set(GNUSTEP_INSTALL_TYPE ${DEFAULT_INSTALL_TYPE} CACHE STRING
	"GNUstep installation type.  Options are NONE, SYSTEM, NETWORK or LOCAL.")
if (${GNUSTEP_INSTALL_TYPE} STREQUAL "NONE")
	SET(LIB_INSTALL_PATH "${CMAKE_INSTALL_LIBDIR}" CACHE STRING
		"Subdirectory of the root prefix where libraries are installed.")
	SET(BIN_INSTALL_PATH "${CMAKE_INSTALL_BINDIR}" CACHE STRING
		"Subdirectory of the root prefix where libraries are installed.")
	SET(HEADER_INSTALL_PATH "include")
	SET(PC_INSTALL_PREFIX ${CMAKE_INSTALL_PREFIX})
else ()
	execute_process(
        COMMAND ${GNUSTEP_CONFIG} --variable=GNUSTEP_${GNUSTEP_INSTALL_TYPE}_LIBRARIES
		OUTPUT_VARIABLE LIB_INSTALL_PATH
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    execute_process(
        COMMAND ${GNUSTEP_CONFIG} --variable=GNUSTEP_${GNUSTEP_INSTALL_TYPE}_LIBRARIES
		OUTPUT_VARIABLE BIN_INSTALL_PATH
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    execute_process(
        COMMAND ${GNUSTEP_CONFIG} --variable=GNUSTEP_${GNUSTEP_INSTALL_TYPE}_HEADERS
		OUTPUT_VARIABLE HEADER_INSTALL_PATH
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
	SET(PC_INSTALL_PREFIX "/")
endif ()
message(STATUS "GNUstep install type set to ${GNUSTEP_INSTALL_TYPE}")

target_include_directories(
	objc
	INTERFACE
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:include>)
install(TARGETS ${INSTALL_TARGETS}
	EXPORT libobjcTargets
	RUNTIME DESTINATION ${BIN_INSTALL_PATH}
	LIBRARY DESTINATION ${LIB_INSTALL_PATH}
	ARCHIVE DESTINATION ${LIB_INSTALL_PATH})

install(FILES ${libobjc_HDRS}
	DESTINATION "${HEADER_INSTALL_PATH}/${INCLUDE_DIRECTORY}")

if (EMBEDDED_BLOCKS_RUNTIME)
	install(FILES ${libBlocksRuntime_COMPATIBILITY_HDRS}
		DESTINATION "${HEADER_INSTALL_PATH}")
endif ()


set(CPACK_GENERATOR TGZ CACHE STRING
	"Installer types to generate.  Sensible options include TGZ, RPM and DEB")

set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "GNUstep Objective-C Runtime")
set(CPACK_PACKAGE_VENDOR "The GNUstep Project")
set(CPACK_PACKAGE_DESCRIPTION_FILE "${CMAKE_CURRENT_SOURCE_DIR}/README.md")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/COPYING")
set(CPACK_PACKAGE_VERSION_MAJOR "2")
set(CPACK_PACKAGE_VERSION_MINOR "2")
set(CPACK_PACKAGE_VERSION_PATCH "0")
set(CPACK_PACKAGE_CONTACT "GNUstep Developer <gnustep-dev@gnu.org>")
set(CPACK_PACKAGE_INSTALL_DIRECTORY "CMake ${CMake_VERSION_MAJOR}.${CMake_VERSION_MINOR}")
if (UNIX)
	set(CPACK_STRIP_FILES true CACHE BOOL "Strip libraries when packaging")
endif ()
include (CPack)

# CMake Configuration File

install(EXPORT libobjcTargets
	FILE libobjcTargets.cmake
	DESTINATION ${LIB_INSTALL_PATH}/cmake/libobjc)
include(CMakePackageConfigHelpers)
configure_package_config_file(${CMAKE_CURRENT_SOURCE_DIR}/Config.cmake.in
	"${CMAKE_CURRENT_BINARY_DIR}/libobjcConfig.cmake"
	INSTALL_DESTINATION "${LIB_INSTALL_PATH}/cmake/libobjc"
	NO_SET_AND_CHECK_MACRO
	NO_CHECK_REQUIRED_COMPONENTS_MACRO)
write_basic_package_version_file(
	"${CMAKE_CURRENT_BINARY_DIR}/libobjcConfigVersion.cmake"
	VERSION "${CPACK_PACKAGE_VERSION_MAJOR}.${CPACK_PACKAGE_VERSION_MINOR}"
	COMPATIBILITY AnyNewerVersion)
install(FILES
	${CMAKE_CURRENT_BINARY_DIR}/libobjcConfig.cmake
	${CMAKE_CURRENT_BINARY_DIR}/libobjcConfigVersion.cmake
	DESTINATION ${LIB_INSTALL_PATH}/cmake/libobjc)

# pkg-config descriptor

set(PC_LIBS_PRIVATE ${CMAKE_CXX_IMPLICIT_LINK_LIBRARIES})
if (M_LIBRARY)
	list(APPEND PC_LIBS_PRIVATE ${M_LIBRARY})
endif ()
if (BLOCKS_RUNTIME_LIBRARY)
	list(APPEND PC_LIBS_PRIVATE ${BLOCKS_RUNTIME_LIBRARY})
endif ()
list(REMOVE_DUPLICATES PC_LIBS_PRIVATE)
string(REPLACE  ";" " -l" PC_LIBS_PRIVATE "${PC_LIBS_PRIVATE}")
set(PC_LIBS_PRIVATE "Libs.private: -l${PC_LIBS_PRIVATE}")

configure_file("libobjc.pc.in" "libobjc.pc" @ONLY)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/libobjc.pc"
	DESTINATION "${LIB_INSTALL_PATH}/pkgconfig"
)


# uninstall target
configure_file(
	"${CMAKE_CURRENT_SOURCE_DIR}/cmake_uninstall.cmake.in"
	"${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
	IMMEDIATE @ONLY)

add_custom_target(uninstall
	COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)

if (TESTS)
	enable_testing()
	add_subdirectory(Test)
endif (TESTS)

CHECK_CXX_SOURCE_COMPILES("
	#include <stdlib.h>
	extern \"C\" {
	__attribute__((weak))
	void *__cxa_allocate_exception(size_t thrown_size) noexcept;
	}
	#include <exception>
	int main() { return 0; }" CXA_ALLOCATE_EXCEPTION_NOEXCEPT_COMPILES)

add_compile_definitions($<IF:$<BOOL:${CXA_ALLOCATE_EXCEPTION_NOEXCEPT_COMPILES}>,CXA_ALLOCATE_EXCEPTION_SPECIFIER=noexcept,CXA_ALLOCATE_EXCEPTION_SPECIFIER>)
