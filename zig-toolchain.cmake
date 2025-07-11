# zig-toolchain.cmake

# One of these may be passed on the CLI:
#   -DTARGET=x86_64-linux-gnu
#   -DTARGET=x86_64-windows-gnu
#   -DTARGET=aarch64-apple-darwin

# Grab host info (already populated by CMake) e.g. Linux, Darwin, or Windows
message(STATUS "Host system: ${CMAKE_HOST_SYSTEM_NAME}/${CMAKE_HOST_SYSTEM_PROCESSOR}")

# Only set TARGET if the user didn't supply -DTARGET=…
if(NOT DEFINED TARGET)
    # Lowercase the host OS for a triple suffix
    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
        set(_os linux-gnu)
    elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
        set(_os apple-darwin)
    elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        set(_os windows-gnu)
    else()
        message(FATAL_ERROR "Unsupported host: ${CMAKE_HOST_SYSTEM_NAME}")
    endif()

    # Lowercase the CPU
    string(TOLOWER "${CMAKE_HOST_SYSTEM_PROCESSOR}" _host_arch_lc)

    # Normalize CPU to Zig’s preferred names
    if(_host_arch_lc MATCHES "^(amd64|x86_64)$")
        set(_arch x86_64)
    elseif(_host_arch_lc MATCHES "^(arm64|aarch64)$")
        set(_arch aarch64)
    else()
        message(FATAL_ERROR
                "Unrecognized host CPU: ${CMAKE_HOST_SYSTEM_PROCESSOR}. "
                "Please pass -DTARGET=<triple> explicitly."
        )
    endif()

    # Build and cache the default triple
    set(TARGET "${_arch}-${_os}"
            CACHE STRING "Target triple for Zig (user may override with -DTARGET=…)" )
    message(STATUS "Defaulting TARGET to ${TARGET}")
endif()

# Parse the triple to pick the CMake SYSTEM
string(REGEX MATCH "windows" _is_win "${TARGET}")
string(REGEX MATCH "darwin|apple" _is_mac "${TARGET}")
if(_is_win)
    set(CMAKE_SYSTEM_NAME Windows CACHE INTERNAL "")
elseif(_is_mac)
    set(CMAKE_SYSTEM_NAME Darwin CACHE INTERNAL "")
else()
    set(CMAKE_SYSTEM_NAME Linux CACHE INTERNAL "")
endif()

# Always set the target CPU from the triple prefix (could parse "${TARGET}" further to get arm vs. x86)
if(${TARGET} MATCHES "^aarch64")
    set(CMAKE_SYSTEM_PROCESSOR aarch64 CACHE INTERNAL "")
else()
    set(CMAKE_SYSTEM_PROCESSOR x86_64 CACHE INTERNAL "")
endif()




# — only if we’re targeting Windows (native or cross-compile) —
if (CMAKE_SYSTEM_NAME STREQUAL "Windows")

    # 1) Figure out where the Windows 10 SDK is installed.
    #    If you’re in an MSVC env, Visual Studio sets this for you:
    if(DEFINED ENV{WindowsSdkDir})
        set(_WINSDK_ROOT "$ENV{WindowsSdkDir}")
    else()
        message(FATAL_ERROR
                "WindowsSdkDir environment variable not set; please install the "
                "Windows 10 SDK or set WindowsSdkDir yourself.")
    endif()

    # 2) Pick the highest-version subfolder under Include/
    file(GLOB _win_inc_dirs "${_WINSDK_ROOT}/Include/*")
    list(SORT _win_inc_dirs)
    list(GET _win_inc_dirs -1 _LATEST_SDK_DIR)
    get_filename_component(_WINSDK_VER ${_LATEST_SDK_DIR} NAME)
    message(STATUS "Using Windows SDK ${_WINSDK_VER} from ${_WINSDK_ROOT}")

    # 3) Globally add the SDK’s um, shared, winrt and ucrt folders
    include_directories(
            SYSTEM
            "${_WINSDK_ROOT}/Include/${_WINSDK_VER}/um"
            "${_WINSDK_ROOT}/Include/${_WINSDK_VER}/shared"
            "${_WINSDK_ROOT}/Include/${_WINSDK_VER}/winrt"
            "${_WINSDK_ROOT}/Include/${_WINSDK_VER}/ucrt"
    )

endif()




# Use Zig for everything
set(CMAKE_C_COMPILER zig cc CACHE INTERNAL "")
set(CMAKE_CXX_COMPILER zig c++ CACHE INTERNAL "")

# Tell Zig which triple to emit
set(CMAKE_C_COMPILER_TARGET ${TARGET} CACHE INTERNAL "")
set(CMAKE_CXX_COMPILER_TARGET ${TARGET} CACHE INTERNAL "")

# Cross-compile mode tweaks
set(CMAKE_CROSSCOMPILING TRUE CACHE INTERNAL "")
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY CACHE INTERNAL "")

# A Zig build should probably use the dependency fetch script by default
set(DAWN_FETCH_DEPENDENCIES ON CACHE BOOL "Use fetch_dawn_dependencies.py as an alternative to using depot_tools")

# This is unnecessary even on Windows, and not building it is easier
set(DAWN_USE_WINDOWS_UI OFF CACHE BOOL "Enable support for Windows UI surface")

# Get some compiler details so that CMake can hopefully skip a bunch of tests that give non-fatal error output clutter
#find_program(ZIG_BIN zig)
#if(ZIG_BIN)
#    execute_process(COMMAND ${ZIG_BIN} c++ --version OUTPUT_VARIABLE _zig_cxx_out OUTPUT_STRIP_TRAILING_WHITESPACE)
#    string(REGEX REPLACE ".*clang version ([0-9]+\\.[0-9]+\\.[0-9]+).*" "\\1" _clang_ver "${_zig_cxx_out}")
#    message(STATUS "Detected Clang version: ${_clang_ver}")
#    set(CMAKE_C_COMPILER_ID "Clang" CACHE STRING "" FORCE)
#    set(CMAKE_CXX_COMPILER_ID "Clang" CACHE STRING "" FORCE)
#    set(CMAKE_C_COMPILER_VERSION "${_clang_ver}" CACHE STRING "" FORCE)
#    set(CMAKE_CXX_COMPILER_VERSION "${_clang_ver}" CACHE STRING "" FORCE)
#    set(CMAKE_C_COMPILER_WORKS TRUE CACHE INTERNAL "" FORCE)
#    set(CMAKE_CXX_COMPILER_WORKS TRUE CACHE INTERNAL "" FORCE)
#
#    set(CMAKE_C_STANDARD_COMPUTED_DEFAULT      11    CACHE INTERNAL "" FORCE)
#    set(CMAKE_C_EXTENSIONS_COMPUTED_DEFAULT    ON    CACHE INTERNAL "" FORCE)
#    set(CMAKE_CXX_STANDARD_COMPUTED_DEFAULT    17    CACHE INTERNAL "" FORCE)
#    set(CMAKE_CXX_EXTENSIONS_COMPUTED_DEFAULT  ON    CACHE INTERNAL "" FORCE)
#
#    set(CMAKE_C_COMPILER_LOADED   TRUE CACHE INTERNAL "" FORCE)
#    set(CMAKE_CXX_COMPILER_LOADED TRUE CACHE INTERNAL "" FORCE)
#endif()
