project(finalterm C)
cmake_minimum_required(VERSION 2.8)
cmake_policy(VERSION 2.6)
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)

option(MINIMAL_FLAGS "Respect system flags as much as possible" OFF)

set(DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set(PKGDATADIR "${DATADIR}/finalterm")
set(VERSION 0.1)
set(GETTEXT_PACKAGE "finalterm")
set(LOCALE_DIR "${DATADIR}/locale")
set(VALAFLAGS "")
if (NOT MINIMAL_FLAGS)
	set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ggdb")
endif (NOT MINIMAL_FLAGS)

find_program(BASHEXE bash /bin /usr/bin /usr/local/bin)
if(NOT DEFINED BASHEXE)
	set(BASHEXE "/bin/bash")
endif(NOT DEFINED BASHEXE)
configure_file(${CMAKE_SOURCE_DIR}/data/Startup/bash_startup.in ${CMAKE_BINARY_DIR}/Startup/bash_startup @ONLY)
configure_file(${CMAKE_SOURCE_DIR}/data/Startup/preexec.bash.in ${CMAKE_BINARY_DIR}/Startup/preexec.bash @ONLY)
configure_file(${CMAKE_SOURCE_DIR}/data/Termlets/bash/ps.in ${CMAKE_BINARY_DIR}/Termlets/bash/ps @ONLY)
configure_file(${CMAKE_SOURCE_DIR}/data/Termlets/bash/ls.in ${CMAKE_BINARY_DIR}/Termlets/bash/ls @ONLY)
configure_file(${CMAKE_SOURCE_DIR}/data/Termlets/bash/wget.in ${CMAKE_BINARY_DIR}/Termlets/bash/wget @ONLY)

find_program(ZSHEXE zsh /bin /usr/bin /usr/local/bin)
if(NOT DEFINED ZSHEXE)
	set(ZSHEXE "/usr/bin/zsh")
endif(NOT DEFINED ZSHEXE)
configure_file(${CMAKE_SOURCE_DIR}/data/Startup/zsh_startup.in ${CMAKE_BINARY_DIR}/Startup/zsh_startup @ONLY)
configure_file(${CMAKE_SOURCE_DIR}/data/Termlets/zsh/ps.in ${CMAKE_BINARY_DIR}/Termlets/zsh/ps @ONLY)
configure_file(${CMAKE_SOURCE_DIR}/data/Termlets/zsh/ls.in ${CMAKE_BINARY_DIR}/Termlets/zsh/ls @ONLY)
configure_file(${CMAKE_SOURCE_DIR}/data/Termlets/zsh/wget.in ${CMAKE_BINARY_DIR}/Termlets/zsh/wget @ONLY)

set(PKGS clutter-gtk-1.0 mx-1.0 keybinder-3.0 gee-0.8)

find_package(PkgConfig)

# see if we got libunity
pkg_check_modules(UNITY unity)
if (UNITY_FOUND)
	set(VALAFLAGS ${VALAFLAGS}
		--define=HAS_UNITY)
	set(PKGS ${PKGS}
		unity)
endif (UNITY_FOUND)

# see if we got libnotify
pkg_check_modules(NOTIFY libnotify)
if (NOTIFY_FOUND)
	set(VALAFLAGS ${VALAFLAGS}
		--define=HAS_NOTIFY)
	set(PKGS ${PKGS}
		libnotify)
endif (NOTIFY_FOUND)

pkg_check_modules(DEPS REQUIRED ${PKGS})
add_definitions(${DEPS_CFLAGS})
add_definitions(-DPKGDATADIR=\"${PKGDATADIR}\")
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
add_definitions(-DLOCALE_DIR=\"${LOCALE_DIR}\")
add_definitions(-DVERSION=\"${VERSION}\")
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
	src/TerminalWidget.vala
	src/NestingContainer.vala
	src/Autocompletion.vala
	src/NotifyingList.vala
	src/ScrollableListView.vala
	src/Utilities.vala
	src/SettingsWindow.vala
	src/TextMenu.vala
	src/ColorScheme.vala
	src/Theme.vala
	src/KeyBindings.vala
	src/Command.vala
	src/Settings.vala
	src/Metrics.vala
PACKAGES
	${PKGS}
	posix
	linux
	Config
OPTIONS
	-g
	--vapidir=${CMAKE_CURRENT_SOURCE_DIR}/vapi/
	${VALAFLAGS}
)

add_subdirectory (po)

include(GSettings)
add_schema ("data/org.gnome.finalterm.gschema.xml")

include(Common)
datestring(DATE "%B %Y")
configure_file(${CMAKE_SOURCE_DIR}/data/finalterm.1.in ${CMAKE_BINARY_DIR}/data/finalterm.1)
install(FILES ${CMAKE_BINARY_DIR}/data/finalterm.1 DESTINATION share/man/man1)

add_executable(finalterm ${VALA_C})
target_link_libraries(finalterm m util)

install(TARGETS finalterm RUNTIME DESTINATION bin)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/ColorSchemes DESTINATION share/finalterm)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/KeyBindings DESTINATION share/finalterm)
install(DIRECTORY ${CMAKE_BINARY_DIR}/Startup DESTINATION share/finalterm)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/Startup/zsh_functions DESTINATION share/finalterm/Startup)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/TerminalCommands DESTINATION share/finalterm)
install(DIRECTORY ${CMAKE_BINARY_DIR}/Termlets DESTINATION share/finalterm FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/TextMenus DESTINATION share/finalterm)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/Themes DESTINATION share/finalterm)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/Icons/hicolor DESTINATION share/icons)

add_custom_target(uninstall
	COMMAND ${CMAKE_COMMAND} -D "GSETTINGS_COMPILE:BOOL=${GSETTINGS_COMPILE}"
							-D "GSETTINGS_DIR:FILEPATH=${GSETTINGS_DIR}"
							-D "_glib_comple_schemas:FILEPATH=${_glib_comple_schemas}"
							-P "${CMAKE_SOURCE_DIR}/cmake/Uninstall.cmake"
)
