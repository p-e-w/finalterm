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

	private bool _dark;
	public bool dark {
		get { return _dark; }
		set { settings.set_boolean("dark", value); }
	}

	private double _opacity;
	public double opacity {
		get { return _opacity; }
		set { settings.set_double("opacity", value); }
	}

	private string _color_scheme_name;
	public string color_scheme_name {
		get { return _color_scheme_name; }
		set { settings.set_string("color-scheme", value); }
	}

	private ColorScheme _color_scheme;
	public ColorScheme color_scheme {
		get { return _color_scheme; }
	}

	private Clutter.Color _foreground_color;
	public Clutter.Color foreground_color {
		get { return _foreground_color; }
	}

	private Clutter.Color _background_color;
	public Clutter.Color background_color {
		get { return _background_color; }
	}

	private string _theme_name;
	public string theme_name {
		get { return _theme_name; }
		set { settings.set_string("theme", value); }
	}

	private Theme _theme;
	public Theme theme {
		get { return _theme; }
	}

	private string _terminal_font_name;
	public string terminal_font_name {
		get { return _terminal_font_name; }
		set { settings.set_string("terminal-font", value); }
	}

	private Pango.FontDescription _terminal_font;
	public Pango.FontDescription terminal_font {
		get { return _terminal_font; }
	}

	private int _character_width;
	public int character_width {
		get { return _character_width; }
	}

	private int _character_height;
	public int character_height {
		get { return _character_height; }
	}

	private string _label_font_name;
	public string label_font_name {
		get { return _label_font_name; }
		set { settings.set_string("label-font", value); }
	}

	private Pango.FontDescription _label_font;
	public Pango.FontDescription label_font {
		get { return _label_font; }
	}

	private int _terminal_lines;
	public int terminal_lines {
		get { return _terminal_lines; }
		set { settings.set_int("terminal-lines", value); }
	}

	private int _terminal_columns;
	public int terminal_columns {
		get { return _terminal_columns; }
		set { settings.set_int("terminal-columns", value); }
	}

	private string _shell_path;
	public string shell_path {
		get { return _shell_path; }
		set { settings.set_string("shell-path", value); }
	}

	private string[] _shell_arguments;
	public string[] shell_arguments {
		get { return _shell_arguments; }
		set { settings.set_strv("shell-arguments", value); }
	}

	private string _emulated_terminal;
	public string emulated_terminal {
		get { return _emulated_terminal; }
		set { settings.set_string("emulated-terminal", value); }
	}

	private int _render_interval;
	public int render_interval {
		get { return _render_interval; }
		set { settings.set_int("render-interval", value); }
	}

	private bool _case_sensitive_autocompletion;
	public bool case_sensitive_autocompletion {
		get { return _case_sensitive_autocompletion; }
		set { settings.set_boolean("case-sensitive-autocompletion", value); }
	}

	private void update_cache() {
		_dark = settings.get_boolean("dark");

		_opacity = settings.get_double("opacity");

		_color_scheme_name = settings.get_string("color-scheme");
		_color_scheme = FinalTerm.color_schemes.get(color_scheme_name);
		_foreground_color = color_scheme.get_foreground_color(dark);
		_background_color = color_scheme.get_background_color(dark);

		_theme_name = settings.get_string("theme");
		_theme = FinalTerm.themes.get(theme_name);

		_terminal_font_name = settings.get_string("terminal-font");
		_terminal_font = Pango.FontDescription.from_string(terminal_font_name);
		// In a monospaced font, "X" should have the same dimensions
		// as all other characters
		Utilities.get_text_size(terminal_font, "X", out _character_width, out _character_height);

		_label_font_name = settings.get_string("label-font");
		_label_font = Pango.FontDescription.from_string(label_font_name);

		_terminal_lines = settings.get_int("terminal-lines");
		_terminal_columns = settings.get_int("terminal-columns");

		_shell_path = settings.get_string("shell-path");
		_shell_arguments = settings.get_strv("shell-arguments");

		_emulated_terminal = settings.get_string("emulated-terminal");

		_render_interval = settings.get_int("render-interval");

		_case_sensitive_autocompletion = settings.get_boolean("case-sensitive-autocompletion");
	}

	public static void load_from_schema(string schema_name) {
		if (instance == null)
			instance = new Settings();

		instance.settings = new GLib.Settings(schema_name);

		instance.update_cache();

		instance.settings.changed.connect((key) => {
			instance.update_cache();
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
