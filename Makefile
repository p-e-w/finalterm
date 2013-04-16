VALA_COMPILER = valac

SOURCE_FILES = \
	FinalTerm.vala \
	Terminal.vala \
	TerminalStream.vala \
	TerminalOutput.vala \
	CharacterAttributes.vala \
	TerminalView.vala \
	LineView.vala \
	Autocompletion.vala \
	NotifyingList.vala \
	ScrollableListView.vala \
	Utilities.vala \
	TextMenu.vala \
	ColorScheme.vala \
	Theme.vala \
	KeyBindings.vala \
	Command.vala \
	Settings.vala \
	Metrics.vala

OUTPUT_FILE = \
	finalterm

VALA_OPTIONS = \
	--Xcc=-lutil \
	--Xcc=-lm \
	--Xcc=-lkeybinder-3.0 \
	--pkg clutter-gtk-1.0 \
	--pkg mx-1.0 \
	--pkg posix \
	--pkg linux \
	--pkg gee-0.8 \
	--pkg keybinder

default:
	$(VALA_COMPILER) $(VALA_OPTIONS) -o $(OUTPUT_FILE) $(SOURCE_FILES)
