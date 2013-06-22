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

public class FinalTerm : Gtk.Application {

	private static FinalTerm application;

	public static Gee.Map<int, TextMenu> text_menus_by_code { get; set; }
	public static Gee.Map<Regex, TextMenu> text_menus_by_pattern { get; set; }

	public static Gee.Map<string, ColorScheme> color_schemes;
	public static Gee.Map<string, Theme> themes;

	public static Autocompletion autocompletion { get; set; }

	private Gtk.Window main_window;

	private Clutter.Stage stage;
	private GtkClutter.Embed clutter_embed;

	private Terminal terminal;
	private TerminalView terminal_view;

#if HAS_UNITY
	public static Unity.LauncherEntry launcher;
#endif

	private const ActionEntry[] action_entries = {
		{ "settings", settings_action },
		{ "about", about_action },
		{ "quit", quit_action }
	};

	protected override void startup() {
		base.startup();

		app_menu = create_application_menu();

#if HAS_UNITY
		launcher = Unity.LauncherEntry.get_for_desktop_id("finalterm.desktop");
#endif

		terminal = new Terminal();
		terminal.title_updated.connect(on_terminal_title_updated);
		terminal.shell_terminated.connect(on_terminal_shell_terminated);

		main_window = new Gtk.ApplicationWindow(this);
		main_window.title = "Final Term";
		main_window.resizable = true;
		main_window.has_resize_grip = true;

		clutter_embed = new GtkClutter.Embed();
		// TODO: Send configure event once to ensure correct wrapping + rendering?
		clutter_embed.configure_event.connect(on_configure_event);
		clutter_embed.show();
		main_window.add(clutter_embed);

		stage = (Clutter.Stage)clutter_embed.get_stage();

		terminal_view = new TerminalView(terminal, clutter_embed);
		terminal.terminal_view = terminal_view;
		stage.add(terminal_view);

		// Enable background transparency
		main_window.set_visual(main_window.screen.get_rgba_visual());
		stage.use_alpha = true;

		main_window.key_press_event.connect(on_key_press_event);
	}

	protected override void activate() {
		main_window.present();

		// NOTE: Changing geometry before the window is presented
		//       results in a segmentation fault
		on_settings_changed(null);
		Settings.get_default().changed.connect(on_settings_changed);
	}

	private Menu create_application_menu() {
		add_action_entries(action_entries, this);

		var menu = new Menu();
		Menu menu_section;

		menu_section = new Menu();
		menu_section.append(_("_Preferences"), "app.settings");
		menu.append_section(null, menu_section);

		menu_section = new Menu();
		menu_section.append(_("_About Final Term"), "app.about");
		menu_section.append(_("_Quit"), "app.quit");
		menu.append_section(null, menu_section);

		return menu;
	}

	private void settings_action() {
		var settings_window = new SettingsWindow();
		settings_window.transient_for = main_window;
		settings_window.show_all();
		settings_window.run();
		settings_window.destroy();
	}

	private void about_action() {
		string[] authors = {
				"Philipp Emanuel Weidmann <pew@worldwidemann.com>" + _(" (original author)"),
				"Tom Beckmann <tomjonabc@gmail.com>",
				"Dominique Lasserre <lasserre.d@gmail.com>",
				null };
		string[] artists = { "Matthieu James" + _(" (Faenza icon, modified)"), null };

		Gtk.show_about_dialog(main_window,
				"program-name", "Final Term",
				"logo-icon-name", "final-term",
				"version", _("pre-alpha"),
				"comments", _("At last – a modern terminal emulator."),
				"copyright", _("Copyright © 2013 Philipp Emanuel Weidmann & contributors"),
				"license-type", Gtk.License.GPL_3_0,
				"authors", authors,
				"artists", artists,
				"translator-credits",
					"Philipp Emanuel Weidmann <pew@worldwidemann.com>" + _(" (German)") + "\n" +
					"Ferenc Erki <erkiferenc@gmail.com>" + _(" (Hungarian)"),
				"website", "http://finalterm.org",
				"website-label", "http://finalterm.org");
	}

	private void quit_action() {
		quit();
	}

	private void on_terminal_title_updated(string new_title) {
		main_window.title = new_title;
	}

	private void on_terminal_shell_terminated() {
		quit();
	}

