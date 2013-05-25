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
 * Interprets a terminal stream, generating line-by-line formatted screen output
 *
 * The list elements of this class are mutable,
 * because the screen output can be retroactively
 * modified by control sequences.
 */
public class TerminalOutput : Gee.ArrayList<OutputLine> {

	public string terminal_title { get; set; default = _("Final Term"); }

	private CharacterAttributes current_attributes;

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
	public CursorPosition command_end_position;

	public TerminalOutput() {
		// Default attributes
		current_attributes = new CharacterAttributes();
		add_new_line();
		move_cursor(0, 0);
		text_updated.connect(on_text_updated);
	}

	// TODO: Rename to "interpret_stream_element"?
	public void parse_stream_element(TerminalStream.StreamElement stream_element) {
		//Metrics.start_block_timer(Log.METHOD);

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
			text_updated(cursor_position.line);
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
				if (cursor_position.line == size - 1) {
					add_new_line();
				} else {
					// TODO: Does LF always imply CR?
					move_cursor(cursor_position.line + 1, 0);
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.BELL:
				// TODO: Beep on the terminal window rather than the default display
				Gdk.beep();
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
				// The CUD sequence moves the active position downward without altering the column position.
				// The number of lines moved is determined by the parameter (default: 1)
				move_cursor(cursor_position.line + stream_element.get_numeric_parameter(0, 1), cursor_position.column);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_FORWARD:
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
					erase_range(cursor_position);
					break;
				case 1:
					// Erase from start of the screen to the active position, inclusive
					erase_range({0, 0}, cursor_position);
					break;
				case 2:
					// Erase all of the display - all lines are erased, changed to single-width,
					// and the cursor does not move
					erase_range();
					break;
				case 3:
					// Erase Saved Lines (xterm)
					print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
					break;
				default:
					print_interpretation_status(stream_element, InterpretationStatus.INVALID);
					break;
				}
				text_updated(cursor_position.line);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.ERASE_IN_LINE_EL:
				switch (stream_element.get_numeric_parameter(0, 0)) {
				case 0:
					// Erase from the active position to the end of the line, inclusive (default)
					get(cursor_position.line).erase_range(cursor_position.column);
					break;
				case 1:
					// Erase from the start of the screen to the active position, inclusive
					// TODO: Is this "inclusive"?
					// TODO: Should this erase from the start of the LINE instead (as implemented here)?
					get(cursor_position.line).erase_range(0, cursor_position.column);
					break;
				case 2:
					// Erase all of the line, inclusive
					get(cursor_position.line).erase_range();
					break;
				default:
					print_interpretation_status(stream_element, InterpretationStatus.INVALID);
					break;
				}
				text_updated(cursor_position.line);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.DELETE_CHARACTERS:
				// This control function deletes one or more characters from the cursor position to the right
				get(cursor_position.line).erase_range(cursor_position.column,
						cursor_position.column + stream_element.get_numeric_parameter(0, 1));
				text_updated(cursor_position.line);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.CURSOR_POSITION:
				int line   = stream_element.get_numeric_parameter(0, 1);
				int column = stream_element.get_numeric_parameter(1, 1);
				move_cursor(line - 1, column - 1);
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
					terminal_title = stream_element.get_text_parameter(1, _("Final Term"));
					title_updated(terminal_title);
					// TODO: Change icon name(?)
					print_interpretation_status(stream_element, InterpretationStatus.PARTIALLY_SUPPORTED);
					break;
				case 2:
					// Change Window Title
					terminal_title = stream_element.get_text_parameter(1, _("Final Term"));
					title_updated(terminal_title);
					break;
				default:
					print_interpretation_status(stream_element, InterpretationStatus.UNSUPPORTED);
					break;
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_PROMPT_START:
				get(cursor_position.line).is_prompt_line = true;
				if (last_command != null)
					command_finished(last_command);
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_COMMAND_START:
				if (command_mode) {
					warning(_("Command start control sequence received while already in command mode"));
				} else {
					command_mode = true;
					command_start_position = cursor_position;
					message(_("Command mode entered"));
				}
				break;

			case TerminalStream.StreamElement.ControlSequenceType.FTCS_COMMAND_END:
				if (command_mode) {
					command_mode = false;
					// TODO: This breaks if cursor is moved backward using arrow keys
					command_end_position = cursor_position;
					last_command = get_command();
					command_executed(last_command);
				} else {
					// Commented out because this is actually a common occurrence and
					// makes the output very verbose
					// TODO: Investigate further when exactly this occurs
					//warning(_("Command end control sequence received while not in command mode"));
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

		//Metrics.stop_block_timer(Log.METHOD);
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
		//Metrics.start_block_timer(Log.METHOD);

		this.transient_text = transient_text;

		// Send update signal here to trigger render but do not print text;
		// the transient text will be printed just in time during render (performance)
		// TODO: Revisit this!
		text_updated(cursor_position.line);

		//Metrics.stop_block_timer(Log.METHOD);
	}

	public void print_transient_text() {
		//Metrics.start_block_timer(Log.METHOD);

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
		// Call on_text_updated instead to trigger other update logic.
		// TODO: Revisit this! Some command updates are being signalled multiple times
		on_text_updated(0);

		printed_transient_text += text_left;

		//Metrics.stop_block_timer(Log.METHOD);
	}

	public string get_command() {
		CursorPosition end_position;
		if (command_mode) {
			// TODO: This breaks if cursor is moved backward using arrow keys
			end_position = cursor_position;
		} else {
			end_position = command_end_position;
		}

		// TODO: Revisit this check (condition should never fail)
		if (command_start_position.compare(end_position) < 0) {
			return get_range(command_start_position, end_position);
		} else {
			return "";
		}
	}

	private void print_text(string text) {
		//Metrics.start_block_timer(Log.METHOD);

		var text_element = new TextElement(text, current_attributes);
		get(cursor_position.line).insert_element(text_element, cursor_position.column, true);
		// TODO: Handle double-width unicode characters
		move_cursor(cursor_position.line, cursor_position.column + text_element.get_length());

		//Metrics.stop_block_timer(Log.METHOD);
	}

	private void on_text_updated(int line_index) {
		if (command_mode)
			command_updated(get_command());
	}

	private void add_new_line() {
		add(new OutputLine());
		move_cursor(size, 0);
	}

	private void move_cursor(int line, int column) {
		// TODO: This should move the cursor to the specified position ON THE SCREEN!(?)
		// TODO: Should cursor be allowed to be positioned AFTER the final character?
		cursor_position.line   = Utilities.bound_value(line, 0, size - 1);
		cursor_position.column = Utilities.bound_value(column, 0, get(cursor_position.line).get_length());

		cursor_position_changed(cursor_position);
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

	private void erase_range(CursorPosition start_position = {0, 0},
							 CursorPosition end_position   = {size - 1, get(size - 1).get_length()}) {
		if (start_position.line == end_position.line) {
			get(start_position.line).erase_range(start_position.column, end_position.column);
			return;
		}

		// Works because start and end position are on different lines
		get(start_position.line).erase_range(start_position.column);

		for (int i = start_position.line + 1; i < end_position.line; i++) {
			get(i).erase_range();
		}

		get(end_position.line).erase_range(0, end_position.column);
	}

	public signal void text_updated(int line_index);

	public signal void command_updated(string command);

	public signal void command_executed(string command);

	public signal void command_finished(string command);

	public signal void title_updated(string new_title);

	public signal void progress_updated(int percentage, string operation);

	public signal void progress_finished();

	public signal void cursor_position_changed(CursorPosition new_position);


	public class OutputLine : Gee.ArrayList<TextElement> {

		public bool is_prompt_line { get; set; default = false; }

		public OutputLine.copy(OutputLine output_line) {
			is_prompt_line = output_line.is_prompt_line;

			foreach (var text_element in output_line) {
				add(new TextElement.copy(text_element));
			}
		}

		public void generate_text_menu_elements() {
			OutputLine old_output_line = new OutputLine.copy(this);

			clear();

			foreach (var text_element in old_output_line) {
				add_all(text_element.get_text_menu_elements());
			}
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
