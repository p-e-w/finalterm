/*
 * Copyright © 2013 Philipp Emanuel Weidmann <pew@worldwidemann.com>
 *
 * Nemo vir est qui mundum non reddat meliorem.
 *
 *
 * This file is part of Final Term.
 *
 * Final Term is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Final Term is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Final Term.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * Processes and stores raw terminal output, parsing control sequences
 */
// TODO: Rename to "TerminalParser"
public class TerminalStream : Object {

	private ParseState parse_state = ParseState.TEXT;

	private enum ParseState {
		TEXT,
		CONTROL_CHARACTER,
		ESCAPE_SEQUENCE,
		DCS_SEQUENCE,
		CSI_SEQUENCE,
		OSC_SEQUENCE
	}

	private StringBuilder sequence_builder = new StringBuilder();

	// All xterm single-character functions (except Space (TODO?))
	// See http://invisible-island.net/xterm/ctlseqs/ctlseqs.html
	private const string CONTROL_CHARACTERS = "\x07\x08\x0D\x05\x0C\x0A\x0F\x0E\x09\x0B";

	// TODO: Generalize this idea to parse any sequence based on start / end characters
	private const string ESCAPE_SEQUENCE_START_CHARACTER = "\x1B";
	private const string DCS_SEQUENCE_START_CHARACTER = "\x90";
	private const string CSI_SEQUENCE_START_CHARACTER = "\x9B";
	private const string OSC_SEQUENCE_START_CHARACTER = "\x9D";
	private const string ESCAPE_SEQUENCE_DCS = "P";
	private const string ESCAPE_SEQUENCE_CSI = "[";
	private const string ESCAPE_SEQUENCE_OSC = "]";

	// All escape sequence end characters listed in the xterm specification (VT100 mode)
	// NOTE: The characters "P" (DCS), "[" (CSI) and "]" (OSC) are excluded here
	private const string ESCAPE_SEQUENCE_END_CHARACTERS = "DEHMNOVWXZ\\^_FGLMN34568@G0AB4C5RQKYE6ZH7=6789=>Fclmno|}~";

	private const string DCS_SEQUENCE_END_CHARACTERS = "\x9C";

	// "The final character of these sequences is in the range ASCII 64 to 126 [...]" (Wikipedia)
	private const string CSI_SEQUENCE_END_CHARACTERS = "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";

	// "[...] in many cases BEL is an acceptable alternative to ST." (Wikipedia)
	// TODO: Handle alternative ST notation (ESC + "\")
	private const string OSC_SEQUENCE_END_CHARACTERS = "\x07\x9C";

	public void parse_character(unichar character) {
		ParseState old_parse_state = parse_state;

		// Sequence start recognition
		switch (parse_state) {
		case ParseState.TEXT:
			if (CONTROL_CHARACTERS.contains(character.to_string())) {
				// Emit current text sequence so that character
				// can be emitted separately
				emit_sequence();
				// Emit control character
				parse_state = ParseState.CONTROL_CHARACTER;
				sequence_builder.append_unichar(character);
				emit_sequence();
				parse_state = ParseState.TEXT;
				return;
			}
			switch (character.to_string()) {
			case ESCAPE_SEQUENCE_START_CHARACTER:
				emit_sequence();
				parse_state = ParseState.ESCAPE_SEQUENCE;
				break;
			case DCS_SEQUENCE_START_CHARACTER:
				emit_sequence();
				parse_state = ParseState.DCS_SEQUENCE;
				break;
			case CSI_SEQUENCE_START_CHARACTER:
				emit_sequence();
				parse_state = ParseState.CSI_SEQUENCE;
				break;
			case OSC_SEQUENCE_START_CHARACTER:
				emit_sequence();
				parse_state = ParseState.OSC_SEQUENCE;
				break;
			}
			break;
		case ParseState.CONTROL_CHARACTER:
			break;
		case ParseState.ESCAPE_SEQUENCE:
			if (sequence_builder.len == 1) {
				// First character after escape sequence inducer
				switch (character.to_string()) {
				case ESCAPE_SEQUENCE_DCS:
					// Do not emit the sequence here (simple state change)
					parse_state = ParseState.DCS_SEQUENCE;
					break;
				case ESCAPE_SEQUENCE_CSI:
					parse_state = ParseState.CSI_SEQUENCE;
					break;
				case ESCAPE_SEQUENCE_OSC:
					parse_state = ParseState.OSC_SEQUENCE;
					break;
				}
			}
			break;
		case ParseState.DCS_SEQUENCE:
		case ParseState.CSI_SEQUENCE:
		case ParseState.OSC_SEQUENCE:
			break;
		}

		sequence_builder.append_unichar(character);

		if (parse_state != old_parse_state)
			// Character already processed
			return;

		switch (parse_state) {
		case ParseState.TEXT:
			transient_text_updated(sequence_builder.str);
			break;
		case ParseState.CONTROL_CHARACTER:
			break;
		// Sequence end recognition
		case ParseState.ESCAPE_SEQUENCE:
			if (ESCAPE_SEQUENCE_END_CHARACTERS.contains(character.to_string())) {
				emit_sequence();
				parse_state = ParseState.TEXT;
			}
			break;
		case ParseState.DCS_SEQUENCE:
			if (DCS_SEQUENCE_END_CHARACTERS.contains(character.to_string())) {
				emit_sequence();
				parse_state = ParseState.TEXT;
			}
			break;
		case ParseState.CSI_SEQUENCE:
			if (CSI_SEQUENCE_END_CHARACTERS.contains(character.to_string())) {
				emit_sequence();
				parse_state = ParseState.TEXT;
			}
			break;
		case ParseState.OSC_SEQUENCE:
			if (OSC_SEQUENCE_END_CHARACTERS.contains(character.to_string())) {
				emit_sequence();
				parse_state = ParseState.TEXT;
			}
			break;
		}
	}

