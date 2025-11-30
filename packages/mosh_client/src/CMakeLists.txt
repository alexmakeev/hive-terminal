# MOSH Client FFI Library for Flutter
# CMake 3.10 is required by Flutter tooling
cmake_minimum_required(VERSION 3.10)

project(mosh_client_library VERSION 0.1.0 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Mosh source directory (relative to this CMakeLists.txt)
get_filename_component(MOSH_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../mosh-1.4.0" ABSOLUTE)
set(MOSH_SRC_DIR "${MOSH_ROOT}/src")

# Check if mosh is built
if(NOT EXISTS "${MOSH_SRC_DIR}/network/libmoshnetwork.a")
    message(STATUS "Mosh libraries not found. Building minimal FFI stub...")

    # Build minimal stub without mosh
    add_library(mosh_client SHARED
        "mosh_ffi_stub.c"
    )

    set_target_properties(mosh_client PROPERTIES
        PUBLIC_HEADER mosh_ffi.h
        OUTPUT_NAME "mosh_client"
    )

    target_compile_definitions(mosh_client PUBLIC DART_SHARED_LIB)

else()
    message(STATUS "Building full mosh FFI library...")

    # Find required packages
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(OPENSSL REQUIRED openssl)
    pkg_check_modules(PROTOBUF REQUIRED protobuf)
    pkg_check_modules(NCURSES REQUIRED ncursesw)

    # Mosh include directories
    set(MOSH_INCLUDE_DIRS
        ${MOSH_SRC_DIR}/include
        ${MOSH_SRC_DIR}/crypto
        ${MOSH_SRC_DIR}/network
        ${MOSH_SRC_DIR}/statesync
        ${MOSH_SRC_DIR}/terminal
        ${MOSH_SRC_DIR}/util
        ${MOSH_SRC_DIR}/protobufs
        ${MOSH_ROOT}/src/include
        ${MOSH_ROOT}/src/protobufs
    )

    # Mosh static libraries (order matters for linking)
    set(MOSH_LIBRARIES
        ${MOSH_SRC_DIR}/network/libmoshnetwork.a
        ${MOSH_SRC_DIR}/statesync/libmoshstatesync.a
        ${MOSH_SRC_DIR}/terminal/libmoshterminal.a
        ${MOSH_SRC_DIR}/crypto/libmoshcrypto.a
        ${MOSH_SRC_DIR}/util/libmoshutil.a
        ${MOSH_SRC_DIR}/protobufs/libmoshprotos.a
    )

    # FFI library
    add_library(mosh_client SHARED
        mosh_ffi.cc
    )

    target_include_directories(mosh_client PRIVATE
        ${MOSH_INCLUDE_DIRS}
        ${OPENSSL_INCLUDE_DIRS}
        ${PROTOBUF_INCLUDE_DIRS}
        ${NCURSES_INCLUDE_DIRS}
    )

    target_compile_definitions(mosh_client PRIVATE
        HAVE_CONFIG_H
        DART_SHARED_LIB
    )

    # Link mosh static libraries and system libraries
    target_link_libraries(mosh_client PRIVATE
        ${MOSH_LIBRARIES}
        ${OPENSSL_LIBRARIES}
        ${PROTOBUF_LIBRARIES}
        ${NCURSES_LIBRARIES}
        pthread
    )

    set_target_properties(mosh_client PROPERTIES
        PUBLIC_HEADER mosh_ffi.h
        OUTPUT_NAME "mosh_client"
        C_VISIBILITY_PRESET hidden
        CXX_VISIBILITY_PRESET hidden
    )
endif()

if (ANDROID)
    # Support Android 15 16k page size
    target_link_options(mosh_client PRIVATE "-Wl,-z,max-page-size=16384")
endif()