	// Called when size or position of window changes
	private bool on_configure_event(Gdk.EventConfigure event) {
		// TODO: Use "expand" properties to achieve this?
		terminal_view.width  = event.width;
		terminal_view.height = event.height;

		// Reposition autocompletion popup when window is moved or resized
		// to make it "stick" to the prompt line
		if (terminal.is_autocompletion_active()) {
			terminal.update_autocompletion_position();
		}

		return false;
	}

	private bool on_key_press_event(Gdk.EventKey event) {
		//message(_("Application key: %s (%s)"), Gdk.keyval_name(event.keyval), event.str);

		// Handle non-configurable keys (for command completion)
		if (terminal.is_autocompletion_active()) {
			if (event.keyval == Gdk.Key.Up &&
				autocompletion.is_command_selected()) {
				// The "Up" key only triggers command selection
				// if a command has already been selected;
				// this allows shell history to work as expected
				autocompletion.select_previous_command();
				return true;

			} else if (event.keyval == Gdk.Key.Down) {
				autocompletion.select_next_command();
				return true;

			} else if (event.keyval == Gdk.Key.Return &&
					   autocompletion.is_command_selected()) {
				terminal.run_command(autocompletion.get_selected_command());
				return true;

			} else if (event.keyval == Gdk.Key.Escape) {
				autocompletion.hide_popup();
				return true;
			}
		}

		// Handle user-configured keys
		var key_commands = KeyBindings.get_key_commands(event.state, event.keyval);
		if (key_commands != null) {
			foreach (var command in key_commands) {
				command.execute();
			}
			return true;
		}

		if (event.length == 0)
			return false;

		terminal.send_text(event.str);
		return true;
	}

	private void execute_command(Command command) {
		switch (command.command) {
		case Command.CommandType.SEND_TO_SHELL:
			foreach (var parameter in command.parameters) {
				terminal.send_text(parameter);
			}
			return;

		case Command.CommandType.CLEAR_SHELL_COMMAND:
			terminal.clear_command();
			return;

		case Command.CommandType.SET_SHELL_COMMAND:
			if (command.parameters.is_empty)
				return;
			terminal.set_command(command.parameters.get(0));
			return;

		case Command.CommandType.RUN_SHELL_COMMAND:
			if (command.parameters.is_empty)
				return;
			terminal.run_command(command.parameters.get(0));
			return;

		case Command.CommandType.TOGGLE_VISIBLE:
			// TODO: Bring window to foreground if visible but not active
			//       This is made difficult by the fact that global
			//       key bindings prevent is_active from working
			//       correctly
			if (main_window.get_window().is_visible()) {
				main_window.hide();
			} else {
				main_window.show();
			}
			return;

		case Command.CommandType.TOGGLE_FULLSCREEN:
			if ((main_window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) != 0) {
				main_window.unfullscreen();
			} else {
				main_window.fullscreen();
			}
			return;

		case Command.CommandType.TOGGLE_DROPDOWN:
			if (main_window.decorated) {
				// Hide window to avoid any noisy window manager
				// transitions when resizing and also to allow
				// resizing to exact screen width regardless of
				// geometry constraints
				// TODO: Geometry constraints are lost when toggling dropdown
				//       on and off and then showing window
				main_window.hide();
				main_window.decorated = false;
				main_window.move(0, 0);
				// TODO: Make height a user setting
				main_window.resize(main_window.screen.get_width(),
						15 * Settings.get_default().character_height);
				// TODO: Always on top(?)
				main_window.show();
			} else {
				main_window.hide();
				main_window.decorated = true;
			}
			return;

		case Command.CommandType.PRINT_METRICS:
			Metrics.print_block_statistics();
			return;

		case Command.CommandType.COPY_TO_CLIPBOARD:
			if (command.parameters.is_empty)
				return;
			Utilities.set_clipboard_text(main_window, command.parameters.get(0));
			return;

		case Command.CommandType.OPEN_URL:
			if (command.parameters.is_empty)
				return;
			var url = command.parameters.get(0);
			try {
				AppInfo.launch_default_for_uri((url.index_of("www.") == 0) ? "http://" + url : url, null);
			} catch (Error e) { warning(_("Launching %s failed: %s"), url, e.message); }
			return;

		default:
			warning(_("Unsupported command: %s"), command.command.to_string());
			return;
		}
	}

