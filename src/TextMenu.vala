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

public class TextMenu : Object {

	public MarkerType marker_type { get; set; }

	public enum MarkerType {
		CODE,
		PATTERN
	}

	public int code { get; set; }
	public Regex pattern { get; set; }

	public string label { get; set; }
	public int color { get; set; }

	public Gtk.Menu menu { get; set; }

	public string text { get; set; }

	public string escape_parameters(string s) {
		var escape_characters = new string[] {" ", "&", "'", ";", "#", "\"", "`", "|", "*", "?", "$", "<", ">", "(", ")", "~"};
		var backslash = "\\";
		string temp = s;
		
		foreach(var character in escape_characters) 
			temp = temp.replace(character, backslash.concat(character) );

		return temp;
	}


	public TextMenu.load_from_file(string filename) {
		var menu_file = new KeyFile();
		try {
			menu_file.load_from_file(filename, KeyFileFlags.NONE);
		} catch (Error e) { error(_("Failed to load text menu definitions %s: %s"), filename, e.message); }

		try {
			if (menu_file.get_string("Parameters", "marker-type") == "code") {
				marker_type = MarkerType.CODE;
				code = menu_file.get_integer("Parameters", "code");
			} else {
				marker_type = MarkerType.PATTERN;
				pattern = new Regex(menu_file.get_value("Parameters", "pattern"), RegexCompileFlags.OPTIMIZE);
			}

			label = menu_file.get_string("Parameters", "label");
			color = menu_file.get_integer("Parameters", "color");

			menu = new Gtk.Menu();

			foreach (var label in menu_file.get_keys("Menu")) {
				if (label == "$$$SEPARATOR$$$") {
					menu.append(new Gtk.SeparatorMenuItem());

				} else {
					var menu_item = new Gtk.MenuItem.with_label("");

					Gtk.Label menu_item_label = (Gtk.Label)menu_item.get_children().nth_data(0);
					menu_item_label.set_markup(label);

					var commands = new Gee.ArrayList<Command>();
					foreach (var command_specification in menu_file.get_string_list("Menu", label)) {
						commands.add(new Command.from_command_specification(command_specification));
					}

					menu_item.activate.connect(() => {
						var placeholder_substitutes = new Gee.ArrayList<string>();
						placeholder_substitutes.add(escape_parameters(text));
						foreach (var command in commands) {
							command.execute(placeholder_substitutes);
						}
					});

					menu.append(menu_item);
				}
			}

			menu.show_all();

		} catch (Error e) { warning(_("Error in text menu %s: %s"), filename, e.message); }
	}

}
