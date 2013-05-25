#
# cmake/Gettext.cmake
# Copyright (C) 2012, 2013, Valama development team
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
#
# Heavily based on Jim Nelson's Gettext.cmake in Geary project:
# https://github.com/ypcs/geary
#
##
# Add find_package handler for gettext programs msgmerge, msgfmt, msgcat and
# xgettext.
##
# Constant:
# XGETTEXT_OPTIONS_DEFAULT: Provide common xgettext options.
# XGETTEXT_VALA_OPTIONS_DEFAULT: Provide common xgettext options for Vala files.
# XGETTEXT_GLADE_OPTIONS_DEFAULT: Provide common xgettext options for glade.
# XGETTEXT_TEXTMENU_OPTIONS_DEFAULT: Provide common xgettext options for
#                                                           TextMenu files.
##
# The gettext_create_pot macro creates .pot files with xgettext from multiple
# source files.
# Provide target 'pot' to generate .pot file.
#
# Supported sections:
#
# PACKAGE (optional)
#   Gettext package name. Get exported to parent scope.
#   Default: ${PROJECT_NAME}
#
# VERSION (optional)
#   Gettext package version. Get exported to parent scope.
#   Default: ${${GETTEXT_PACKAGE_NAME}_VERSION}
#   (${GETTEXT_PACKAGE_NAME} is package name from option above)
#
# OPTIONS (optional)
#   Pass list of xgettext options (you can use XGETTEXT_OPTIONS_DEFAULT,
#   XGETTEXT_VALA_OPTIONS_DEFAULT, XGETTEXT_GLADE_OPTIONS_DEFAULT and
#   XGETTEXT_TEXTMENU_OPTIONS_DEFAULT constants).
#   Default: ${XGETTEXT_{,VALA,GLADE,TEXTMENU}_OPTIONS_DEFAULT}
#
# SRCFILES (optional/mandatory)
#   List of source files to extract gettext strings from. Globbing is
#  supported.
#
# GLADEFILES (optional/mandatory)
#   List of glade source files to extract gettext strings from. Globbing is
#   supported.
#
# TEXTMENUFILES (optional/mandatory)
#   List of ftmenu files to extract gettext strings from. Globbing is
#   supported.
#
# Either SRCFILES or GLADEFILES or TEXTMENUFILES (or all of them) has to be
# filled with some files.
#
##
# The gettext_create_translations function generates .gmo files from .po files
# and install them as .mo files.
# Provide target 'translations' to build .gmo files.
#
# Supported sections:
#
# ALL (optional)
#   Make translations target a dependency of the 'all' target. (Build
#   translations with every build.)
#
# COMMENT (optional)
#   Cmake comment for translations target.
#
# PODIR (optional)
#   Directory with .po files.
#   Default: ${CMAKE_CURRENT_SOURCE_DIR}
#
# LOCALEDIR (optional)
#   Base directory where to install translations.
#   Default: share/cmake
#
# LANGUAGES (optional)
#   List of language 'short names'. This is in generel the part before the .po.
#   With English locale this is e.g. 'en_GB' or 'en_US' etc.
#
# POFILES (optional)
#   List of .po files.
#
##
#
# The following call is a simple example (within project po directory):
#
#   include(Gettext)
#   if(XGETTEXT_FOUND)
#     set(potfile "${CMAKE_CURRENT_SOURCE_DIR}/my_project.pot")
#     gettext_create_pot("${potfile}"
#       SRCFILES
#         "${PROJECT_SOURCE_DIR}/src/*.vala"
#     )
#     gettext_create_translations("${potfile}"
#       ALL
#       COMMENT
#         "Build translations."
#     )
#   endif()
#
##
#
# Gettext functions imported from Valama project:
# https://github.com/Valama/valama
#
# 2013/05/23: Dominique Lasserre <lasserre.d@gmail.com>
#             - Support .ftmenu files.
#
##
find_program(GETTEXT_MSGMERGE_EXECUTABLE msgmerge)
find_program(GETTEXT_MSGFMT_EXECUTABLE msgfmt)
find_program(GETTEXT_MSGCAT_EXECUTABLE msgcat)
find_program(XGETTEXT_EXECUTABLE xgettext)
mark_as_advanced(GETTEXT_MSGMERGE_EXECUTABLE)
mark_as_advanced(GETTEXT_MSGFMT_EXECUTABLE)
mark_as_advanced(GETTEXT_MSGCAT_EXECUTABLE)
mark_as_advanced(XGETTEXT_EXECUTABLE)

