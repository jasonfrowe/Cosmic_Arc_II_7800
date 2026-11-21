cmake_minimum_required(VERSION 3.20)
project(CosmicArcII
    VERSION 0.1.0
    DESCRIPTION "Cosmic Arc II for the Atari 7800 + AstroCart (7800basic + assembly)"
    LANGUAGES NONE
)

# The build itself is tools/build.sh, which uses the 7800basic vendored in
# tools/7800basic (needs wasmtime on the PATH). CMake runs it when a
# source changes, so "cmake --build build" works.
file(GLOB_RECURSE GAME_SOURCES CONFIGURE_DEPENDS
    ${CMAKE_SOURCE_DIR}/src/*.bas
    ${CMAKE_SOURCE_DIR}/src/asm/*.asm
    ${CMAKE_SOURCE_DIR}/src/gfx/*.png
    ${CMAKE_SOURCE_DIR}/tools/music.py
)

add_custom_command(
    OUTPUT ${CMAKE_SOURCE_DIR}/build/cosmicarc.a78
    COMMAND sh ${CMAKE_SOURCE_DIR}/tools/build.sh
    DEPENDS ${GAME_SOURCES} ${CMAKE_SOURCE_DIR}/tools/build.sh ${CMAKE_SOURCE_DIR}/tools/a78header.py
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Building cosmicarc.a78 with 7800basic"
    VERBATIM
)
add_custom_target(cosmicarc ALL DEPENDS ${CMAKE_SOURCE_DIR}/build/cosmicarc.a78)
