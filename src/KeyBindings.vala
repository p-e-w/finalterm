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

public class KeyBindings : Object {

	// A MultiMap is not sufficient here because
	// the order of the commands has to be preserved
	private static Gee.Map<string, Gee.List<Command>> key_bindings;

	public static void initialize() {
		key_bindings = new Gee.HashMap<string, Gee.List<Command>>();
	}

	public static void load_from_file(string filename) {
		var key_bindings_file = new KeyFile();
		try {
			key_bindings_file.load_from_file(filename, KeyFileFlags.NONE);
		} catch (Error e) { error("Loading key bindings file %s failed: %s", filename, e.message); }

		try {
			string[] group_names = { "Global", "Application" };
			foreach (var group_name in group_names) {
				foreach (var key_specification in key_bindings_file.get_keys(group_name)) {
					var commands = new Gee.ArrayList<Command>();
					foreach (var command_specification in key_bindings_file.get_string_list(group_name, key_specification)) {
						commands.add(new Command.from_command_specification(command_specification));
					}

					key_bindings.set(key_specification, commands);

					if (group_name == "Global") {
						// Keybinder.bind is declared in the VAPI file with
						// [CCode(has_target=false)], so the closure does not receive
						// the context information needed to use the commands variable.
						// As a workaround, the key specification is passed as
						// user data and the commands are retrieved when the
						// callback is invoked.
						Keybinder.bind(key_specification, (keystring, user_data) => {
							//message("Global key: %s", (string)user_data);
							foreach (var command in key_bindings.get((string)user_data)) {
								command.execute();
							}
						},
						// Trick to create a new string in-place to avoid
						// the data at the variable's address getting overwritten
						key_specification + "");
					}
				}
			}
		} catch (Error e) { warning("Error in keybindings file %s: %s", filename, e.message); }
	}

	public static Gee.List<Command>? get_key_commands(Gdk.ModifierType modifiers, uint key) {
		foreach (var key_specification in key_bindings.keys) {
			uint key_buffer;
			Gdk.ModifierType modifiers_buffer;
			Gtk.accelerator_parse(key_specification, out key_buffer, out modifiers_buffer);

			if (key_buffer == key &&
				(modifiers_buffer & modifiers) == modifiers_buffer) {
				return key_bindings.get(key_specification);
			}
		}

		return null;
	}

}
