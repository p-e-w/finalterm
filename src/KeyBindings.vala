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

public class KeyBindings : Object {

	private static Gee.List<KeyBinding> key_bindings;

	// TODO: Make this a struct
	private class KeyBinding : Object {
		public string key_specification;

		public uint key;
		public Gdk.ModifierType modifiers;
		public TerminalOutput.TerminalMode set_terminal_modes;
		public TerminalOutput.TerminalMode unset_terminal_modes;

		public Gee.List<Command> commands = new Gee.ArrayList<Command>();
	}

	private static Regex key_specification_pattern;

	public static void initialize() {
		key_bindings = new Gee.ArrayList<KeyBinding>();
		try {
			key_specification_pattern = new Regex("(.+)\\{(.+)\\}", RegexCompileFlags.OPTIMIZE);
		} catch (Error e) { error(e.message); }
	}

	public static void load_from_file(string filename) {
		var key_bindings_file = new KeyFile();
		try {
			key_bindings_file.load_from_file(filename, KeyFileFlags.NONE);
		} catch (Error e) { error(_("Loading key bindings file %s failed: %s"), filename, e.message); }

		try {
			string[] group_names = { "Global", "Application" };
			foreach (var group_name in group_names) {
				foreach (var key_specification in key_bindings_file.get_keys(group_name)) {
					var key_binding = new KeyBinding();
					key_binding.key_specification = key_specification;

					var accelerator = key_specification;

					MatchInfo match_info;
					if (key_specification_pattern.match(key_specification, 0, out match_info)) {
						// Specification includes terminal modes
						accelerator = match_info.fetch(1).strip();

						foreach (var mode_specification in match_info.fetch(2).split(";")) {
							mode_specification = mode_specification.strip();
							if (mode_specification.length == 0) {
								warning(_("Invalid key specification (empty mode): '%s'"), key_specification);
								continue;
							}

							bool negated_mode = (mode_specification.substring(0, 1) == "~");
							if (negated_mode)
								mode_specification = mode_specification.substring(1).strip();

							TerminalOutput.TerminalMode terminal_mode = Utilities.get_enum_value_from_name(
									typeof(TerminalOutput.TerminalMode),
									"TERMINAL_OUTPUT_TERMINAL_MODE_" + mode_specification.up());

							if (negated_mode) {
								key_binding.unset_terminal_modes |= terminal_mode;
							} else {
								key_binding.set_terminal_modes |= terminal_mode;
							}
						}
					}

					Gtk.accelerator_parse(accelerator, out key_binding.key, out key_binding.modifiers);

					foreach (var command_specification in key_bindings_file.get_string_list(group_name, key_specification)) {
						key_binding.commands.add(new Command.from_command_specification(command_specification));
					}

					key_bindings.add(key_binding);

					if (group_name == "Global") {
						// Keybinder.bind is declared in the VAPI file with
						// [CCode(has_target=false)], so the closure does not receive
						// the context information needed to use the commands variable.
						// As a workaround, the key specification is passed as
						// user data and the commands are retrieved when the
						// callback is invoked.
						Keybinder.bind(accelerator, (keystring, user_data) => {
							//message(_("Global key: %s"), (string)user_data);
							foreach (var key_binding_inner in key_bindings) {
								if (key_binding_inner.key_specification == (string)user_data) {
									foreach (var command in key_binding_inner.commands) {
										command.execute();
									}
									break;
								}
							}
						},
						// Trick to create a new string in-place to avoid
						// the data at the variable's address getting overwritten
						key_specification + "");
					}
				}
			}
		} catch (Error e) { warning(_("Error in key bindings file %s: %s"), filename, e.message); }
	}

	public static Gee.List<Command>? get_key_commands(uint key, Gdk.ModifierType modifiers,
				TerminalOutput.TerminalMode terminal_modes) {
		foreach (var key_binding in key_bindings) {
			if (key_binding.key != key)
				continue;
			if ((key_binding.modifiers & modifiers) != key_binding.modifiers)
				continue;
			if ((key_binding.set_terminal_modes & terminal_modes) != key_binding.set_terminal_modes)
				continue;
			if ((key_binding.unset_terminal_modes & terminal_modes) != 0)
				continue;

			return key_binding.commands;
		}

		return null;
	}

}
