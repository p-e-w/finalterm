/*
 * Copyright © 2013 Tom Beckmann <tomjonabc@gmail.com>
 *             2013 Dominique Lasserre <lasserre.d@gmail.com>
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

[GtkTemplate (ui = "/org/gnome/finalterm/ui/SettingsWindow.ui")]
public class SettingsWindow : Gtk.Dialog {

	[GtkChild (name = "rows")]
	private Gtk.SpinButton rows;

	[GtkChild (name = "columns")]
	private Gtk.SpinButton columns;

	[GtkChild (name = "terminal_font")]
	private Gtk.FontButton terminal_font;

	[GtkChild (name = "label_font")]
	private Gtk.FontButton label_font;

	[GtkChild (name = "dark_look")]
	private Gtk.Switch dark_look;

	[GtkChild (name = "color_scheme")]
	private Gtk.ComboBoxText color_scheme;

	[GtkChild (name = "theme")]
	private Gtk.ComboBoxText theme;

	[GtkChild (name = "opacity")]
	private Gtk.Scale opacityval;

	public SettingsWindow() {
		rows.value = Settings.get_default().terminal_lines;
		rows.value_changed.connect(() => {
			Settings.get_default().terminal_lines = (int)rows.value;
		});

		columns.value = Settings.get_default().terminal_columns;
		columns.value_changed.connect(() => {
			Settings.get_default().terminal_columns = (int)columns.value;
		});

		terminal_font.set_filter_func((family, face) => {
			return family.is_monospace();
		});
		terminal_font.font_name = Settings.get_default().terminal_font_name;
		terminal_font.font_set.connect(() => {
			Settings.get_default().terminal_font_name = terminal_font.font_name;
		});

		label_font.font_name = Settings.get_default().label_font_name;
		label_font.font_set.connect(() => {
			Settings.get_default().label_font_name = label_font.font_name;
		});

		dark_look.active = Settings.get_default().dark;
		dark_look.notify["active"].connect(() => {
			Settings.get_default().dark = dark_look.active;
		});

		foreach (var color_scheme_name in FinalTerm.color_schemes.keys) {
			color_scheme.append(color_scheme_name, color_scheme_name);
		}
		color_scheme.active_id = Settings.get_default().color_scheme_name;
		color_scheme.changed.connect(() => {
			Settings.get_default().color_scheme_name = color_scheme.active_id;
		});

		foreach (var theme_name in FinalTerm.themes.keys) {
			theme.append(theme_name, theme_name);
		}
		theme.active_id = Settings.get_default().theme_name;
		theme.changed.connect(() => {
			Settings.get_default().theme_name = theme.active_id;
		});

		opacityval.set_value(Settings.get_default().opacity * 100.0);
		opacityval.value_changed.connect(() => {
			Settings.get_default().opacity = opacityval.get_value() / 100.0;
		});
	}
}
