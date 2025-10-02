# Minimal CMakeLists.txt for bundling sonix_native.dll
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "sonix")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "sonix_plugin")

# Create a minimal plugin library
add_library(${PLUGIN_NAME} SHARED
  "sonix_plugin.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# Bundle sonix_native.dll with the plugin
set(sonix_bundled_libraries
  "${CMAKE_CURRENT_SOURCE_DIR}/sonix_native.dll"
  PARENT_SCOPE
)