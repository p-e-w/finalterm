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

public class TerminalWidget : GtkClutter.Embed, NestingContainerChild {

	public bool is_active { get; set; }

	public string title { get; set; }

	private Clutter.Stage stage;

	private Terminal terminal;
	private TerminalView terminal_view;

	// This has to be a field rather than a local variable
	// because it gets destroyed immediately otherwise
	private Gtk.Menu context_menu;

	public TerminalWidget() {
		stage = (Clutter.Stage)get_stage();
		stage.use_alpha = true;

		terminal = new Terminal();

		title = terminal.terminal_output.terminal_title;
		terminal.terminal_output.notify["terminal-title"].connect(() => {
			title = terminal.terminal_output.terminal_title;
		});

		close.connect(() => {
			FinalTerm.close_in_pogress = true;
			terminal.terminate_shell();
			FinalTerm.close_in_pogress = false;
		});

		terminal_view = new TerminalView(terminal, this);
		terminal.terminal_view = terminal_view;

		stage.add(terminal_view);

		var inactive_effect = new Clutter.BrightnessContrastEffect();
		inactive_effect.set_brightness(-0.2f);
		inactive_effect.set_contrast(-0.4f);

		notify["is-active"].connect(() => {
			terminal_view.clear_effects();
			if (!is_active)
				terminal_view.add_effect(inactive_effect);

			terminal_view.terminal_output_view.is_active = is_active;
		});

		configure_event.connect(on_configure_event);
		button_press_event.connect(on_button_press_event);

		on_settings_changed(null);
		Settings.get_default().changed.connect(on_settings_changed);
	}

	protected override void get_preferred_width(out int minimum_width, out int natural_width) {
		natural_width = terminal_view.terminal_output_view.get_horizontal_padding() +
				(terminal.columns * Settings.get_default().character_width);
	}

	protected override void get_preferred_height(out int minimum_height, out int natural_height) {
		natural_height = terminal_view.terminal_output_view.get_vertical_padding() +
				(terminal.lines * Settings.get_default().character_height);
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

	public TerminalOutput.TerminalMode get_terminal_modes() {
		return terminal.terminal_output.terminal_modes;
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

	private bool on_button_press_event(Gdk.EventButton event) {
		if (event.type == Gdk.EventType.BUTTON_PRESS && event.button == 1) {
			// Left mouse button pressed
			is_active = true;
			return true;
		} else if (event.type == Gdk.EventType.BUTTON_PRESS && event.button == 3) {
			// Right mouse button pressed
			get_context_menu().popup(null, null, null, event.button, event.time);
			return true;
		}

		return false;
	}

	private Gtk.Menu get_context_menu() {
		context_menu = new Gtk.Menu();

		Gtk.MenuItem menu_item;

		menu_item = new Gtk.MenuItem.with_label(_("New Tab"));
		menu_item.activate.connect(() => {
			add_tab();
		});
		context_menu.append(menu_item);

		context_menu.append(new Gtk.SeparatorMenuItem());

		menu_item = new Gtk.MenuItem.with_label(_("Split Horizontally"));
		menu_item.activate.connect(() => {
			split(Gtk.Orientation.HORIZONTAL);
		});
		context_menu.append(menu_item);

		menu_item = new Gtk.MenuItem.with_label(_("Split Vertically"));
		menu_item.activate.connect(() => {
			split(Gtk.Orientation.VERTICAL);
		});
		context_menu.append(menu_item);

		context_menu.append(new Gtk.SeparatorMenuItem());

		menu_item = new Gtk.MenuItem.with_label(_("Close"));
		menu_item.activate.connect(() => {
			close();
		});
		context_menu.append(menu_item);

		context_menu.show_all();

		return context_menu;
	}

	private void on_settings_changed(string? key) {
		var background_color = Settings.get_default().background_color;
		background_color.alpha = (uint8)(Settings.get_default().opacity * 255.0);
		stage.background_color = background_color;
	}

}