if(XGETTEXT_EXECUTABLE)
  execute_process(COMMAND ${XGETTEXT_EXECUTABLE} "--version"
                  OUTPUT_VARIABLE gettext_version
                  ERROR_QUIET
                  OUTPUT_STRIP_TRAILING_WHITESPACE
  )
   if(gettext_version MATCHES "^xgettext \\(.*\\) [0-9]")
      string(REGEX REPLACE "^xgettext \\([^\\)]*\\) ([0-9\\.]+[^ \n]*).*" "\\1" GETTEXT_VERSION_STRING "${gettext_version}")
   endif()
   unset(gettext_version)
endif()


include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Gettext
  REQUIRED_VARS
    XGETTEXT_EXECUTABLE
    GETTEXT_MSGMERGE_EXECUTABLE
    GETTEXT_MSGFMT_EXECUTABLE
    GETTEXT_MSGCAT_EXECUTABLE
  VERSION_VAR
    GETTEXT_VERSION_STRING
)

if(XGETTEXT_EXECUTABLE AND GETTEXT_MSGMERGE_EXECUTABLE AND GETTEXT_MSGFMT_EXECUTABLE AND GETTEXT_MSGCAT_EXECUTABLE)
  set(XGETTEXT_FOUND TRUE)
  # Export variable to use it as status info.
  set(TRANSLATION_BUILD TRUE PARENT_SCOPE)
else()
  set(XGETTEXT_FOUND FALSE)
  set(TRANSLATION_BUILD FALSE PARENT_SCOPE)
endif()


set(XGETTEXT_OPTIONS_DEFAULT
  "-s"
  "--escape"
  "--add-comments=\"TRANSLATORS:\""  #TODO: Make this configurable.
  "--from-code=UTF-8"
)
set(XGETTEXT_VALA_OPTIONS_DEFAULT
  "--language" "C"
  "--keyword=_"
  "--keyword=N_"
  "--keyword=C_:1c,2"
  "--keyword=NC_:1c,2"
)
set(XGETTEXT_GLADE_OPTIONS_DEFAULT
  "--language" "Glade"
  "--omit-header"
)
set(XGETTEXT_TEXTMENU_OPTIONS_DEFAULT
  "--language" "C"
)


