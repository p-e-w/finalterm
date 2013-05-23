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

	private static Settings? instance = null;

	private GLib.Settings settings { get; set; }

	public bool dark {
		// TODO: GLib probably performs settings caching already.
		//       If not, that should be implemented here to avoid
		//       hitting the disk each time a value is retrieved.
		get { return settings.get_boolean("dark"); }
		set { settings.set_boolean("dark", value); }
	}

	public double opacity {
		get { return settings.get_double("opacity"); }
		set { settings.set_double("opacity", value); }
	}

	public string color_scheme_name {
		owned get { return settings.get_string("color-scheme"); }
		set { settings.set_string("color-scheme", value); }
	}

	public ColorScheme color_scheme {
		owned get { return FinalTerm.color_schemes.get(color_scheme_name); }
	}

	// Convenience properties for common cases
	public Clutter.Color foreground_color {
		get { return color_scheme.get_foreground_color(dark); }
	}

	public Clutter.Color background_color {
		get { return color_scheme.get_background_color(dark); }
	}

	public string theme_name {
		owned get { return settings.get_string("theme"); }
		set { settings.set_string("theme", value); }
	}

	public Theme theme {
		owned get { return FinalTerm.themes.get(theme_name); }
	}

	public string terminal_font_name {
		owned get { return settings.get_string("terminal-font"); }
		set { settings.set_string("terminal-font", value); }
	}

	public Pango.FontDescription terminal_font {
		owned get { return Pango.FontDescription.from_string(terminal_font_name); }
	}

	// TODO: Both character_width and character_height should be cached
	public int character_width {
		get {
			// In a monospaced font, "X" should have the same dimensions
			// as all other characters
			int character_width;
			int character_height;
			Utilities.get_text_size(terminal_font, "X", out character_width, out character_height);
			return character_width;
		}
	}

	public int character_height {
		get {
			int character_width;
			int character_height;
			Utilities.get_text_size(terminal_font, "X", out character_width, out character_height);
			return character_height;
		}
	}

	public string label_font_name {
		owned get { return settings.get_string("label-font"); }
		set { settings.set_string("label-font", value); }
	}

	public Pango.FontDescription label_font {
		owned get { return Pango.FontDescription.from_string(label_font_name); }
	}

	public int terminal_lines {
		get { return settings.get_int("terminal-lines"); }
		set { settings.set_int("terminal-lines", value); }
	}

	public int terminal_columns {
		get { return settings.get_int("terminal-columns"); }
		set { settings.set_int("terminal-columns", value); }
	}

	public string shell_path {
		owned get { return settings.get_string("shell-path"); }
		set { settings.set_string("shell-path", value); }
	}

	public string emulated_terminal {
		owned get { return settings.get_string("emulated-terminal"); }
		set { settings.set_string("emulated-terminal", value); }
	}

	public int render_interval {
		get { return settings.get_int("render-interval"); }
		set { settings.set_int("render-interval", value); }
	}

	public int resize_interval {
		get { return settings.get_int("resize-interval"); }
		set { settings.set_int("resize-interval", value); }
	}

	public static void load_from_schema(string schema_name) {
		if (instance == null)
			instance = new Settings();

		instance.settings = new GLib.Settings(schema_name);

		instance.settings.changed.connect((key) => {
			instance.changed(key);
		});
	}

	public static Settings get_default() {
		if (instance == null)
			error(_("No Settings instance available yet"));

		return instance;
	}

	public signal void changed(string? key);

}
