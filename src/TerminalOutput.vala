/*
 * Copyright © 2013–2014 Philipp Emanuel Weidmann <pew@worldwidemann.com>
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
 * Interprets a terminal stream, generating line-by-line formatted screen output
 *
 * The list elements of this class are mutable,
 * because the screen output can be retroactively
 * modified by control sequences.
 */
public class TerminalOutput : Gee.ArrayList<OutputLine> {

	private Terminal terminal;

	public string terminal_title { get; set; default = "Final Term"; }

	public TerminalMode terminal_modes { get; set; }

	[Flags]
	public enum TerminalMode {
		KEYPAD,
		NUMLOCK, // Currently unsupported
		CURSOR,
		CRLF
	}

	private CharacterAttributes current_attributes;

	// Number of lines the virtual "screen" is shifted down
	// with respect to the full terminal output
	public int screen_offset { get; set; }

	// The cursor's position within the full terminal output,
	// not its position on the screen
	public CursorPosition cursor_position = CursorPosition();

	public struct CursorPosition {
		public int line;
		public int column;

		public int compare(CursorPosition position) {
			int line_difference = line - position.line;

			if (line_difference != 0)
				return line_difference;

			return column - position.column;
		}
	}

	private string transient_text = "";
	private string printed_transient_text = "";

	private string last_command = null;

	public bool command_mode = false;
	public CursorPosition command_start_position;

	public TerminalOutput(Terminal terminal) {
		this.terminal = terminal;

		// Default attributes
		current_attributes = new CharacterAttributes();

		screen_offset = 0;
		move_cursor(0, 0);

		line_updated.connect(on_line_updated);
	}

