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

public class TerminalWidget : GtkClutter.Embed {

	private Clutter.Stage stage;

	private Terminal terminal;
	private TerminalView terminal_view;

	public TerminalWidget() {
		stage = (Clutter.Stage)get_stage();
		stage.use_alpha = true;

		terminal = new Terminal();
		terminal.title_updated.connect((new_title) => {
			title_updated(new_title);
		});
		terminal.shell_terminated.connect(() => {
			closed();
		});

		terminal_view = new TerminalView(terminal, this);
		terminal.terminal_view = terminal_view;

		stage.add(terminal_view);

		configure_event.connect(on_configure_event);

		on_settings_changed(null);
		Settings.get_default().changed.connect(on_settings_changed);
	}

	public void clear_shell_command() {
		terminal.clear_command();
	}

	public void set_shell_command(string command) {
		terminal.set_command(command);
	}

	public void run_shell_command(string command) {
		terminal.run_command(command);
	}

	public void send_text_to_shell(string text) {
		terminal.send_text(text);
	}

	public int get_terminal_lines() {
		return terminal.lines;
	}

	public int get_terminal_columns() {
		return terminal.columns;
	}

	public int get_horizontal_padding() {
		return terminal_view.terminal_output_view.get_horizontal_padding();
	}

	public int get_vertical_padding() {
		return terminal_view.terminal_output_view.get_vertical_padding();
	}

	private bool on_configure_event(Gdk.EventConfigure event) {
		// TODO: Use "expand" properties to achieve this?
		terminal_view.width  = event.width;
		terminal_view.height = event.height;

		// Reposition autocompletion popup when window is moved or resized
		// to make it "stick" to the prompt line
		if (FinalTerm.autocompletion.is_popup_visible()) {
			terminal.update_autocompletion_position();
		}

		return false;
	}

	private void on_settings_changed(string? key) {
		var background_color = Settings.get_default().background_color;
		background_color.alpha = (uint8)(Settings.get_default().opacity * 255.0);
		stage.background_color = background_color;
	}

	// TODO: Rename to "title_changed"?
	public signal void title_updated(string new_title);

	public signal void closed();

}
