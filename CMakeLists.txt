# CMakeLists.txt file for larutils

#  This simply copies files into an install directory - there is no build

cmake_minimum_required(VERSION 3.19 FATAL_ERROR)

project(larutils LANGUAGES NONE)

# cetbuildtools contains our cmake modules
find_package(cetbuildtools REQUIRED)

include(CetCMakeEnv)

# larutils has no architecture dependence
cet_cmake_env( noarch )

# source code
add_subdirectory(buildScripts)
add_subdirectory(scripts)
add_subdirectory(test)
add_subdirectory(ups)

# packaging utility
include(UseCPack)


