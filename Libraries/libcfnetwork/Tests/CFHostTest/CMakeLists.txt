cmake_minimum_required(VERSION 3.0.0)
project(CFHostTest VERSION 0.1.0 LANGUAGES C)

#include(CTest)
#enable_testing()

add_executable(CFHostTest 
                gethostbyname.c)

set(CPACK_PROJECT_NAME ${PROJECT_NAME})
set(CPACK_PROJECT_VERSION ${PROJECT_VERSION})
include(CPack)

#add_compile_options($<$<COMPILE_LANGUAGE:C>:-F/usr/NextSpace/Frameworks>)

target_compile_options(${PROJECT_NAME} PRIVATE -F/usr/NextSpace/Frameworks)
target_include_directories(${PROJECT_NAME} PRIVATE
    /usr/NextSpace/include
)

target_link_options(${PROJECT_NAME} PRIVATE -L/usr/NextSpace/lib)
target_link_libraries(${PROJECT_NAME}
  PRIVATE
    CoreFoundation
    CFNetwork)