	// TODO: Rename to "interpret_stream_element"?
	public void parse_stream_element(TerminalStream.StreamElement stream_element) {
		switch (stream_element.stream_element_type) {
		case TerminalStream.StreamElement.StreamElementType.TEXT:
			//message(_("Text sequence received: '%s'"), stream_element.text);

			// Print only text that has not been printed yet
			string text_left = stream_element.text.substring(
					stream_element.text.index_of_nth_char(
						printed_transient_text.char_count()));

			if (text_left.length == 0)
				break;

			print_text(text_left);
			line_updated(cursor_position.line);
			break;

		case TerminalStream.StreamElement.StreamElementType.CONTROL_SEQUENCE:
			//message(_("Control sequence received: '%s' = '%s'"), stream_element.text, stream_element.control_sequence_type.to_string());

			// Descriptions of control sequence effects are taken from
			// http://vt100.net/docs/vt100-ug/chapter3.html,
			// which is more detailed than xterm's specification at
			// http://invisible-island.net/xterm/ctlseqs/ctlseqs.html
			switch (stream_element.control_sequence_type) {
			case TerminalStream.StreamElement.ControlSequenceType.CARRIAGE_RETURN:
				// Move cursor to the left margin on the current line
				move_cursor(cursor_position.line, 0);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FORM_FEED:
			case TerminalStream.StreamElement.ControlSequenceType.LINE_FEED:
			case TerminalStream.StreamElement.ControlSequenceType.VERTICAL_TAB:
				// This code causes a line feed or a new line operation
				// TODO: Does LF always imply CR?
				move_cursor(cursor_position.line + 1, 0);
				terminal.terminal_view.terminal_output_view.add_line_views();
				terminal.terminal_view.terminal_output_view.scroll_to_position();
				break;

			case TerminalStream.StreamElement.ControlSequenceType.HORIZONTAL_TAB:
				// Move the cursor to the next tab stop, or to the right margin
				// if no further tab stops are present on the line
				print_text("\t");
				line_updated(cursor_position.line);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.BELL:
				// TODO: Beep on the terminal window rather than the default display
				Gdk.beep();
				break;

			case TerminalStream.StreamElement.ControlSequenceType.APPLICATION_KEYPAD:
				terminal_modes |= TerminalMode.KEYPAD;
				break;

			case TerminalStream.StreamElement.ControlSequenceType.NORMAL_KEYPAD:
				terminal_modes &= ~TerminalMode.KEYPAD;
				break;

			// TODO: Implement unified system for setting and resetting flags
			case TerminalStream.StreamElement.ControlSequenceType.SET_MODE:
				for (int i = 0; i < stream_element.control_sequence_parameters.size; i++) {
					switch (stream_element.get_numeric_parameter(i, -1)) {
					case 20:
						// Automatic Newline
						terminal_modes |= TerminalMode.CRLF;
						break;
					default:
						print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
						break;
					}
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.RESET_MODE:
				for (int i = 0; i < stream_element.control_sequence_parameters.size; i++) {
					switch (stream_element.get_numeric_parameter(i, -1)) {
					case 20:
						// Normal Linefeed
						terminal_modes &= ~TerminalMode.CRLF;
						break;
					default:
						print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
						break;
					}
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DEC_PRIVATE_MODE_SET:
				for (int i = 0; i < stream_element.control_sequence_parameters.size; i++) {
					switch (stream_element.get_numeric_parameter(i, -1)) {
					case 1:
						// Application Cursor Keys
						terminal_modes |= TerminalMode.CURSOR;
						break;
					default:
						print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
						break;
					}
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DEC_PRIVATE_MODE_RESET:
				for (int i = 0; i < stream_element.control_sequence_parameters.size; i++) {
					switch (stream_element.get_numeric_parameter(i, -1)) {
					case 1:
						// Normal Cursor Keys
						terminal_modes &= ~TerminalMode.CURSOR;
						break;
					default:
						print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
						break;
					}
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.BACKSPACE:
				// Move the cursor to the left one character position,
				// unless it is at the left margin, in which case no action occurs
				move_cursor(cursor_position.line, cursor_position.column - 1);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_UP:
				// Moves the active position upward without altering the column position.
				// The number of lines moved is determined by the parameter (default: 1)
				move_cursor(cursor_position.line - stream_element.get_numeric_parameter(0, 1), cursor_position.column);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_DOWN:
			case TerminalStream.StreamElement.ControlSequenceType.LINE_POSITION_RELATIVE:
				// The CUD sequence moves the active position downward without altering the column position.
				// The number of lines moved is determined by the parameter (default: 1)
				move_cursor(cursor_position.line + stream_element.get_numeric_parameter(0, 1), cursor_position.column);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_FORWARD:
			case TerminalStream.StreamElement.ControlSequenceType.REVERSE_INDEX:
				screen_offset -= 1;
				move_cursor(cursor_position.line - stream_element.get_numeric_parameter(0,1), cursor_position.column);
				terminal.terminal_view.terminal_output_view.add_line_views();
				break;

			case TerminalStream.StreamElement.ControlSequenceType.NEXT_LINE:
				screen_offset += 1;
				move_cursor(cursor_position.line + stream_element.get_numeric_parameter(0,1), 0);
				terminal.terminal_view.terminal_output_view.add_line_views();
				break;

			case TerminalStream.StreamElement.ControlSequenceType.INDEX:
				screen_offset += 1;
				move_cursor(cursor_position.line + stream_element.get_numeric_parameter(0,1), cursor_position.column);
				terminal.terminal_view.terminal_output_view.add_line_views();
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CHARACTER_POSITION_RELATIVE:
				// The CUF sequence moves the active position to the right.
				// The distance moved is determined by the parameter (default: 1)
				move_cursor(cursor_position.line, cursor_position.column + stream_element.get_numeric_parameter(0, 1));
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_BACKWARD:
				// The CUB sequence moves the active position to the left.
				// The distance moved is determined by the parameter (default: 1)
				move_cursor(cursor_position.line, cursor_position.column - stream_element.get_numeric_parameter(0, 1));
				break;

			case TerminalStream.StreamElement.ControlSequenceType.ERASE_IN_DISPLAY_ED:
				switch (stream_element.get_numeric_parameter(0, 0)) {
				case 0:
					// Erase from the active position to the end of the screen, inclusive (default)
					erase_range_screen(get_screen_position(cursor_position));
					break;
				case 1:
					// Erase from start of the screen to the active position, inclusive
					erase_range_screen({1, 1}, get_screen_position(cursor_position));
					break;
				case 2:
					// Erase all of the display - all lines are erased, changed to single-width,
					// and the cursor does not move
					//erase_range_screen();

					/*
					 * THE SECRET OF MODERN TERMINAL SCROLLING
					 *
					 * The text terminal that xterm emulates (VT100) is based on a
					 * single-screen model, i.e. output that is deleted from the screen
					 * or scrolled above the first line disappears forever.
					 * Today, users expect their graphical terminal emulators to
					 * preserve past output and make it accessible by scrolling back up
					 * even when that output is "deleted" with the "Erase in Display"
					 * control sequence.
					 *
					 * The recipe for the proper behavior (which seems to be the one
					 * followed by other graphical terminal emulators as well) is to
					 * replace the action of the "Erase All" subcommand as specified
					 * for VT100 (i.e. wipe the current screen) with the following:
					 *
					 * - Scroll the view down as many lines as are visible (used)
					 *   on the current virtual screen
					 * - Shift the virtual screen as many lines downward
					 * - Move the cursor as many lines downward
					 *
					 * Actually, the behavior implemented by GNOME Terminal is slightly
					 * different, but this recipe gives better results.
					 */
					int visible_lines = size - screen_offset;
					screen_offset += visible_lines;
					move_cursor(cursor_position.line + visible_lines, cursor_position.column);

					break;

				case 3:
					// Erase Saved Lines (xterm)
					print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
					break;
				default:
					print_interpretation_status(stream_element, InterpretationStatus.INVALID);
					break;
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.ERASE_IN_LINE_EL:
				switch (stream_element.get_numeric_parameter(0, 0)) {
				case 0:
					// Erase from the active position to the end of the line, inclusive (default)
					erase_line_range(cursor_position.line, cursor_position.column);
					break;
				case 1:
					// Erase from the start of the screen to the active position, inclusive
					// TODO: Is this "inclusive"?
					// TODO: Should this erase from the start of the LINE instead (as implemented here)?
					erase_line_range(cursor_position.line, 0, cursor_position.column);
					break;
				case 2:
					// Erase all of the line, inclusive
					erase_line_range(cursor_position.line);
					break;
				default:
					print_interpretation_status(stream_element, InterpretationStatus.INVALID);
					break;
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.ERASE_CHARACTERS:
				// "Erase" means "clear" in this case (i.e. fill with whitespace)
				var text_element = new TextElement(
						Utilities.repeat_string(" ", stream_element.get_numeric_parameter(0, 1)),
						current_attributes);
				get(cursor_position.line).insert_element(text_element, cursor_position.column, true);
				line_updated(cursor_position.line);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DELETE_CHARACTERS:
				// This control function deletes one or more characters from the cursor position to the right
				erase_line_range(cursor_position.line, cursor_position.column,
						cursor_position.column + stream_element.get_numeric_parameter(0, 1));
				break;

			case TerminalStream.StreamElement.ControlSequenceType.HORIZONTAL_AND_VERTICAL_POSITION:
			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_POSITION:
				int line   = stream_element.get_numeric_parameter(0, 1);
				int column = stream_element.get_numeric_parameter(1, 1);
				move_cursor_screen(line, column);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.LINE_POSITION_ABSOLUTE:
				move_cursor_screen(stream_element.get_numeric_parameter(0, 1),
						get_screen_position(cursor_position).column);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_CHARACTER_ABSOLUTE:
			case TerminalStream.StreamElement.ControlSequenceType.CHARACTER_POSITION_ABSOLUTE:
				move_cursor_screen(get_screen_position(cursor_position).line,
						stream_element.get_numeric_parameter(0, 1));
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CHARACTER_ATTRIBUTES:
				current_attributes = new CharacterAttributes.from_stream_element(stream_element, current_attributes);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DESIGNATE_G0_CHARACTER_SET_VT100:
				// The program "top" emits this sequence repeatedly
				//print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.SET_TEXT_PARAMETERS:
				switch (stream_element.get_numeric_parameter(0, -1)) {
				case 0:
					// Change Icon Name and Window Title
					terminal_title = stream_element.get_text_parameter(1, "Final Term");
					// TODO: Change icon name(?)
					print_interpretation_status(stream_element, InterpretationStatus.PARTIALLY_SUPPORTED);
					break;
				case 2:
					// Change Window Title
					terminal_title = stream_element.get_text_parameter(1, "Final Term");
					break;
				default:
					print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
					break;
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_PROMPT:
				get(cursor_position.line).is_prompt_line = true;
				line_updated(cursor_position.line);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_COMMAND_START:
				if (command_mode)
					// TODO: This can happen with malformed multi-line commands
					warning(_("Command start control sequence received while already in command mode"));
				command_mode = true;
				command_start_position = cursor_position;
				message(_("Command mode entered"));
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_COMMAND_EXECUTED:
				command_mode = false;
				last_command = stream_element.get_text_parameter(0, "");
				command_executed(last_command);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_COMMAND_FINISHED:
				var return_code = stream_element.get_numeric_parameter(0, 0);

				if (last_command != null) {
					command_finished(last_command, return_code);
					progress_finished();

					// Set return code in corresponding prompt line
					for (int i = size - 1; i >= 0; i--) {
						if (get(i).is_prompt_line) {
							get(i).return_code = return_code;
							line_updated(i);
							break;
						}
					}
				}

				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_TEXT_MENU_START:
				current_attributes = new CharacterAttributes.copy(current_attributes);
				current_attributes.text_menu = FinalTerm.text_menus_by_code.get(stream_element.get_numeric_parameter(0, -1));
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_TEXT_MENU_END:
				current_attributes = new CharacterAttributes.copy(current_attributes);
				current_attributes.text_menu = null;
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_PROGRESS:
				var percentage = stream_element.get_numeric_parameter(0, -1);
				if (percentage == -1) {
					progress_finished();
				} else {
					var operation = stream_element.get_text_parameter(1, "");
					progress_updated(percentage, operation);
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_EXECUTE_COMMANDS:
				var commands = new Gee.ArrayList<Command>();
				var arguments = new Gee.ArrayList<string>();

				var is_argument = false;
				foreach (var parameter in stream_element.control_sequence_parameters) {
					// The "#" character acts as a separator between commands and arguments
					if (parameter == "#" && !is_argument) {
						is_argument = true;
						continue;
					}

					parameter = parameter.strip();

					if (parameter != "") {
						if (is_argument) {
							arguments.add(parameter);
						} else {
							commands.add(new Command.from_command_specification(parameter));
						}
					}
				}

				foreach (var command in commands) {
					command.execute(arguments);
				}

				break;

			case TerminalStream.StreamElement.ControlSequenceType.UNKNOWN:
				print_interpretation_status(stream_element, InterpretationStatus.UNRECOGNIZED);
				break;

			default:
				print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
				break;
			}
			break;
		}

		transient_text = "";
		printed_transient_text = "";
	}

	public enum InterpretationStatus {
		INVALID,
		UNRECOGNIZED,
		UNSUPPORTED,
		PARTIALLY_SUPPORTED,
		SUPPORTED
	}

	public static void print_interpretation_status(TerminalStream.StreamElement stream_element,
													InterpretationStatus interpretation_status) {
		if (stream_element.stream_element_type != TerminalStream.StreamElement.StreamElementType.CONTROL_SEQUENCE) {
			critical(_("print_interpretation_status should only be called on control sequence elements"));
			return;
		}

		switch (interpretation_status) {
		case InterpretationStatus.INVALID:
			warning(_("Invalid control sequence: '%s' (%s)"), stream_element.text,
					stream_element.control_sequence_type.to_string());
			break;
		case InterpretationStatus.UNRECOGNIZED:
			warning(_("Unrecognized control sequence: '%s' (%s)"), stream_element.text,
					stream_element.control_sequence_type.to_string());
			break;
		case InterpretationStatus.UNSUPPORTED:
			warning(_("Unsupported control sequence: '%s' (%s)"), stream_element.text,
					stream_element.control_sequence_type.to_string());
			break;
		case InterpretationStatus.PARTIALLY_SUPPORTED:
			message(_("Partially supported control sequence: '%s' (%s)"), stream_element.text,
					stream_element.control_sequence_type.to_string());
			break;
		case InterpretationStatus.SUPPORTED:
			debug(_("Supported control sequence: '%s' (%s)"), stream_element.text,
					stream_element.control_sequence_type.to_string());
			break;
		default:
			critical(_("Unrecognized interpretation status value"));
			break;
		}
	}

	public void parse_transient_text(string transient_text) {
		this.transient_text = transient_text;

		// Send update signal here to trigger render but do not print text;
		// the transient text will be printed just in time during render (performance)
		// TODO: Revisit this!
		line_updated(cursor_position.line);
	}

	public void print_transient_text() {
		// Print only text that has not been printed yet
		string text_left = transient_text.substring(
				transient_text.index_of_nth_char(
					printed_transient_text.char_count()));

		if (text_left.length == 0)
			return;

		print_text(text_left);

		// IMPORTANT: Do NOT send update signal here!
		//            This method is called when rendering the terminal
		//            and sending the signal would trigger another render.
		// Call on_line_updated instead to trigger other update logic.
		// TODO: Revisit this! Some command updates are being signaled multiple times
		on_line_updated(0);

		printed_transient_text += text_left;
	}

	public string get_command() {
		// TODO: Revisit this check (condition should never fail)
		if (command_start_position.compare(cursor_position) < 0) {
			return get_range(command_start_position, cursor_position);
		} else {
			return "";
		}
	}

	private void print_text(string text) {
		var text_element = new TextElement(text, current_attributes);
		get(cursor_position.line).insert_element(text_element, cursor_position.column, true);
		// TODO: Handle double-width unicode characters and tabs
		move_cursor(cursor_position.line, cursor_position.column + text_element.get_length());
	}

	private void on_line_updated(int line_index) {
		if (command_mode)
			command_updated(get_command());
	}

	private CursorPosition get_screen_position(CursorPosition position) {
		// Screen coordinates are 1-based (see http://vt100.net/docs/vt100-ug/chapter3.html)
		return {position.line - screen_offset + 1, position.column + 1};
	}

	private CursorPosition get_absolute_position(CursorPosition position) {
		return {position.line + screen_offset - 1, position.column - 1};
	}

	private void move_cursor(int line, int column) {
		// TODO: Use uint as a parameter type to ensure positivity here
		cursor_position.line   = int.max(line, 0);
		cursor_position.column = int.max(column, 0);

		// Ensure that the virtual screen contains the cursor
		screen_offset = int.max(screen_offset, cursor_position.line - terminal.lines + 1);

		// Add enough lines to make the line index valid
		int lines_to_add = cursor_position.line - size + 1;
		if (lines_to_add > 0) {
			for (int i = 0; i < lines_to_add; i++)
				add(new OutputLine());

			line_added();
		}

		// Add enough whitespace to make the column index valid
		int columns_to_add = cursor_position.column - get(cursor_position.line).get_length();
		if (columns_to_add > 0) {
			var text_element = new TextElement(
					Utilities.repeat_string(" ", columns_to_add),
					current_attributes);
			get(cursor_position.line).add(text_element);
		}

		cursor_position_changed(cursor_position);
	}

	private void move_cursor_screen(int line, int column) {
		// TODO: Coordinates of (0, 0) should act like (1, 1) according to specification
		move_cursor(line + screen_offset - 1, column - 1);
	}

	// Returns the text contained in the specified range
	private string get_range(CursorPosition start_position = {0, 0},
							 CursorPosition end_position   = {size - 1, get(size - 1).get_length()}) {
		// TODO: This works with bytes rather than characters
		if (start_position.line == end_position.line) {
			var line_text = get(start_position.line).get_text();
			return line_text.substring(start_position.column, end_position.column - start_position.column);
		}

		var text_builder = new StringBuilder();

		// Works because start and end position are on different lines
		text_builder.append(get(start_position.line).get_text().substring(start_position.column));
		text_builder.append("\n");

		for (int i = start_position.line + 1; i < end_position.line; i++) {
			text_builder.append(get(i).get_text());
			text_builder.append("\n");
		}

		text_builder.append(get(end_position.line).get_text().substring(0, end_position.column));

		return text_builder.str;
	}

	private void erase_range(CursorPosition start_position, CursorPosition end_position) {
		if (start_position.line == end_position.line) {
			erase_line_range(start_position.line, start_position.column, end_position.column);
			return;
		}

		// Works because start and end position are on different lines
		erase_line_range(start_position.line, start_position.column);

		for (int i = start_position.line + 1; i < end_position.line; i++) {
			erase_line_range(i);
		}

		erase_line_range(end_position.line, 0, end_position.column);
	}

	private void erase_range_screen(CursorPosition start_position = {1, 1},
									CursorPosition end_position   = {terminal.lines, terminal.columns + 1}) {
		var absolute_start_position = get_absolute_position(start_position);
		var absolute_end_position   = get_absolute_position(end_position);

		// Constrain positions to permissible range
		absolute_start_position.line = int.min(absolute_start_position.line, size - 1);
		absolute_start_position.column = int.min(absolute_start_position.column,
				get(absolute_start_position.line).get_length());
		absolute_end_position.line = int.min(absolute_end_position.line, size - 1);
		absolute_end_position.column = int.min(absolute_end_position.column,
				get(absolute_end_position.line).get_length());

		erase_range(absolute_start_position, absolute_end_position);
	}

	private void erase_line_range(int line, int start_position = 0, int end_position = -1) {
		get(line).erase_range(start_position, end_position);
		line_updated(line);
	}

	public signal void line_added();

	public signal void line_updated(int line_index);

	public signal void command_updated(string command);

	public signal void command_executed(string command);

	public signal void command_finished(string command, int return_code);

	public signal void progress_updated(int percentage, string operation);

	public signal void progress_finished();

	public signal void cursor_position_changed(CursorPosition new_position);


	public class OutputLine : Gee.ArrayList<TextElement> {

		public bool is_prompt_line { get; set; default = false; }
		public int return_code { get; set; default = 0; }

		// Returns a new OutputLine object reflecting
		// matching text menu patterns if there are any
		// and this object otherwise (the function is
		// therefore guaranteed to never modify this object)
		public OutputLine generate_text_menu_elements() {
			var matching_pattern = false;
			var text = get_text();
			foreach (var pattern in FinalTerm.text_menus_by_pattern.keys) {
				matching_pattern = (matching_pattern || pattern.match(text));
			}

			if (!matching_pattern)
				return this;

			OutputLine output_line = new OutputLine();
			output_line.is_prompt_line = is_prompt_line;
			output_line.return_code = return_code;
			foreach (var text_element in this) {
				output_line.add_all(text_element.get_text_menu_elements());
			}
			return output_line;
		}

		public void insert_element(TextElement text_element, int position, bool overwrite = false) {
			// TODO: Handle position > length
			if (position == get_length()) {
				add(text_element);
				return;
			}

			var character_elements = explode();
			var result_elements = new Gee.ArrayList<TextElement>();

			result_elements.add_all(character_elements.slice(0, position));
			result_elements.add(text_element);

			int next_position = (overwrite ? position + text_element.get_length() : position);

			// This check is necessary because slice
			// returns null if start > stop
			if (next_position <= get_length())
				result_elements.add_all(character_elements.slice(next_position, get_length()));

			assemble(result_elements);
		}
		
		// TODO: Convert position variables to long (cf. GLib.string)?
		// TODO: Use contract programming (requires/ensures) to ensure positions are acceptable
		public void erase_range(int start_position = 0, int end_position = -1) {
			var character_elements = explode();
			var result_elements = new Gee.ArrayList<TextElement>();

			result_elements.add_all(character_elements.slice(0, start_position));
			if (end_position != -1)
				result_elements.add_all(character_elements.slice(end_position, get_length()));

			// TODO: Simple add sufficient (only optimize on render)?
			assemble(result_elements);
		}

		public void optimize() {
			var text_elements = new Gee.ArrayList<TextElement>();
			text_elements.add_all(this);
			assemble(text_elements);
		}

		// Returns a character-by-character representation of the line
		public Gee.List<TextElement> explode() {
			var character_elements = new Gee.ArrayList<TextElement>();
			foreach (var text_element in this) {
				character_elements.add_all(text_element.explode());
			}

			return character_elements;
		}

		// Assembles the supplied list of text elements into
		// the minimum number of elements required to preserve
		// all character attributes
		public void assemble(Gee.List<TextElement> text_elements) {
			clear();

			if (text_elements.is_empty)
				return;

			// Works because list is not empty
			var current_attributes = text_elements.get(0).attributes;
			var text_builder = new StringBuilder();

			foreach (var text_element in text_elements) {
				if (!text_element.attributes.equals(current_attributes)) {
					add(new TextElement(text_builder.str, current_attributes));
					current_attributes = text_element.attributes;
					text_builder.erase();
				}
				text_builder.append(text_element.text);
			}

			if (text_builder.len > 0) {
				// Add final element
				add(new TextElement(text_builder.str, current_attributes));
			}
		}

		public int get_length() {
			int length = 0;
			foreach (var text_element in this) {
				length += text_element.get_length();
			}
			return length;
		}

		public string get_text() {
			var text_builder = new StringBuilder();
			foreach (var text_element in this) {
				text_builder.append(text_element.text);
			}
			return text_builder.str;
		}

		public void get_text_element_from_index(int index, out TextElement? text_element, out int? position) {
			int current_index = 0;
			foreach (var current_element in this) {
				if (index >= current_index && index < (current_index + current_element.get_length())) {
					text_element = current_element;
					position = current_index;
					return;
				}
				current_index += current_element.get_length();
			}

			text_element = null;
			position = null;
		}

	}


	// TODO: Make this a struct?
	public class TextElement : Object {

		public string text { get; set; }
		public CharacterAttributes attributes { get; set; }

		public TextElement(string text, CharacterAttributes attributes) {
			this.text = text;
			this.attributes = attributes;
		}

		public TextElement.copy(TextElement text_element) {
			text = text_element.text;
			attributes = new CharacterAttributes.copy(text_element.attributes);
		}

		public Gee.List<TextElement> get_text_menu_elements() {
			var old_text_elements = new Gee.ArrayList<TextElement>();
			var current_text_elements = new Gee.ArrayList<TextElement>();

			current_text_elements.add(new TextElement.copy(this));

			foreach (var pattern in FinalTerm.text_menus_by_pattern.keys) {
				old_text_elements.clear();
				old_text_elements.add_all(current_text_elements);
				current_text_elements.clear();

				foreach (var text_element in old_text_elements) {
					current_text_elements.add_all(get_text_menu_elements_for_pattern(text_element, pattern));
				}
			}

			return current_text_elements;
		}

		public Gee.List<TextElement> get_text_menu_elements_for_pattern(TextElement text_element, Regex pattern) {
			var text_elements = new Gee.ArrayList<TextElement>();

			MatchInfo match_info;
			if (pattern.match(text_element.text, 0, out match_info)) {
				int old_end_position = 0;

				// Loop over all matches and split them off as
				// separate text elements with the appropriate
				// text menu attached to them
				try {
					do {
						int start_position;
						int end_position;
						match_info.fetch_pos(0, out start_position, out end_position);

						if (start_position > old_end_position) {
							// There is text to the left of the match
							text_elements.add(new TextElement(
									text_element.text.substring(old_end_position, start_position - old_end_position),
									new CharacterAttributes.copy(text_element.attributes)));
						}

						var character_attributes = new CharacterAttributes.copy(text_element.attributes);
						character_attributes.text_menu = FinalTerm.text_menus_by_pattern.get(pattern);
						text_elements.add(new TextElement(
								text_element.text.substring(start_position, end_position - start_position),
								character_attributes));

						old_end_position = end_position;
					} while (match_info.next());
				} catch (Error e) { warning(e.message); }

				if (old_end_position < text_element.text.length) {
					// There is text to the right of the last match
					text_elements.add(new TextElement(
							text_element.text.substring(old_end_position),
							new CharacterAttributes.copy(text_element.attributes)));
				}

			} else {
				text_elements.add(text_element);
			}

			return text_elements;
		}

		public int get_length() {
			return text.char_count();
		}

		// Returns a list of TextElement objects, each of them
		// containing a single character from this element
		// and sharing this element's character attributes
		public Gee.List<TextElement> explode() {
			var character_elements = new Gee.ArrayList<TextElement>();
			for (int i = 0; i < text.char_count(); i++) {
				// TODO: This is highly inefficient
				// TODO: Potential problem as attributes is passed by reference
				character_elements.add(new TextElement(text.get_char(text.index_of_nth_char(i)).to_string(), attributes));
			}
			return character_elements;
		}

	}

}
