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

public class Settings : Object {

	public string color_scheme_name { get; set; }
	public bool dark { get; set; }
	public string theme_name { get; set; }
	public double opacity { get; set; }

	public int terminal_lines { get; set; }
	public int terminal_columns { get; set; }

	public string shell_path { get; set; }
	public string emulated_terminal { get; set; }

	public int render_interval { get; set; }
	public int resize_interval { get; set; }

	public Settings.load_from_file(string filename) {
		var settings_file = new KeyFile();
		settings_file.load_from_file(filename, KeyFileFlags.NONE);

		color_scheme_name = settings_file.get_string("Settings", "color-scheme");
		dark = settings_file.get_boolean("Settings", "dark");
		theme_name = settings_file.get_string("Settings", "theme");
		opacity = settings_file.get_double("Settings", "opacity");

		terminal_lines = settings_file.get_integer("Settings", "terminal-lines");
		terminal_columns = settings_file.get_integer("Settings", "terminal-columns");

		shell_path = settings_file.get_string("Settings", "shell-path");
		emulated_terminal = settings_file.get_string("Settings", "emulated-terminal");

		render_interval = settings_file.get_integer("Settings", "render-interval");
		resize_interval = settings_file.get_integer("Settings", "resize-interval");
	}

}
