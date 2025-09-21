include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(LargeInteger_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(LargeInteger_setup_options)
  option(LargeInteger_ENABLE_HARDENING "Enable hardening" ON)
  option(LargeInteger_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    LargeInteger_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    LargeInteger_ENABLE_HARDENING
    OFF)

  LargeInteger_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR LargeInteger_PACKAGING_MAINTAINER_MODE)
    option(LargeInteger_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(LargeInteger_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(LargeInteger_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(LargeInteger_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(LargeInteger_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(LargeInteger_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(LargeInteger_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(LargeInteger_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(LargeInteger_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(LargeInteger_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(LargeInteger_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(LargeInteger_ENABLE_PCH "Enable precompiled headers" OFF)
    option(LargeInteger_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(LargeInteger_ENABLE_IPO "Enable IPO/LTO" ON)
    option(LargeInteger_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(LargeInteger_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(LargeInteger_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(LargeInteger_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(LargeInteger_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(LargeInteger_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(LargeInteger_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(LargeInteger_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(LargeInteger_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(LargeInteger_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(LargeInteger_ENABLE_PCH "Enable precompiled headers" OFF)
    option(LargeInteger_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      LargeInteger_ENABLE_IPO
      LargeInteger_WARNINGS_AS_ERRORS
      LargeInteger_ENABLE_USER_LINKER
      LargeInteger_ENABLE_SANITIZER_ADDRESS
      LargeInteger_ENABLE_SANITIZER_LEAK
      LargeInteger_ENABLE_SANITIZER_UNDEFINED
      LargeInteger_ENABLE_SANITIZER_THREAD
      LargeInteger_ENABLE_SANITIZER_MEMORY
      LargeInteger_ENABLE_UNITY_BUILD
      LargeInteger_ENABLE_CLANG_TIDY
      LargeInteger_ENABLE_CPPCHECK
      LargeInteger_ENABLE_COVERAGE
      LargeInteger_ENABLE_PCH
      LargeInteger_ENABLE_CACHE)
  endif()

  LargeInteger_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (LargeInteger_ENABLE_SANITIZER_ADDRESS OR LargeInteger_ENABLE_SANITIZER_THREAD OR LargeInteger_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(LargeInteger_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(LargeInteger_global_options)
  if(LargeInteger_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    LargeInteger_enable_ipo()
  endif()

  LargeInteger_supports_sanitizers()

  if(LargeInteger_ENABLE_HARDENING AND LargeInteger_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR LargeInteger_ENABLE_SANITIZER_UNDEFINED
       OR LargeInteger_ENABLE_SANITIZER_ADDRESS
       OR LargeInteger_ENABLE_SANITIZER_THREAD
       OR LargeInteger_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${LargeInteger_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${LargeInteger_ENABLE_SANITIZER_UNDEFINED}")
    LargeInteger_enable_hardening(LargeInteger_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(LargeInteger_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(LargeInteger_warnings INTERFACE)
  add_library(LargeInteger_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  LargeInteger_set_project_warnings(
    LargeInteger_warnings
    ${LargeInteger_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(LargeInteger_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    LargeInteger_configure_linker(LargeInteger_options)
  endif()

  include(cmake/Sanitizers.cmake)
  LargeInteger_enable_sanitizers(
    LargeInteger_options
    ${LargeInteger_ENABLE_SANITIZER_ADDRESS}
    ${LargeInteger_ENABLE_SANITIZER_LEAK}
    ${LargeInteger_ENABLE_SANITIZER_UNDEFINED}
    ${LargeInteger_ENABLE_SANITIZER_THREAD}
    ${LargeInteger_ENABLE_SANITIZER_MEMORY})

  set_target_properties(LargeInteger_options PROPERTIES UNITY_BUILD ${LargeInteger_ENABLE_UNITY_BUILD})

  if(LargeInteger_ENABLE_PCH)
    target_precompile_headers(
      LargeInteger_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(LargeInteger_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    LargeInteger_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(LargeInteger_ENABLE_CLANG_TIDY)
    LargeInteger_enable_clang_tidy(LargeInteger_options ${LargeInteger_WARNINGS_AS_ERRORS})
  endif()

  if(LargeInteger_ENABLE_CPPCHECK)
    LargeInteger_enable_cppcheck(${LargeInteger_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(LargeInteger_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    LargeInteger_enable_coverage(LargeInteger_options)
  endif()

  if(LargeInteger_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(LargeInteger_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(LargeInteger_ENABLE_HARDENING AND NOT LargeInteger_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR LargeInteger_ENABLE_SANITIZER_UNDEFINED
       OR LargeInteger_ENABLE_SANITIZER_ADDRESS
       OR LargeInteger_ENABLE_SANITIZER_THREAD
       OR LargeInteger_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    LargeInteger_enable_hardening(LargeInteger_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
