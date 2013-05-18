/*
 * Copyright © 2013 Tom Beckmann <tomjonabc@gmail.com>
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

public class SettingsWindow : Gtk.Dialog {

	public class SettingsWindow(FinalTerm app) {
		title = "Settings";
		transient_for = app.main_window;
		modal = true;
		add_buttons(Gtk.Stock.CLOSE, Gtk.ResponseType.CANCEL);

		var dimensions = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
		var rows = new Gtk.SpinButton.with_range(10, 200, 1);
		var cols = new Gtk.SpinButton.with_range(10, 300, 1);
		rows.value = FinalTerm.settings.terminal_lines;
		rows.value_changed.connect(() => {
			FinalTerm.settings.settings.set_int("terminal-lines", (int)rows.value);
		});
		cols.value = FinalTerm.settings.terminal_columns;
		cols.value_changed.connect(() => {
			FinalTerm.settings.settings.set_int("terminal-columns", (int)cols.value);
		});
		dimensions.pack_start(cols, false);
		dimensions.pack_start(new Gtk.Label("x"), false);
		dimensions.pack_start(rows, false);

		var dark_look = new Gtk.Switch();
		dark_look.active = FinalTerm.settings.dark;
		dark_look.halign = Gtk.Align.START;
		dark_look.notify["active"].connect(() => {
			app.set_color_scheme_all(app.color_scheme, dark_look.active);
			FinalTerm.settings.settings.set_boolean("dark", dark_look.active);
		});

		var color_scheme = new Gtk.ComboBoxText();
		foreach (var color_scheme_name in FinalTerm.color_schemes.keys) {
			color_scheme.append(color_scheme_name, color_scheme_name);
		}
		color_scheme.active_id = FinalTerm.settings.color_scheme_name;
		color_scheme.changed.connect(() => {
			app.set_color_scheme_all(FinalTerm.color_schemes.get(color_scheme.active_id), app.dark);
			FinalTerm.settings.settings.set_string("color-scheme", color_scheme.active_id);
		});

		var theme = new Gtk.ComboBoxText();
		foreach (var theme_name in FinalTerm.themes.keys) {
			theme.append(theme_name, theme_name);
		}
		theme.active_id = FinalTerm.settings.theme_name;
		theme.changed.connect(() => {
			app.set_theme_all(FinalTerm.themes.get(theme.active_id));
			FinalTerm.settings.settings.set_string("theme", theme.active_id);
		});

		var opacity = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1);
		opacity.set_value(FinalTerm.settings.opacity * 100.0);
		opacity.value_changed.connect(() => {
			var val = opacity.get_value() / 100.0;
			FinalTerm.settings.settings.set_double("opacity", val);
			app.set_background(app.color_scheme.get_background_color(app.dark), val);
		});

		var grid = new Gtk.Grid();
		grid.column_homogeneous = true;
		grid.column_spacing = 12;
		grid.row_spacing = 6;
		grid.margin = 12;

		grid.attach(create_caption("General:"), 0, 0, 1, 1);

		grid.attach(create_label("Default dimensions:"), 0, 1, 1, 1);
		grid.attach(dimensions, 1, 1, 1, 1);

		grid.attach(create_caption("Appearance:"), 0, 2, 1, 1);

		grid.attach(create_label("Dark look:"), 0, 3, 1, 1);
		grid.attach(dark_look, 1, 3, 1, 1);

		grid.attach(create_label("Color scheme:"), 0, 4, 1, 1);
		grid.attach(color_scheme, 1, 4, 1, 1);

		grid.attach(create_label("Theme:"), 0, 5, 1, 1);
		grid.attach(theme, 1, 5, 1, 1);

		grid.attach(create_label("Opacity:"), 0, 6, 1, 1);
		grid.attach(opacity, 1, 6, 1, 1);

		get_content_area().add(grid);
	}

	Gtk.Label create_caption(string title) {
		var label = new Gtk.Label("<span weight='bold'>" + title + "</span>");
		label.use_markup = true;
		label.halign = Gtk.Align.START;
		return label;
	}

	Gtk.Label create_label(string text) {
		var label = new Gtk.Label(text);
		label.halign = Gtk.Align.END;
		return label;
	}
}