	private void emit_sequence() {
		if (sequence_builder.len == 0)
			return;

		switch (parse_state) {
		case ParseState.TEXT:
			element_completed(new StreamElement.from_text(sequence_builder.str));
			break;
		case ParseState.CONTROL_CHARACTER:
		case ParseState.ESCAPE_SEQUENCE:
		case ParseState.DCS_SEQUENCE:
		case ParseState.CSI_SEQUENCE:
		case ParseState.OSC_SEQUENCE:
			element_completed(new StreamElement.from_control_sequence(sequence_builder.str));
			break;
		}

		sequence_builder.erase();
	}

	public signal void element_completed(StreamElement stream_element);

	public signal void transient_text_updated(string transient_text);


	public class StreamElement : Object {

		public StreamElementType stream_element_type { get; set; }

		public enum StreamElementType {
			TEXT,
			CONTROL_SEQUENCE  // TODO: Rename "control code"?
		}

		public string text { get; set; }

		public ControlSequenceType control_sequence_type { get; set; }

		// Naming convention follows xterm specification found at
		// http://invisible-island.net/xterm/ctlseqs/ctlseqs.html
		public enum ControlSequenceType {
			UNKNOWN,

			BELL,
			BACKSPACE,
			CARRIAGE_RETURN,
			RETURN_TERMINAL_STATUS,
			FORM_FEED,
			LINE_FEED,
			SHIFT_IN,
			SHIFT_OUT,
			HORIZONTAL_TAB,
			VERTICAL_TAB,

			SEVEN_BIT_CONTROLS,
			EIGHT_BIT_CONTROLS,
			SET_ANSI_CONFORMANCE_LEVEL_1,
			SET_ANSI_CONFORMANCE_LEVEL_2,
			SET_ANSI_CONFORMANCE_LEVEL_3,
			DEC_DOUBLE_HEIGHT_LINE_TOP_HALF,
			DEC_DOUBLE_HEIGHT_LINE_BOTTOM_HALF,
			DEC_SINGLE_WIDTH_LINE,
			DEC_DOUBLE_WIDTH_LINE,
			DEC_SCREEN_ALIGNMENT_TEST,
			SELECT_DEFAULT_CHARACTER_SET,
			SELECT_UTF8_CHARACTER_SET,
			DESIGNATE_G0_CHARACTER_SET_VT100,
			DESIGNATE_G1_CHARACTER_SET_VT100,
			DESIGNATE_G2_CHARACTER_SET_VT220,
			DESIGNATE_G3_CHARACTER_SET_VT220,
			DESIGNATE_G1_CHARACTER_SET_VT300,
			DESIGNATE_G2_CHARACTER_SET_VT300,
			DESIGNATE_G3_CHARACTER_SET_VT300,
			BACK_INDEX,
			SAVE_CURSOR,
			RESTORE_CURSOR,
			FORWARD_INDEX,
			APPLICATION_KEYPAD,
			NORMAL_KEYPAD,
			CURSOR_TO_LOWER_LEFT_CORNER_OF_SCREEN,
			FULL_RESET,
			MEMORY_LOCK,
			MEMORY_UNLOCK,
			INVOKE_G2_CHARACTER_SET_AS_GL,
			INVOKE_G3_CHARACTER_SET_AS_GL,
			INVOKE_G3_CHARACTER_SET_AS_GR,
			INVOKE_G2_CHARACTER_SET_AS_GR,
			INVOKE_G1_CHARACTER_SET_AS_GR,

			USER_DEFINED_KEYS,
			REQUEST_STATUS_STRING,
			SET_TERMCAP_DATA,
			REQUEST_TERMCAP_STRING,

