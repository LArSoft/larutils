# CMakeLists.txt file for larutils

#  This simply copies files into an install directory - there is no build

cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

find_package(cetmodules REQUIRED)
project(larutils VERSION 1.29.00 LANGUAGES NONE)

include(CetCMakeEnv)

# larutils has no architecture dependence
cet_cmake_env( noarch )

# source code
add_subdirectory(buildScripts)
add_subdirectory(scripts)

cet_cmake_config(NO_CMAKE_CONFIG)


