include(Gettext)
if(XGETTEXT_FOUND)
	set(potfile "${CMAKE_CURRENT_SOURCE_DIR}/finalterm.pot")
	gettext_create_pot("${potfile}"
		SRCFILES
			"src/*.vala"
		TEXTMENUFILES
			"data/TextMenus/*.ftmenu"
		DESKTOPFILES
			"data/finalterm.desktop.in"
		GSETTINGSFILES
			"data/org.gnome.finalterm.gschema.xml"
		WORKING_DIRECTORY
			"../"
	)
	option(UPDATE_PO "Update .po files." ON)
  if(UPDATE_PO)
    set(NOUPDATE)
  else()
    set(NOUPDATE "NOUPDATE")
  endif()
  gettext_create_translations("${potfile}" ALL ${NOUPDATE})
endif()