			INSERT_CHARACTERS,
			CURSOR_UP,
			CURSOR_DOWN,
			CURSOR_FORWARD,
			CURSOR_BACKWARD,
			CURSOR_NEXT_LINE,
			CURSOR_PRECEDING_LINE,
			CURSOR_CHARACTER_ABSOLUTE,
			CURSOR_POSITION,
			CURSOR_FORWARD_TABULATION,
			ERASE_IN_DISPLAY_ED,
			ERASE_IN_DISPLAY_DECSED,
			ERASE_IN_LINE_EL,
			ERASE_IN_LINE_DECSEL,
			INSERT_LINES,
			DELETE_LINES,
			DELETE_CHARACTERS,
			SCROLL_UP_LINES,
			SCROLL_DOWN_LINES,
			INITIATE_HIGHLIGHT_MOUSE_TRACKING,
			RESET_TITLE_MODES_FEATURES,
			ERASE_CHARACTERS,
			CURSOR_BACKWARD_TABULATION,
			CHARACTER_POSITION_ABSOLUTE,
			CHARACTER_POSITION_RELATIVE,
			REPEAT_PRECEDING_GRAPHIC_CHARACTER,
			SEND_DEVICE_ATTRIBUTES_PRIMARY,
			SEND_DEVICE_ATTRIBUTES_SECONDARY,
			LINE_POSITION_ABSOLUTE,
			LINE_POSITION_RELATIVE,
			HORIZONTAL_AND_VERTICAL_POSITION,
			TAB_CLEAR,
			SET_MODE,
			DEC_PRIVATE_MODE_SET,
			MEDIA_COPY,
			MEDIA_COPY_DEC,
			RESET_MODE,
			DEC_PRIVATE_MODE_RESET,
			CHARACTER_ATTRIBUTES,
			SET_OR_RESET_RESOURCE_VALUES,
			DEVICE_STATUS_REPORT,
			DISABLE_MODIFIERS,
			DEVICE_STATUS_REPORT_DEC,
			SET_RESOURCE_VALUE_POINTER_MODE,
			SOFT_TERMINAL_RESET,
			REQUEST_ANSI_MODE,
			REQUEST_DEC_PRIVATE_MODE,
			SET_CONFORMANCE_LEVEL,
			LOAD_LEDS,
			SET_CURSOR_STYLE,
			SELECT_CHARACTER_PROTECTION_ATTRIBUTE,
			SET_SCROLLING_REGION,
			RESTORE_DEC_PRIVATE_MODE_VALUES,
			CHANGE_ATTRIBUTES_IN_RECTANGULAR_AREA,
			SET_LEFT_AND_RIGHT_MARGINS,
			SAVE_CURSOR_ANSI_SYS,
			SAVE_DEC_PRIVATE_MODE_VALUES,
			WINDOW_MANIPULATION,
			REVERSE_ATTRIBUTES_IN_RECTANGULAR_AREA,
			SET_TITLE_MODES_FEATURES,
			SET_WARNING_BELL_VOLUME,
			RESTORE_CURSOR_ANSI_SYS,
			SET_MARGIN_BELL_VOLUME,
			COPY_RECTANGULAR_AREA,
			ENABLE_FILTER_RECTANGLE,
			REQUEST_TERMINAL_PARAMETERS,
			SELECT_ATTRIBUTE_CHANGE_EXTENT,
			REQUEST_CHECKSUM_OF_RECTANGULAR_AREA,
			FILL_RECTANGULAR_AREA,
			ENABLE_LOCATOR_REPORTING,
			ERASE_RECTANGULAR_AREA,
			SELECT_LOCATOR_EVENTS,
			SELECTIVE_ERASE_RECTANGULAR_AREA,
			REQUEST_LOCATOR_POSITION,
			INSERT_COLUMNS,
			DELETE_COLUMNS,

			SET_TEXT_PARAMETERS,

			FTCS_PROMPT,
			FTCS_COMMAND_START,
			FTCS_COMMAND_EXECUTED,
			FTCS_COMMAND_FINISHED,
			FTCS_TEXT_MENU_START,
			FTCS_TEXT_MENU_END,
			FTCS_PROGRESS
		}

		// TODO: Use accessor methods ("add_parameter()") instead of public(?)
		public Gee.List<string> control_sequence_parameters { get; set; }

		private struct ControlSequenceSpecification {
			ControlSequenceType type;
			Regex pattern;
		}

		// This data structure is used to facilitate efficient control sequence matching
		// by mapping sequences' final characters to sequence specifications
		// TODO: Consider GLib Quarks here?
		private static Gee.MultiMap<unichar, ControlSequenceSpecification?> control_sequence_specifications =
				new Gee.HashMultiMap<unichar, ControlSequenceSpecification?>();

		private const string ESC_PATTERN_START = "\\x1B";
		private const string DCS_PATTERN_START = "(?:(?:\\x1BP)|\\x90)";
		private const string DCS_PATTERN_END   = "\\x9C";
		private const string CSI_PATTERN_START = "(?:(?:\\x1B\\[)|\\x9B)";
		private const string OSC_PATTERN_START = "(?:(?:\\x1B\\])|\\x9D)";
		private const string OSC_PATTERN_END   = "(?:\\x07|\\x9C)";

