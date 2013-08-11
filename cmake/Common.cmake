#
# Part of cmake/Common.cmake of Valama.
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
# Get formatted date string.
#
# Usage:
# The first parameter is set to output date string.
#
# FORMAT
#   Format string.
#
#
# Simple example:
#
#   datestring(date
#     FORMAT "%B %Y"
#   )
#   # Will print out e.g. "Date: April 2013"
#   message("Date: ${date}")
#
macro(datestring output)
  include(CMakeParseArguments)
  cmake_parse_arguments(ARGS "" "FORMAT" "" ${ARGN})

  if(ARGS_FORMAT)
    set(format "${ARGS_FORMAT}")
  else()
    set(format "${ARGN}")
  endif()

  if(WIN32)
    #FIXME: Needs to be tested. Perhaps wrapping with cmd is needed.
    execute_process(
      COMMAND
        "date" "${format}"
      OUTPUT_VARIABLE
        "${output}"
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
  else()
    execute_process(
      COMMAND
      "date" "+${format}"
      OUTPUT_VARIABLE
        "${output}"
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
  endif()
endmacro()
