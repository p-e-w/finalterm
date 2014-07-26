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

public class FinalTerm : Gtk.Application {

	private static FinalTerm application;

	public static Gee.Map<int, TextMenu> text_menus_by_code { get; set; }
	public static Gee.Map<Regex, TextMenu> text_menus_by_pattern { get; set; }

	public static Gee.Map<string, ColorScheme> color_schemes;
	public static Gee.Map<string, Theme> themes;

	public static Autocompletion autocompletion { get; set; }

	private Gtk.Window main_window;
	private Gtk.IMContext im_context;
	private bool preedit_active = false;

	private TerminalWidget active_terminal_widget = null;

#if HAS_UNITY
	public static Unity.LauncherEntry launcher;
#endif

	private static bool show_version = false;

	private const OptionEntry[] options = {
		{ "version", 'v', 0, OptionArg.NONE, ref show_version, N_("Display version number"), null },
		{ null }
	};

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

		main_window = new Gtk.ApplicationWindow(this);
		main_window.resizable = true;
		main_window.has_resize_grip = true;
		// Enable background transparency
		main_window.app_paintable = true;
		main_window.set_visual(main_window.screen.get_rgba_visual());

		var nesting_container = new NestingContainer(() => {
			var terminal_widget = new TerminalWidget();

			if (active_terminal_widget == null) {
				terminal_widget.is_active = true;
				active_terminal_widget = terminal_widget;
			} else {
				terminal_widget.is_active = false;
			}

			terminal_widget.notify["is-active"].connect(() => {
				if (terminal_widget.is_active)
					active_terminal_widget = terminal_widget;
			});

			return terminal_widget;
		});

		main_window.title = nesting_container.title;
		nesting_container.notify["title"].connect(() => {
			main_window.title = nesting_container.title;
		});

		nesting_container.close.connect(() => {
			quit();
		});

		main_window.add(nesting_container);