		// Used to differentiate Final Term control sequences from ordinary OSC sequences
		private const string FINAL_TERM_PATTERN_DESIGNATOR = "133;";

		// TODO: More accurate / specific parameter matching
		private const string PARAMETER_LIST_PATTERN   = "(.*)";
		private const string PARAMETER_LIST_DELIMITER = ";";

		private const string[] OSC_FINAL_CHARACTERS = { "\x07", "\x9C" };

		private const string[] CHARACTER_SET_DESIGNATOR_FINAL_CHARACTERS =
				{ "0", "A", "B", "4", "C", "5", "R", "Q", "K", "Y", "E", "6", "Z", "H", "7", "=" };

		static construct {
			// All xterm single-character functions (except Space (TODO?))
			// See http://invisible-island.net/xterm/ctlseqs/ctlseqs.html
			add_scf_sequence_pattern(ControlSequenceType.BELL, "\x07");
			add_scf_sequence_pattern(ControlSequenceType.BACKSPACE, "\x08");
			add_scf_sequence_pattern(ControlSequenceType.CARRIAGE_RETURN, "\x0D");
			add_scf_sequence_pattern(ControlSequenceType.RETURN_TERMINAL_STATUS, "\x05");
			add_scf_sequence_pattern(ControlSequenceType.FORM_FEED, "\x0C");
			add_scf_sequence_pattern(ControlSequenceType.LINE_FEED, "\x0A");
			add_scf_sequence_pattern(ControlSequenceType.SHIFT_IN, "\x0F");
			add_scf_sequence_pattern(ControlSequenceType.SHIFT_OUT, "\x0E");
			add_scf_sequence_pattern(ControlSequenceType.HORIZONTAL_TAB, "\x09");
			add_scf_sequence_pattern(ControlSequenceType.VERTICAL_TAB, "\x0B");

			// All xterm ESC control sequences (VT100 mode)
			// See http://invisible-island.net/xterm/ctlseqs/ctlseqs.html
			// TODO: Add C1 (8-bit) ESC control sequences as well
			add_esc_sequence_pattern(ControlSequenceType.SEVEN_BIT_CONTROLS, " F");
			add_esc_sequence_pattern(ControlSequenceType.EIGHT_BIT_CONTROLS, " G");
			add_esc_sequence_pattern(ControlSequenceType.SET_ANSI_CONFORMANCE_LEVEL_1, " L");
			add_esc_sequence_pattern(ControlSequenceType.SET_ANSI_CONFORMANCE_LEVEL_2, " M");
			add_esc_sequence_pattern(ControlSequenceType.SET_ANSI_CONFORMANCE_LEVEL_3, " N");
			add_esc_sequence_pattern(ControlSequenceType.DEC_DOUBLE_HEIGHT_LINE_TOP_HALF, "#3");
			add_esc_sequence_pattern(ControlSequenceType.DEC_DOUBLE_HEIGHT_LINE_BOTTOM_HALF, "#4");
			add_esc_sequence_pattern(ControlSequenceType.DEC_SINGLE_WIDTH_LINE, "#5");
			add_esc_sequence_pattern(ControlSequenceType.DEC_DOUBLE_WIDTH_LINE, "#6");
			add_esc_sequence_pattern(ControlSequenceType.DEC_SCREEN_ALIGNMENT_TEST, "#8");
			add_esc_sequence_pattern(ControlSequenceType.SELECT_DEFAULT_CHARACTER_SET, "%@");
			add_esc_sequence_pattern(ControlSequenceType.SELECT_UTF8_CHARACTER_SET, "%G");
			add_designate_character_set_sequence_pattern(ControlSequenceType.DESIGNATE_G0_CHARACTER_SET_VT100, "(");
			add_designate_character_set_sequence_pattern(ControlSequenceType.DESIGNATE_G1_CHARACTER_SET_VT100, ")");
			add_designate_character_set_sequence_pattern(ControlSequenceType.DESIGNATE_G2_CHARACTER_SET_VT220, "*");
			add_designate_character_set_sequence_pattern(ControlSequenceType.DESIGNATE_G3_CHARACTER_SET_VT220, "+");
			add_designate_character_set_sequence_pattern(ControlSequenceType.DESIGNATE_G1_CHARACTER_SET_VT300, "-");
			add_designate_character_set_sequence_pattern(ControlSequenceType.DESIGNATE_G2_CHARACTER_SET_VT300, ".");
			add_designate_character_set_sequence_pattern(ControlSequenceType.DESIGNATE_G3_CHARACTER_SET_VT300, "/");
			add_esc_sequence_pattern(ControlSequenceType.BACK_INDEX, "6");
			add_esc_sequence_pattern(ControlSequenceType.SAVE_CURSOR, "7");
			add_esc_sequence_pattern(ControlSequenceType.RESTORE_CURSOR, "8");
			add_esc_sequence_pattern(ControlSequenceType.FORWARD_INDEX, "9");
			add_esc_sequence_pattern(ControlSequenceType.APPLICATION_KEYPAD, "=");
			add_esc_sequence_pattern(ControlSequenceType.NORMAL_KEYPAD, ">");
			add_esc_sequence_pattern(ControlSequenceType.CURSOR_TO_LOWER_LEFT_CORNER_OF_SCREEN, "F");
			add_esc_sequence_pattern(ControlSequenceType.FULL_RESET, "c");
			add_esc_sequence_pattern(ControlSequenceType.MEMORY_LOCK, "l");
			add_esc_sequence_pattern(ControlSequenceType.MEMORY_UNLOCK, "m");
			add_esc_sequence_pattern(ControlSequenceType.INVOKE_G2_CHARACTER_SET_AS_GL, "n");
			add_esc_sequence_pattern(ControlSequenceType.INVOKE_G3_CHARACTER_SET_AS_GL, "o");
			add_esc_sequence_pattern(ControlSequenceType.INVOKE_G3_CHARACTER_SET_AS_GR, "|");
			add_esc_sequence_pattern(ControlSequenceType.INVOKE_G2_CHARACTER_SET_AS_GR, "}");
			add_esc_sequence_pattern(ControlSequenceType.INVOKE_G1_CHARACTER_SET_AS_GR, "~");

			// xterm implements no APC functions
			// See http://invisible-island.net/xterm/ctlseqs/ctlseqs.html

			// All xterm DCS control sequences
			// See http://invisible-island.net/xterm/ctlseqs/ctlseqs.html
			add_dcs_sequence_pattern(ControlSequenceType.USER_DEFINED_KEYS, "");
			add_dcs_sequence_pattern(ControlSequenceType.REQUEST_STATUS_STRING, "$q");
			add_dcs_sequence_pattern(ControlSequenceType.SET_TERMCAP_DATA, "+p");
			add_dcs_sequence_pattern(ControlSequenceType.REQUEST_TERMCAP_STRING, "+q");

			// All xterm CSI control sequences
			// See http://invisible-island.net/xterm/ctlseqs/ctlseqs.html
			// TODO: Comment ignored sequences to improve performance
			add_csi_sequence_pattern(ControlSequenceType.INSERT_CHARACTERS, "@");
			add_csi_sequence_pattern(ControlSequenceType.CURSOR_UP, "A");
			add_csi_sequence_pattern(ControlSequenceType.CURSOR_DOWN, "B");
			add_csi_sequence_pattern(ControlSequenceType.CURSOR_FORWARD, "C");
			add_csi_sequence_pattern(ControlSequenceType.CURSOR_BACKWARD, "D");
			add_csi_sequence_pattern(ControlSequenceType.CURSOR_NEXT_LINE, "E");
			add_csi_sequence_pattern(ControlSequenceType.CURSOR_PRECEDING_LINE, "F");
			add_csi_sequence_pattern(ControlSequenceType.CURSOR_CHARACTER_ABSOLUTE, "G");
			add_csi_sequence_pattern(ControlSequenceType.CURSOR_POSITION, "H");
			add_csi_sequence_pattern(ControlSequenceType.CURSOR_FORWARD_TABULATION, "I");
			add_csi_sequence_pattern(ControlSequenceType.ERASE_IN_DISPLAY_ED, "J");
			add_csi_sequence_pattern(ControlSequenceType.ERASE_IN_DISPLAY_DECSED, "J", "?");
			add_csi_sequence_pattern(ControlSequenceType.ERASE_IN_LINE_EL, "K");
			add_csi_sequence_pattern(ControlSequenceType.ERASE_IN_LINE_DECSEL, "K", "?");
			add_csi_sequence_pattern(ControlSequenceType.INSERT_LINES, "L");
			add_csi_sequence_pattern(ControlSequenceType.DELETE_LINES, "M");
			add_csi_sequence_pattern(ControlSequenceType.DELETE_CHARACTERS, "P");
			add_csi_sequence_pattern(ControlSequenceType.SCROLL_UP_LINES, "S");
			add_csi_sequence_pattern(ControlSequenceType.SCROLL_DOWN_LINES, "T");
			// TODO: Parameter count differentiation needed here
			add_csi_sequence_pattern(ControlSequenceType.INITIATE_HIGHLIGHT_MOUSE_TRACKING, "T");
			add_csi_sequence_pattern(ControlSequenceType.RESET_TITLE_MODES_FEATURES, "T", ">");
			add_csi_sequence_pattern(ControlSequenceType.ERASE_CHARACTERS, "X");
			add_csi_sequence_pattern(ControlSequenceType.CURSOR_BACKWARD_TABULATION, "Z");
			add_csi_sequence_pattern(ControlSequenceType.CHARACTER_POSITION_ABSOLUTE, "`");
			add_csi_sequence_pattern(ControlSequenceType.CHARACTER_POSITION_RELATIVE, "a");
			add_csi_sequence_pattern(ControlSequenceType.REPEAT_PRECEDING_GRAPHIC_CHARACTER, "b");
			add_csi_sequence_pattern(ControlSequenceType.SEND_DEVICE_ATTRIBUTES_PRIMARY, "c");
			add_csi_sequence_pattern(ControlSequenceType.SEND_DEVICE_ATTRIBUTES_SECONDARY, "c", ">");
			add_csi_sequence_pattern(ControlSequenceType.LINE_POSITION_ABSOLUTE, "d");
			add_csi_sequence_pattern(ControlSequenceType.LINE_POSITION_RELATIVE, "e");
			add_csi_sequence_pattern(ControlSequenceType.HORIZONTAL_AND_VERTICAL_POSITION, "f");
			add_csi_sequence_pattern(ControlSequenceType.TAB_CLEAR, "g");
			add_csi_sequence_pattern(ControlSequenceType.SET_MODE, "h");
			add_csi_sequence_pattern(ControlSequenceType.DEC_PRIVATE_MODE_SET, "h", "?");
			add_csi_sequence_pattern(ControlSequenceType.MEDIA_COPY, "i");
			add_csi_sequence_pattern(ControlSequenceType.MEDIA_COPY_DEC, "i", "?");
			add_csi_sequence_pattern(ControlSequenceType.RESET_MODE, "l");
			add_csi_sequence_pattern(ControlSequenceType.DEC_PRIVATE_MODE_RESET, "l", "?");
			add_csi_sequence_pattern(ControlSequenceType.CHARACTER_ATTRIBUTES, "m");
			add_csi_sequence_pattern(ControlSequenceType.SET_OR_RESET_RESOURCE_VALUES, "m", ">");
			add_csi_sequence_pattern(ControlSequenceType.DEVICE_STATUS_REPORT, "n");
			add_csi_sequence_pattern(ControlSequenceType.DISABLE_MODIFIERS, "n", ">");
			add_csi_sequence_pattern(ControlSequenceType.DEVICE_STATUS_REPORT_DEC, "n", "?");
			add_csi_sequence_pattern(ControlSequenceType.SET_RESOURCE_VALUE_POINTER_MODE, "p", ">");
			// TODO: This is a hack to match the EXACT sequence CSI + "!p"
			add_csi_sequence_pattern(ControlSequenceType.SOFT_TERMINAL_RESET, "!p");
			add_csi_sequence_pattern(ControlSequenceType.REQUEST_ANSI_MODE, "$p");
			add_csi_sequence_pattern(ControlSequenceType.REQUEST_DEC_PRIVATE_MODE, "$p", "?");
			add_csi_sequence_pattern(ControlSequenceType.SET_CONFORMANCE_LEVEL, "“p");
			add_csi_sequence_pattern(ControlSequenceType.LOAD_LEDS, "q");
			add_csi_sequence_pattern(ControlSequenceType.SET_CURSOR_STYLE, " q");
			add_csi_sequence_pattern(ControlSequenceType.SELECT_CHARACTER_PROTECTION_ATTRIBUTE, "“q");
			add_csi_sequence_pattern(ControlSequenceType.SET_SCROLLING_REGION, "r");
			add_csi_sequence_pattern(ControlSequenceType.RESTORE_DEC_PRIVATE_MODE_VALUES, "r", "?");
			add_csi_sequence_pattern(ControlSequenceType.CHANGE_ATTRIBUTES_IN_RECTANGULAR_AREA, "$r");
			add_csi_sequence_pattern(ControlSequenceType.SET_LEFT_AND_RIGHT_MARGINS, "s");
			// TODO: This is a hack to match the EXACT sequence CSI + "s"
			add_csi_sequence_pattern(ControlSequenceType.SAVE_CURSOR_ANSI_SYS, "s");
			add_csi_sequence_pattern(ControlSequenceType.SAVE_DEC_PRIVATE_MODE_VALUES, "s", "?");
			add_csi_sequence_pattern(ControlSequenceType.WINDOW_MANIPULATION, "t");
			add_csi_sequence_pattern(ControlSequenceType.REVERSE_ATTRIBUTES_IN_RECTANGULAR_AREA, "$t");
			add_csi_sequence_pattern(ControlSequenceType.SET_TITLE_MODES_FEATURES, "t", ">");
			add_csi_sequence_pattern(ControlSequenceType.SET_WARNING_BELL_VOLUME, " t");
			// TODO: This is a hack to match the EXACT sequence CSI + "u"
			add_csi_sequence_pattern(ControlSequenceType.RESTORE_CURSOR_ANSI_SYS, "u");
			add_csi_sequence_pattern(ControlSequenceType.SET_MARGIN_BELL_VOLUME, " u");
			add_csi_sequence_pattern(ControlSequenceType.COPY_RECTANGULAR_AREA, "$v");
			add_csi_sequence_pattern(ControlSequenceType.ENABLE_FILTER_RECTANGLE, "’w");
			add_csi_sequence_pattern(ControlSequenceType.REQUEST_TERMINAL_PARAMETERS, "x");
			add_csi_sequence_pattern(ControlSequenceType.SELECT_ATTRIBUTE_CHANGE_EXTENT, "*x");
			add_csi_sequence_pattern(ControlSequenceType.REQUEST_CHECKSUM_OF_RECTANGULAR_AREA, "*y");
			add_csi_sequence_pattern(ControlSequenceType.FILL_RECTANGULAR_AREA, "$x");
			add_csi_sequence_pattern(ControlSequenceType.ENABLE_LOCATOR_REPORTING, "’z");
			add_csi_sequence_pattern(ControlSequenceType.ERASE_RECTANGULAR_AREA, "$z");
			add_csi_sequence_pattern(ControlSequenceType.SELECT_LOCATOR_EVENTS, "’{");
			add_csi_sequence_pattern(ControlSequenceType.SELECTIVE_ERASE_RECTANGULAR_AREA, "${");
			add_csi_sequence_pattern(ControlSequenceType.REQUEST_LOCATOR_POSITION, "’|");
			add_csi_sequence_pattern(ControlSequenceType.INSERT_COLUMNS, " }");
			add_csi_sequence_pattern(ControlSequenceType.DELETE_COLUMNS, " ~");

			// All xterm OSC control sequences
			// See http://invisible-island.net/xterm/ctlseqs/ctlseqs.html
			add_osc_sequence_pattern(ControlSequenceType.SET_TEXT_PARAMETERS,
					// Negative lookahead
					"(?!" + Regex.escape_string(FINAL_TERM_PATTERN_DESIGNATOR) + ")" +
					PARAMETER_LIST_PATTERN);

			// Final Term control sequences (note that these are actually OSC sequences)
			add_final_term_sequence_pattern(ControlSequenceType.FTCS_PROMPT, "A");
			add_final_term_sequence_pattern(ControlSequenceType.FTCS_COMMAND_START, "B");
			add_final_term_sequence_pattern(ControlSequenceType.FTCS_COMMAND_EXECUTED, "C");
			add_final_term_sequence_pattern(ControlSequenceType.FTCS_COMMAND_FINISHED, "D");
			add_final_term_sequence_pattern(ControlSequenceType.FTCS_TEXT_MENU_START, "E");
			add_final_term_sequence_pattern(ControlSequenceType.FTCS_TEXT_MENU_END, "F");
			add_final_term_sequence_pattern(ControlSequenceType.FTCS_PROGRESS, "G");

			// xterm implements no PM functions
			// See http://invisible-island.net/xterm/ctlseqs/ctlseqs.html
		}

