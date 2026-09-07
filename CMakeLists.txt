cmake_minimum_required(VERSION 3.15)

project(rkllm-eos-repro CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_INSTALL_PREFIX ${CMAKE_SOURCE_DIR}/install)

foreach(ver 1.3.0 1.2.3)
  if(NOT EXISTS "${CMAKE_SOURCE_DIR}/runtime/${ver}/rkllm.h")
    message(FATAL_ERROR "No rkllm.h in runtime/${ver}; run ./build-android.sh")
  endif()

  add_executable(repro-${ver} main.cpp)
  target_include_directories(repro-${ver} PRIVATE runtime/${ver})
  target_link_libraries(repro-${ver} PRIVATE ${CMAKE_SOURCE_DIR}/runtime/${ver}/librkllmrt.so)

  # 1.2.3 rkllm_init takes a bare function pointer, 1.3.0 takes RKLLMCallback*
  if(ver STREQUAL 1.2.3)
    target_compile_definitions(repro-${ver} PRIVATE RKLLM_LEGACY_CALLBACK)
  endif()

  install(TARGETS repro-${ver} DESTINATION ./)
  install(PROGRAMS runtime/${ver}/librkllmrt.so runtime/${ver}/libomp.so DESTINATION lib-${ver})
endforeach()