		im_context = new Gtk.IMMulticontext();
		im_context.commit.connect(on_commit);
		im_context.preedit_start.connect(on_preedit_start);
		im_context.preedit_end.connect(on_preedit_end);
		main_window.key_press_event.connect(on_key_press_event);
		main_window.key_release_event.connect(on_key_release_event);
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
				"Ferenc Erki <erkiferenc@gmail.com>",
				"Luke Carrier <luke@carrier.im>",
				"Abderrahim Kitouni <a.kitouni@gmail.com>",
				"Tomasz Święcicki <tomislater@gmail.com>",
				"Steven Oliver <oliver.steven@gmail.com>",
				"Guilhem Lettron <guilhem.lettron@optiflows.com>",
				"Carl George <carl@carlgeorge.us>",
				"Martin Middel <martin.middel@liones.nl>",
				"Mola Pahnadayan <mola.mp@gmail.com>",
				"Adis Hamzić <adis@hamzadis.com>",
				null };
		string[] artists = { "Matthieu James" + _(" (Faenza icon, modified)"), null };

		Gtk.show_about_dialog(main_window,
				"program-name", "Final Term",
				"logo-icon-name", "final-term",
				"version", _("pre-alpha"),
				"comments", _("At last – a modern terminal emulator."),
				"copyright", _("Copyright © 2013–2014 Philipp Emanuel Weidmann & contributors"),
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

	private bool on_key_press_event(Gdk.EventKey event) {
		//message(_("Application key: %s (%s)"), Gdk.keyval_name(event.keyval), event.str);

		// Handle non-configurable keys (for command completion)
		if (autocompletion.is_popup_visible()) {
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

			} else if (event.keyval == Gdk.Key.Right &&
					   autocompletion.is_command_selected()) {
				active_terminal_widget.set_shell_command(autocompletion.get_selected_command());
				return true;

			} else if (event.keyval == Gdk.Key.Return &&
					   autocompletion.is_command_selected()) {
				active_terminal_widget.run_shell_command(autocompletion.get_selected_command());
				return true;

			} else if (event.keyval == Gdk.Key.Escape) {
				autocompletion.hide_popup();
				return true;
			}
		}

		// Handle user-configured keys only outside of preedit
		if (!preedit_active) {
			var key_commands = KeyBindings.get_key_commands(event.keyval, event.state,
					active_terminal_widget.get_terminal_modes());
			if (key_commands != null) {
				foreach (var command in key_commands) {
					command.execute();
				}
				return true;
			}
		}

		if (im_context.filter_keypress(event))
			return true;

		if (event.length == 0)
			return false;

		active_terminal_widget.send_text_to_shell(event.str);
		return true;
	}

	private bool on_key_release_event(Gdk.EventKey event) {
		return im_context.filter_keypress(event);
	}

	private void on_commit(string str) {
		active_terminal_widget.send_text_to_shell(str);
	}

	private void on_preedit_start() {
		preedit_active = true;
	}

	private void on_preedit_end() {
		preedit_active = false;
	}

	private void execute_command(Command command) {
		switch (command.command) {
		case Command.CommandType.QUIT_PROGRAM:
			quit();
			return;

		case Command.CommandType.SEND_TO_SHELL:
			foreach (var parameter in command.parameters) {
				active_terminal_widget.send_text_to_shell(parameter);
			}
			return;

		case Command.CommandType.CLEAR_SHELL_COMMAND:
			active_terminal_widget.clear_shell_command();
			return;

		case Command.CommandType.SET_SHELL_COMMAND:
			if (command.parameters.is_empty)
				return;
			active_terminal_widget.set_shell_command(command.parameters.get(0));
			return;

		case Command.CommandType.RUN_SHELL_COMMAND:
			if (command.parameters.is_empty)
				return;
			active_terminal_widget.run_shell_command(command.parameters.get(0));
			return;

		case Command.CommandType.TOGGLE_VISIBLE:
			// TODO: Bring window to foreground if visible but not active
			//       This is made difficult by the fact that global
			//       key bindings prevent is_active from working
			//       correctly
			if (main_window.get_window().is_visible()) {
				main_window.hide();
			} else {
				main_window.present();
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
				// TODO: Make height a user setting
				// TODO: Account for vertical padding
				Gdk.Rectangle monitor_geometry;
				main_window.screen.get_monitor_geometry(main_window.screen.get_primary_monitor(), out monitor_geometry);
				main_window.move(monitor_geometry.x, monitor_geometry.y);
				main_window.resize(monitor_geometry.width, 15 * Settings.get_default().character_height);
				main_window.present();
				main_window.set_keep_above(true);
			} else {
				main_window.set_keep_above(false);
				main_window.hide();
				main_window.decorated = true;
			}
			return;

		case Command.CommandType.ADD_TAB:
			if (active_terminal_widget != null) {
				for (int i = 0; i < command.get_numeric_parameter(0, 1); i++)
					active_terminal_widget.add_tab();
			}
			return;

		case Command.CommandType.SPLIT:
			if (active_terminal_widget != null) {
				var orientation = command.get_text_parameter(0, "HORIZONTALLY");
				switch (orientation) {
				case "HORIZONTALLY":
					active_terminal_widget.split(Gtk.Orientation.HORIZONTAL);
					break;
				case "VERTICALLY":
					active_terminal_widget.split(Gtk.Orientation.VERTICAL);
					break;
				default:
					warning(_("Unsupported split orientation: %s"), orientation);
					break;
				}
			}
			return;

		case Command.CommandType.CLOSE:
			if (active_terminal_widget != null) {
				active_terminal_widget.close();
			}
			return;

		case Command.CommandType.LOG:
			foreach (var parameter in command.parameters) {
				message(_("Log entry: '%s'"), parameter);
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

		try {
			if (GtkClutter.init_with_args(ref args, null, options, Config.GETTEXT_PACKAGE) != Clutter.InitError.SUCCESS) {
				error(_("Failed to initialize Clutter"));
			}
		} catch (Error e) {
			print("%s\n", e.message);
			print(_("Run '%s --help' to see a list of available command line options\n"), args[0]);
			return 1;
		}

		if (show_version) {
			print("Final Term %s\n", Config.VERSION);
			return 0;
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
				data_dir.make_directory_with_parents();
			} catch (Error e) { error(_("Cannot access data directory %s: %s"), data_dir.get_parse_name(), e.message); }
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

	private void on_settings_changed(string? key) {
		Gtk.Settings.get_default().gtk_application_prefer_dark_theme = Settings.get_default().dark;
	}

}