		private static void add_scf_sequence_pattern(ControlSequenceType control_sequence_type, string character) {
			add_sequence_pattern(
					control_sequence_type,
					Regex.escape_string(character),
					get_final_character(character));
		}

		private static void add_esc_sequence_pattern(ControlSequenceType control_sequence_type, string final_characters) {
			add_sequence_pattern(
					control_sequence_type,
					ESC_PATTERN_START + Regex.escape_string(final_characters),
					get_final_character(final_characters));
		}

		// Handles the special, ugly cases where the final character
		// of a control sequence is not unique but rather acts as a parameter
		private static void add_designate_character_set_sequence_pattern(ControlSequenceType control_sequence_type,
					string intermediate_character) {
			var pattern_builder = new StringBuilder();
			pattern_builder.append(ESC_PATTERN_START);
			pattern_builder.append(Regex.escape_string(intermediate_character));
			pattern_builder.append("([");
			foreach (var final_character in CHARACTER_SET_DESIGNATOR_FINAL_CHARACTERS) {
				pattern_builder.append(Regex.escape_string(final_character));
			}
			pattern_builder.append("])");

			foreach (var final_character in CHARACTER_SET_DESIGNATOR_FINAL_CHARACTERS) {
				add_sequence_pattern(
						control_sequence_type,
						pattern_builder.str,
						get_final_character(final_character));
			}
		}

