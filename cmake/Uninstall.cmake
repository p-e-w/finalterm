#
# Slightly modified version from: http://www.cmake.org/Wiki/CMake_FAQ
#

if(NOT EXISTS "${CMAKE_BINARY_DIR}/install_manifest.txt")
	message(FATAL_ERROR "Cannot find install manifest: \"${CMAKE_BINARY_DIR}/install_manifest.txt\"")
endif()

file(READ "${CMAKE_BINARY_DIR}/install_manifest.txt" files)
string(REGEX REPLACE "\n" ";" files "${files}")

cmake_policy(PUSH)
# Ignore empty list elements.
cmake_policy(SET CMP0007 OLD)
list(REVERSE files)
cmake_policy(POP)

foreach(file ${files})
	message(STATUS "Uninstalling \"$ENV{DESTDIR}${file}\"")
	if(EXISTS "$ENV{DESTDIR}${file}")
		execute_process(
			COMMAND ${CMAKE_COMMAND} -E remove "$ENV{DESTDIR}${file}"
			OUTPUT_VARIABLE rm_out
			RESULT_VARIABLE rm_retval
		)
		if(NOT ${rm_retval} EQUAL 0)
			message(FATAL_ERROR "Problem when removing \"$ENV{DESTDIR}${file}\"")
		endif()
	else()
		message(STATUS "File \"$ENV{DESTDIR}${file}\" does not exist.")
	endif()
endforeach()

if(GSETTINGS_COMPILE AND "$ENV{DESTDIR}" STREQUAL "")
	message (STATUS "Compiling GSettings schemas")
	execute_process(COMMAND ${_glib_comple_schemas} ${GSETTINGS_DIR})
endif()
