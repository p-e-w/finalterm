
project(finalterm)
cmake_minimum_required(VERSION 2.8)
cmake_policy(VERSION 2.6)
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)


set(DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set(PKGDATADIR "${DATADIR}/finalterm")
set(VERSION 0.1)
set(GETTEXT_PACKAGE "finalterm")
set(CMAKE_C_FLAGS "-ggdb")
set(DOLLAR "$")

configure_file(${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)
configure_file(${CMAKE_SOURCE_DIR}/data/Startup/bash_startup ${CMAKE_BINARY_DIR}/Startup/bash_startup)

set(PKGS clutter-gtk-1.0 mx-1.0 gee-0.8 keybinder-3.0)

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED ${PKGS})

add_definitions(${DEPS_CFLAGS})
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.16.0" MINIMUM)

include(ValaPrecompile)
vala_precompile(VALA_C
	src/FinalTerm.vala
	src/Terminal.vala
	src/TerminalStream.vala
	src/TerminalOutput.vala
	src/CharacterAttributes.vala
	src/TerminalView.vala
	src/LineView.vala
	src/Autocompletion.vala
	src/NotifyingList.vala
	src/ScrollableListView.vala
	src/Utilities.vala
	src/TextMenu.vala
	src/ColorScheme.vala
	src/Theme.vala
	src/KeyBindings.vala
	src/Command.vala
	src/Settings.vala
	src/Metrics.vala
	${CMAKE_BINARY_DIR}/src/Config.vala
PACKAGES
	${PKGS}
	posix
	linux 
OPTIONS
	-g
	--vapidir=${CMAKE_CURRENT_SOURCE_DIR}/vapi/
)

include(GSettings)
add_schema ("data/org.gnome.finalterm.gschema.xml")

add_executable(finalterm ${VALA_C})
target_link_libraries(finalterm m util)

install(TARGETS finalterm RUNTIME DESTINATION bin)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/ColorSchemes DESTINATION share/finalterm)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/KeyBindings DESTINATION share/finalterm)
install(DIRECTORY ${CMAKE_BINARY_DIR}/Startup DESTINATION share/finalterm)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/Termlets DESTINATION share/finalterm USE_SOURCE_PERMISSIONS)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/TextMenus DESTINATION share/finalterm)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/Themes DESTINATION share/finalterm)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/Icons/hicolor DESTINATION share/icons)