		private static void add_dcs_sequence_pattern(ControlSequenceType control_sequence_type,
					string intermediate_characters) {
			add_sequence_pattern(
					control_sequence_type,

					DCS_PATTERN_START +
					Regex.escape_string(intermediate_characters) +
					PARAMETER_LIST_PATTERN +
					DCS_PATTERN_END,

					get_final_character("\x9C"));
		}

		private static void add_csi_sequence_pattern(ControlSequenceType control_sequence_type,
					string final_characters, string private_mode_characters = "") {
			// TODO: Remove round brackets from sequence (compare http://lucentbeing.com/blog/that-256-color-thing/)
			add_sequence_pattern(
					control_sequence_type,

					CSI_PATTERN_START +
					Regex.escape_string(private_mode_characters) +
					PARAMETER_LIST_PATTERN +
					Regex.escape_string(final_characters),

					get_final_character(final_characters));
		}

		private static void add_osc_sequence_pattern(ControlSequenceType control_sequence_type,
					string intermediate_pattern) {
			foreach (var final_character in OSC_FINAL_CHARACTERS) {
				add_sequence_pattern(
						control_sequence_type,
						OSC_PATTERN_START + intermediate_pattern + OSC_PATTERN_END,
						get_final_character(final_character));
			}
		}

		private static void add_final_term_sequence_pattern(ControlSequenceType control_sequence_type,
					string intermediate_characters) {
			// Final Term control sequences are of the form
			//
			// OSC 133 ; { intermediate_characters ; parameter_1 (; parameter_2 [...]) } BEL
			//
			// Since the part in curly parentheses is a printable string, it matches the
			// "Pt" specification in http://invisible-island.net/xterm/ctlseqs/ctlseqs.html,
			// thus making Final Term control sequences OSC sequences with an unused "Ps" value,
			// which should be ignored by other terminal emulators (though in practice they aren't).
			add_osc_sequence_pattern(control_sequence_type,

					Regex.escape_string(FINAL_TERM_PATTERN_DESIGNATOR) +
					Regex.escape_string(intermediate_characters) + ";" +
					PARAMETER_LIST_PATTERN);
		}