if(XGETTEXT_FOUND)
  macro(gettext_create_pot potfile)
    cmake_parse_arguments(ARGS "" "PACKAGE;VERSION;WORKING_DIRECTORY"
      "OPTIONS;VALA_OPTIONS;GLADE_OPTIONS;TEXTMENU_OPTIONS;SRCFILES;GLADEFILES;TEXTMENUFILES" ${ARGN})

    if(ARGS_PACKAGE)
      set(package_name "${ARGS_PACKAGE}")
    elseif(GETTEXT_PACKAGE)
      set(package_name "${GETTEXT_PACKAGE}")
    else()
      set(package_name "${PROJECT_NAME}")
    endif()

    if(ARGS_VERSION)
      set(package_version "${ARGS_VERSION}")
    elseif(VERSION)
      set(package_version "${VERSION}")
    else()
      set(package_version "${${package_name}_VERSION}")
    endif()
    # Export for status information.
    set(GETTEXT_PACKAGE_NAME "${package_name}" PARENT_SCOPE)
    set(GETTEXT_PACKAGE_VERSION "${package_version}" PARENT_SCOPE)

    set(xgettext_options "--package-name" "${package_name}")
    if(package_version)
      list(APPEND xgettext_options "--package-version" "${package_version}")
    endif()
    if(ARGS_OPTIONS)
      list(APPEND xgettext_options ${ARGS_OPTIONS})
    else()
      list(APPEND xgettext_options ${XGETTEXT_OPTIONS_DEFAULT})
    endif()

    if(ARGS_XGETTEXT_VALA_OPTIONS_DEFAULT)
      set(xgettext_vala_options ${ARGS_XGETTEXT_VALA_OPTIONS_DEFAULT})
    else()
      set(xgettext_vala_options ${XGETTEXT_VALA_OPTIONS_DEFAULT})
    endif()
    if(ARGS_XGETTEXT_GLADE_OPTIONS_DEFAULT)
      set(xgettext_glade_options ${ARGS_XGETTEXT_GLADE_OPTIONS_DEFAULT})
    else()
      set(xgettext_glade_options ${XGETTEXT_GLADE_OPTIONS_DEFAULT})
    endif()
    if(ARGS_XGETTEXT_TEXTMENU_OPTIONS_DEFAULT)
      set(xgettext_ftmenu_options ${ARGS_XGETTEXT_TEXTMENU_OPTIONS_DEFAULT})
    else()
      set(xgettext_ftmenu_options ${XGETTEXT_TEXTMENU_OPTIONS_DEFAULT})
    endif()

    if(ARGS_SRCFILES OR ARGS_GLADEFILES OR ARGS_TEXTMENUFILES)
      set(src_list)
      set(src_list_abs)
      foreach(globexpr ${ARGS_SRCFILES})
        set(tmpsrcfiles)
        file(GLOB tmpsrcfiles ${globexpr})
        if (tmpsrcfiles)
          foreach(tmpsrcfile ${tmpsrcfiles})
            get_filename_component(absFile "${ARGS_WORKING_DIRECTORY}${tmpsrcfile}" ABSOLUTE)
            file(RELATIVE_PATH relFile "${CMAKE_CURRENT_SOURCE_DIR}" "${absFile}")
            list(APPEND src_list "${relFile}")
            list(APPEND src_list_abs "${absFile}")
          endforeach()
        else()
          get_filename_component(absFile "${ARGS_WORKING_DIRECTORY}${globexpr}" ABSOLUTE)
          file(RELATIVE_PATH relFile "${CMAKE_CURRENT_SOURCE_DIR}" "${absFile}")
          list(APPEND src_list "${relFile}")
          list(APPEND src_list_abs "${absFile}")
        endif()
      endforeach()

      set(glade_list)
      set(glade_list_abs)
      foreach(globexpr ${ARGS_GLADEFILES})
        set(tmpgladefiles)
        file(GLOB tmpgladefiles ${globexpr})
        if (tmpgladefiles)
          foreach(tmpgladefile ${tmpgladefiles})
            get_filename_component(absFile "${ARGS_WORKING_DIRECTORY}${tmpgladefile}" ABSOLUTE)
            file(RELATIVE_PATH relFile "${CMAKE_CURRENT_SOURCE_DIR}" "${absFile}")
            list(APPEND glade_list "${relFile}")
            list(APPEND glade_list_abs "${absFile}")
          endforeach()
        else()
          get_filename_component(absFile "${ARGS_WORKING_DIRECTORY}${globexpr}" ABSOLUTE)
          file(RELATIVE_PATH relFile "${CMAKE_CURRENT_SOURCE_DIR}" "${absFile}")
          list(APPEND glade_list "${relFile}")
          list(APPEND glade_list_abs "${absFile}")
        endif()
      endforeach()

      set(ftmenu_list)
      set(ftmenu_list_abs)
      foreach(globexpr ${ARGS_TEXTMENUFILES})
        set(tmpftmenufiles)
        file(GLOB tmpftmenufiles ${globexpr})
        if (tmpftmenufiles)
          foreach(tmpftmenufile ${tmpftmenufiles})
            get_filename_component(absFile "${ARGS_WORKING_DIRECTORY}${tmpftmenufile}" ABSOLUTE)
            file(RELATIVE_PATH relFile "${CMAKE_CURRENT_SOURCE_DIR}" "${absFile}")
            list(APPEND ftmenu_list "${relFile}")
            list(APPEND ftmenu_list_abs "${absFile}")
          endforeach()
        else()
          get_filename_component(absFile "${ARGS_WORKING_DIRECTORY}${globexpr}" ABSOLUTE)
          file(RELATIVE_PATH relFile "${CMAKE_CURRENT_SOURCE_DIR}" "${absFile}")
          list(APPEND ftmenu_list "${relFile}")
          list(APPEND ftmenu_list_abs "${absFile}")
        endif()
      endforeach()

      if(ARGS_SRCFILES)
        add_custom_command(
          OUTPUT
            "${CMAKE_CURRENT_BINARY_DIR}/_source.pot"
          COMMAND
            "${XGETTEXT_EXECUTABLE}" ${xgettext_options} ${xgettext_vala_options} "-o" "${CMAKE_CURRENT_BINARY_DIR}/_source.pot" ${src_list}
          COMMAND
            # Make sure file exists even if no translatable strings available.
            ${CMAKE_COMMAND} -E touch "${CMAKE_CURRENT_BINARY_DIR}/_source.pot"
          DEPENDS
            ${src_list_abs}
          WORKING_DIRECTORY
            "${CMAKE_CURRENT_SOURCE_DIR}"
        )
      else()
        add_custom_command(
          OUTPUT
            "${CMAKE_CURRENT_BINARY_DIR}/_source.pot"
          COMMAND
            ${CMAKE_COMMAND} -E touch "${CMAKE_CURRENT_BINARY_DIR}/_source.pot"
        )
      endif()
      if(ARGS_GLADEFILES)
        add_custom_command(
          OUTPUT
            "${CMAKE_CURRENT_BINARY_DIR}/_glade.pot"
          COMMAND
            "${XGETTEXT_EXECUTABLE}" ${xgettext_options} ${xgettext_glade_options} "-o" "${CMAKE_CURRENT_BINARY_DIR}/_glade.pot" ${glade_list}
          COMMAND
            ${CMAKE_COMMAND} -E touch "${CMAKE_CURRENT_BINARY_DIR}/_glade.pot"
          DEPENDS
            ${glade_list_abs}
          WORKING_DIRECTORY
            "${CMAKE_CURRENT_SOURCE_DIR}"
        )
      else()
        add_custom_command(
          OUTPUT
            "${CMAKE_CURRENT_BINARY_DIR}/_glade.pot"
          COMMAND
            ${CMAKE_COMMAND} -E touch "${CMAKE_CURRENT_BINARY_DIR}/_glade.pot"
        )
      endif()
      if(ARGS_TEXTMENUFILES)
        add_custom_command(
          OUTPUT
            "${CMAKE_CURRENT_BINARY_DIR}/_ftmenu.pot"
          COMMAND
            "${XGETTEXT_EXECUTABLE}" ${xgettext_options} ${xgettext_ftmenu_options} "-o" "${CMAKE_CURRENT_BINARY_DIR}/_ftmenu.pot" ${ftmenu_list}
          COMMAND
            ${CMAKE_COMMAND} -E touch "${CMAKE_CURRENT_BINARY_DIR}/_ftmenu.pot"
          DEPENDS
            ${ftmenu_list_abs}
          WORKING_DIRECTORY
            "${CMAKE_CURRENT_SOURCE_DIR}"
        )
      else()
        add_custom_command(
          OUTPUT
            "${CMAKE_CURRENT_BINARY_DIR}/_ftmenu.pot"
          COMMAND
            ${CMAKE_COMMAND} -E touch "${CMAKE_CURRENT_BINARY_DIR}/_ftmenu.pot"
        )
      endif()

      add_custom_target(pot
        COMMAND
          "${GETTEXT_MSGCAT_EXECUTABLE}" "-o" "${potfile}" "--use-first" "${CMAKE_CURRENT_BINARY_DIR}/_source.pot" "${CMAKE_CURRENT_BINARY_DIR}/_glade.pot" "${CMAKE_CURRENT_BINARY_DIR}/_ftmenu.pot"
        DEPENDS
          "${CMAKE_CURRENT_BINARY_DIR}/_source.pot"
          "${CMAKE_CURRENT_BINARY_DIR}/_glade.pot"
          "${CMAKE_CURRENT_BINARY_DIR}/_ftmenu.pot"
        WORKING_DIRECTORY
          "${CMAKE_CURRENT_SOURCE_DIR}"
        COMMENT
          "Extract translatable messages to ${potfile}"
      )
    endif()
  endmacro()


  function(gettext_create_translations potfile)
    cmake_parse_arguments(ARGS "ALL;NOUPDATE" "COMMENT;PODIR;LOCALEDIR" "LANGUAGES;POFILES" ${ARGN})

    get_filename_component(_potBasename ${potfile} NAME_WE)
    get_filename_component(_absPotFile ${potfile} ABSOLUTE)

    if(ARGS_ALL)
      set(make_all "ALL")
    else()
      set(make_all)
    endif()

    if(ARGS_LOCALEDIR)
      set(_localedir "${ARGS_LOCALEDIR}")
    elseif(localedir)
      set(_localedir "${localedir}")
    else()
      set(_localedir "share/locale")
    endif()

    set(langs)
    list(APPEND langs ${ARGS_LANGUAGES})

    foreach(globexpr ${ARGS_POFILES})
      set(tmppofiles)
      file(GLOB tmppofiles ${globexpr})
      if(tmppofiles)
        foreach(tmppofile ${tmppofiles})
          string(REGEX REPLACE ".*/([a-zA-Z_]+)(\\.po)?$" "\\1" lang "${tmppofile}")
          list(APPEND langs "${lang}")
        endforeach()
      else()
          string(REGEX REPLACE ".*/([a-zA-Z_]+)(\\.po)?$" "\\1" lang "${globexpr}")
          list(APPEND langs "${lang}")
      endif()
    endforeach()

    if(NOT langs AND NOT ARGS_PODIR)
      set(ARGS_PODIR "${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
    if(ARGS_PODIR)
      file(GLOB pofiles "${ARGS_PODIR}/*.po")
      foreach(pofile ${pofiles})
        string(REGEX REPLACE ".*/([a-zA-Z_]+)\\.po$" "\\1" lang "${pofile}")
        list(APPEND langs "${lang}")
      endforeach()
    endif()

    if(langs)
      list(REMOVE_DUPLICATES langs)
    endif()


    set(_gmoFile)
    set(_gmoFiles)
    foreach (lang ${langs})
      get_filename_component(_absFile "${lang}.po" ABSOLUTE)
      set(_gmoFile "${CMAKE_CURRENT_BINARY_DIR}/${lang}.gmo")

      if(ARGS_NOUPDATE)
        set(_absFile_new "${CMAKE_CURRENT_BINARY_DIR}/${lang}.po")
        add_custom_command(
          OUTPUT
            "${_absFile_new}"
          COMMAND
            ${CMAKE_COMMAND} -E copy "${_absFile}" "${_absFile_new}"
          DEPENDS
            "${_absPotFile}"
            "${_absFile}"
        )
        set(_absFile "${_absFile_new}")
      endif()
      add_custom_command(
        OUTPUT
          "${_gmoFile}"
        COMMAND
          "${GETTEXT_MSGMERGE_EXECUTABLE}" "--quiet" "--update" "--backup=none" "-s" "${_absFile}" "${_absPotFile}"
        COMMAND
          "${GETTEXT_MSGFMT_EXECUTABLE}" "-o" "${_gmoFile}" "${_absFile}"
        DEPENDS
          "${_absPotFile}"
          "${_absFile}"
        WORKING_DIRECTORY
          "${CMAKE_CURRENT_BINARY_DIR}"
      )

      install(
        FILES
          "${_gmoFile}"
        DESTINATION
          "${_localedir}/${lang}/LC_MESSAGES"
        RENAME
          "${_potBasename}.mo"
      )
      list(APPEND _gmoFiles "${_gmoFile}")
    endforeach()

    if(ARGS_COMMENT)
      add_custom_target(translations
        "${make_all}"
        DEPENDS
          ${_gmoFiles}
        COMMENT
          "${ARGS_COMMENT}" VERBATIM
      )
    else()
      add_custom_target(translations
        "${make_all}"
        DEPENDS
          ${_gmoFiles}
        COMMENT
          "Build translations." VERBATIM
      )
    endif()
  endfunction()
endif()

# vim: set ai ts=2 sts=2 et sw=2
