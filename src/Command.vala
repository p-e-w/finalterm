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

public class Command : Object {

	public enum CommandType {
		QUIT_PROGRAM,
		SEND_TO_SHELL,
		CLEAR_SHELL_COMMAND,
		SET_SHELL_COMMAND,
		RUN_SHELL_COMMAND,
		TOGGLE_VISIBLE,
		TOGGLE_FULLSCREEN,
		TOGGLE_DROPDOWN,
		ADD_TAB,
		SPLIT,
		CLOSE,
		LOG,
		PRINT_METRICS,
		PASTE_FROM_CLIPBOARD,
		COPY_TO_CLIPBOARD,
		OPEN_URL
	}

	public CommandType command { get; set; }
	public Gee.List<string> parameters { get; set; }

	private static Regex command_pattern;
	private static Regex placeholder_pattern;

	public delegate void CommandExecuteFunction(Command command);

	public static CommandExecuteFunction execute_function;

	public static void initialize() {
		try {
			// Supports up to 5 parameters
			// Note the DOTALL flag, required because parameters may contain newlines
			command_pattern = new Regex(
				"(\\w+)(?:\\s+\"(.*?)\")?(?:\\s+\"(.*?)\")?(?:\\s+\"(.*?)\")?(?:\\s+\"(.*?)\")?(?:\\s+\"(.*?)\")?",
				RegexCompileFlags.OPTIMIZE | RegexCompileFlags.DOTALL);
			placeholder_pattern = new Regex("%\\d", RegexCompileFlags.OPTIMIZE);
		} catch (Error e) { error(e.message); }
	}

	public Command.from_command_specification(string command_specification) {
		MatchInfo match_info;
		if (!command_pattern.match(command_specification, 0, out match_info)) {
			warning(_("Invalid command specification: '%s'"), command_specification);
			return;
		}

		// The first capturing group matches the command itself
		command = Utilities.get_enum_value_from_name(typeof(Command.CommandType),
				"COMMAND_COMMAND_TYPE_" + match_info.fetch(1));

		// The remaining capturing groups match the parameters
		parameters = new Gee.ArrayList<string>();
		for (int i = 2; i < match_info.get_match_count(); i++) {
			var parameter = match_info.fetch(i);
			// Required because KeyFile.get_string_list does not handle
			// all escape sequences in strings, making it impossible
			// to specify arbitrary non-printable characters such as ESC
			parameter = parameter.compress();
			parameters.add(parameter);
		}
	}

	public void execute(Gee.List<string>? placeholder_substitutes = null) {
		if (placeholder_substitutes == null) {
			execute_function(this);

		} else {
			var substitute_command = new Command();

			substitute_command.command = command;
			substitute_command.parameters = new Gee.ArrayList<string>();

			foreach (var parameter in parameters) {
				var substitute_parameter = parameter;

				// Replace placeholder "%i" with placeholder_substitutes[i - 1]
				for (int i = 0; i < placeholder_substitutes.size; i++) {
					substitute_parameter = substitute_parameter.replace(
							"%" + (i + 1).to_string(),
							placeholder_substitutes.get(i));
				}

				// Remove remaining placeholders
				substitute_parameter = placeholder_pattern.replace(substitute_parameter, -1, 0, "");

				substitute_command.parameters.add(substitute_parameter);
			}

			substitute_command.execute();
		}
	}

	public int get_numeric_parameter(int index, int default_value) {
		return int.parse(get_text_parameter(index, default_value.to_string()));
	}

	public string get_text_parameter(int index, string default_value) {
		if (parameters.size <= index) {
			// No parameter with specified index exists
			return default_value;
		} else {
			var parameter = parameters.get(index);
			return (parameter == "") ? default_value : parameter;
		}
	}

}