		private static void add_sequence_pattern(ControlSequenceType control_sequence_type, string pattern,
					unichar final_character) {
			// TODO: A vala bug prevents inlining this (GCC error)
			Regex patternRegex;
			try {
				patternRegex = new Regex(pattern, RegexCompileFlags.OPTIMIZE);
			} catch (Error e) { error(e.message); }

			control_sequence_specifications.set(
					final_character,
					ControlSequenceSpecification() { type = control_sequence_type, pattern = patternRegex });
		}

		private static unichar get_final_character(string text) {
			// TODO: According to valadoc a negative offset can be used here,
			//       but this seems not to work (returns empty character)
			return text.get_char(text.index_of_nth_char(text.char_count() - 1));
		}

		public StreamElement.from_text(string text) {
			stream_element_type = StreamElementType.TEXT;
			this.text = text;
		}

		public StreamElement.from_control_sequence(string control_sequence) {
			stream_element_type = StreamElementType.CONTROL_SEQUENCE;
			text = control_sequence;

			control_sequence_type = ControlSequenceType.UNKNOWN;
			control_sequence_parameters = new Gee.ArrayList<string>();

			var final_character = get_final_character(control_sequence);

			if (!control_sequence_specifications.contains(final_character))
				return;

			MatchInfo match_info;
			foreach (var specification in control_sequence_specifications.get(final_character)) {
				// Left-anchored matching ensures that patterns which are contained within other patterns
				// (such as BELL within SET_TEXT_PARAMETERS) do not lead to sequences being confused
				// without requiring any additional checks, since a control sequence can never
				// be the prefix of another control sequence for obvious reasons
				if (specification.pattern.match(control_sequence, RegexMatchFlags.ANCHORED, out match_info)) {
					control_sequence_type = specification.type;

					//message(_("Control sequence recognized: '%s' = '%s'"), control_sequence, control_sequence_type.to_string());

					// 0 is the full text of the match, 1 is the first capturing group,
					// which matches the parameter part of the sequence
					// TODO: Does this work with non-CSI sequences?
					var parameter_string = match_info.fetch(1);

					if (parameter_string == null || parameter_string == "")
						break;

					control_sequence_parameters = parse_sequence_parameters(parameter_string);

					break;
				}
			}
		}

		// An unfortunate necessity because Regexes don't support
		// a variable number of capturing groups
		// TODO: Handle case where text parameter contains the delimiter!
		private static Gee.List<string> parse_sequence_parameters(string parameter_string) {
			var parameters = new Gee.ArrayList<string>();

			string[] parts = parameter_string.split(PARAMETER_LIST_DELIMITER);

			// Another necessity because Gee collections
			// cannot be directly created from an array
			foreach (string part in parts) {
				parameters.add(part);
			}

			return parameters;
		}

		public int get_numeric_parameter(int index, int default_value) {
			if (control_sequence_parameters.size <= index) {
				// No parameter with specified index exists
				return default_value;
			} else {
				return int.parse(control_sequence_parameters.get(index));
			}
		}

		public string get_text_parameter(int index, string default_value) {
			if (control_sequence_parameters.size <= index) {
				// No parameter with specified index exists
				return default_value;
			} else {
				return control_sequence_parameters.get(index);
			}
		}

	}

}
