#
# cmake/Intltool.cmake
# Copyright (C) 2013, Valama development team
#
# Valama is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Valama is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <http://www.gnu.org/licenses/>.
#
##
find_program(INTLTOOL_EXTRACT_EXECUTABLE intltool-extract)
find_program(INTLTOOL_MERGE_EXECUTABLE intltool-merge)
mark_as_advanced(INTLTOOL_EXTRACT_EXECUTABLE)
mark_as_advanced(INTLTOOL_MERGE_EXECUTABLE)

if(INTLTOOL_EXTRACT_EXECUTABLE)
  execute_process(
    COMMAND
      ${INTLTOOL_EXTRACT_EXECUTABLE} "--version"
    OUTPUT_VARIABLE
      intltool_version
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if(intltool_version MATCHES "^intltool-extract \\(.*\\) [0-9]")
    string(REGEX REPLACE "^intltool-extract \\([^\\)]*\\) ([0-9\\.]+[^ \n]*).*" "\\1" INTLTOOL_VERSION_STRING "${intltool_version}")
  endif()
  unset(intltool_version)
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Intltool
  REQUIRED_VARS
    INTLTOOL_EXTRACT_EXECUTABLE
    INTLTOOL_MERGE_EXECUTABLE
  VERSION_VAR
    INTLTOOL_VERSION_STRING
)

set(INTLTOOL_OPTIONS_DEFAULT
  "--quiet"
)
