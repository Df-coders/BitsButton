cmake_minimum_required(VERSION 3.10)
project(BitsButton LANGUAGES C CXX)

# 默认使用 C11
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# --- Project options (expose common compile-time switches) ---
option(BITS_BTN_DISABLE_BUFFER "Disable built-in buffer (use callback/no internal buffer)" OFF)
option(BITS_BTN_USE_USER_BUFFER "Use user-provided buffer implementation (requires bits_button_set_buffer_ops)" OFF)

# Validate mutually exclusive buffer options
if(BITS_BTN_DISABLE_BUFFER AND BITS_BTN_USE_USER_BUFFER)
    message(FATAL_ERROR "BITS_BTN_DISABLE_BUFFER and BITS_BTN_USE_USER_BUFFER are mutually exclusive. Choose one.")
endif()

# 定义库目标（静态库）
add_library(bits_button STATIC
    bits_button.c
    bits_button.h
)

target_include_directories(bits_button PUBLIC ${CMAKE_SOURCE_DIR})

# Map CMake options to compile definitions for the target
if(BITS_BTN_DISABLE_BUFFER)
    target_compile_definitions(bits_button PUBLIC BITS_BTN_DISABLE_BUFFER)
elseif(BITS_BTN_USE_USER_BUFFER)
    target_compile_definitions(bits_button PUBLIC BITS_BTN_USE_USER_BUFFER)
else()
    # default: use C11 atomic buffer if available (no define needed)
endif()

# 可选构建测试（默认开启）
option(BUILD_TESTS "Build unit tests" ON)
if(BUILD_TESTS)
    include(CTest)
    add_subdirectory(test)
endif()

message(STATUS "BitsButton: top-level CMakeLists ready. BUILD_TESTS=${BUILD_TESTS}")