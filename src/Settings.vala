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

	public GLib.Settings settings { get; set; }

	public Settings.load_from_schema(string schema_name) {
		settings = new GLib.Settings(schema_name);

		color_scheme_name = settings.get_string("color-scheme");
		dark = settings.get_boolean("dark");
		theme_name = settings.get_string("theme");
		opacity = settings.get_double("opacity");

		terminal_lines = settings.get_int("terminal-lines");
		terminal_columns = settings.get_int("terminal-columns");

		shell_path = settings.get_string("shell-path");
		emulated_terminal = settings.get_string("emulated-terminal");

		render_interval = settings.get_int("render-interval");
		resize_interval = settings.get_int("resize-interval");
	}

}