	public static int main(string[] args) {
		Intl.textdomain(Config.GETTEXT_PACKAGE);
		Intl.bindtextdomain(Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);

		if (GtkClutter.init(ref args) != Clutter.InitError.SUCCESS) {
			error(_("Failed to initialize Clutter"));
		}

		Keybinder.init();

		Utilities.initialize();
		Metrics.initialize();
		KeyBindings.initialize();
		Command.initialize();
#if HAS_NOTIFY
		Notify.init("Final Term");
#endif

		Environment.set_application_name("Final Term");

		Gtk.Window.set_default_icon_name("final-term");

		text_menus_by_code    = new Gee.HashMap<int, TextMenu>();
		text_menus_by_pattern = new Gee.HashMap<Regex, TextMenu>();
		foreach (var filename in Utilities.get_files_in_directory(Config.PKGDATADIR + "/TextMenus", ".ftmenu")) {
			var text_menu = new TextMenu.load_from_file(filename);
			switch (text_menu.marker_type) {
			case TextMenu.MarkerType.CODE:
				text_menus_by_code.set(text_menu.code, text_menu);
				break;
			case TextMenu.MarkerType.PATTERN:
				text_menus_by_pattern.set(text_menu.pattern, text_menu);
				break;
			}
		}

		color_schemes = new Gee.HashMap<string, ColorScheme>();
		foreach (var filename in Utilities.get_files_in_directory(Config.PKGDATADIR + "/ColorSchemes", ".ftcolors")) {
			var color_scheme = new ColorScheme.load_from_file(filename);
			color_schemes.set(color_scheme.name, color_scheme);
		}

		themes = new Gee.HashMap<string, Theme>();
		foreach (var filename in Utilities.get_files_in_directory(Config.PKGDATADIR + "/Themes", ".fttheme", true)) {
			var theme = new Theme.load_from_file(filename);
			themes.set(theme.name, theme);
		}

		foreach (var filename in Utilities.get_files_in_directory(Config.PKGDATADIR + "/KeyBindings", ".ftkeys")) {
			KeyBindings.load_from_file(filename);
		}

		var data_dir = File.new_for_path(Environment.get_user_data_dir() + "/finalterm");
		if (!data_dir.query_exists()) {
			try {
				data_dir.make_directory();
			} catch (Error e) { error(_("Cannot access data directory: %s"), e.message); }
		}

		application = new FinalTerm();

		Settings.load_from_schema("org.gnome.finalterm");

		Command.execute_function = application.execute_command;

		string autocompletion_filename = data_dir.get_path() + "/commands.ftcompletion";

		autocompletion = new Autocompletion();

		if (File.new_for_path(autocompletion_filename).query_exists())
			autocompletion.load_entries_from_file(autocompletion_filename);

		var result = application.run(args);

		autocompletion.save_entries_to_file(autocompletion_filename);

		return result;
	}

	private void set_background(Clutter.Color color, double opacity) {
		color.alpha = (uint8)(opacity * 255.0);
		stage.background_color = color;
	}

	private void on_settings_changed(string? key) {
		set_background(Settings.get_default().background_color, Settings.get_default().opacity);
		Gtk.Settings.get_default().gtk_application_prefer_dark_theme = Settings.get_default().dark;

		// Restrict window resizing to multiples of character size
		// TODO: Make this optional (user setting)
		var geometry = Gdk.Geometry();
		// TODO: Account for appearing / disappearing scrollbars
		geometry.base_width  = terminal_view.terminal_output_view.get_horizontal_padding();
		geometry.base_height = terminal_view.terminal_output_view.get_vertical_padding();
		geometry.width_inc   = Settings.get_default().character_width;
		geometry.height_inc  = Settings.get_default().character_height;
		// TODO: Move values into constants / settings
		geometry.min_width   = geometry.base_width + (20 * geometry.width_inc);
		geometry.min_height  = geometry.base_height + (5 * geometry.height_inc);
		main_window.get_window().set_geometry_hints(geometry,
				Gdk.WindowHints.BASE_SIZE | Gdk.WindowHints.RESIZE_INC | Gdk.WindowHints.MIN_SIZE);

		// TODO: This should be resize_to_geometry, but that doesn't work
		main_window.resize(
			terminal_view.terminal_output_view.get_horizontal_padding() +
				(terminal.columns * Settings.get_default().character_width),
			terminal_view.terminal_output_view.get_vertical_padding() +
				(terminal.lines * Settings.get_default().character_height));
	}

}
