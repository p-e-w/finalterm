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

public class Command : Object {

	public enum CommandType {
		SEND_TO_SHELL,
		CLEAR_SHELL_COMMAND,
		SET_SHELL_COMMAND,
		RUN_SHELL_COMMAND,
		TOGGLE_VISIBLE,
		TOGGLE_FULLSCREEN,
		TOGGLE_DROPDOWN,
		PRINT_METRICS,
		COPY_TO_CLIPBOARD,
		OPEN_URL
	}

	public CommandType command { get; set; }
	public Gee.List<string> parameters { get; set; }

	private static Regex command_pattern;

	public delegate void CommandExecuteFunction(Command command);

	public static CommandExecuteFunction execute_function;

	public static void initialize() {
		try {
			// Supports up to 5 parameters
			// Note the DOTALL flag, required because parameters may contain newlines
			command_pattern = new Regex(
				"(\\w+)(?:\\s+\"(.*?)\")?(?:\\s+\"(.*?)\")?(?:\\s+\"(.*?)\")?(?:\\s+\"(.*?)\")?(?:\\s+\"(.*?)\")?",
				RegexCompileFlags.OPTIMIZE | RegexCompileFlags.DOTALL);
		} catch (Error e) { error(e.message); }
	}

	public Command.from_command_specification(string command_specification) {
		MatchInfo match_info;
		if (!command_pattern.match(command_specification, 0, out match_info)) {
			warning("Invalid command specification: '%s'", command_specification);
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

			// Replace placeholder "$$$i$$$" with placeholder_substitutes[i - 1]
			// in all parameters
			foreach (var parameter in parameters) {
				var substitute_parameter = parameter;
				for (int i = 0; i < placeholder_substitutes.size; i++) {
					substitute_parameter = substitute_parameter.replace(
							"$$$" + (i + 1).to_string() + "$$$",
							placeholder_substitutes.get(i));
				}
				substitute_command.parameters.add(substitute_parameter);
			}

			substitute_command.execute();
		}
	}

}
