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

public class FinalTerm : Gtk.Application, ColorSchemable, Themable {

	private static FinalTerm application;

	public static Settings settings { get; set; }

	public static Gee.Map<int, TextMenu> text_menus_by_code { get; set; }
	public static Gee.Map<Regex, TextMenu> text_menus_by_pattern { get; set; }

	private static Gee.Map<string, ColorScheme> color_schemes;
	private static Gee.Map<string, Theme> themes;

	private ColorScheme color_scheme;
	private bool dark;
	private Theme theme;
	private double opacity;

	private Gee.Set<ColorSchemable> color_schemables = new Gee.HashSet<ColorSchemable>();
	private Gee.Set<Themable> themables = new Gee.HashSet<Themable>();

	public static Autocompletion autocompletion { get; set; }

	private Gtk.Window main_window;

	private Clutter.Stage stage;
	private GtkClutter.Embed clutter_embed;

	private Terminal terminal;
	private TerminalView terminal_view;

	private const ActionEntry[] action_entries = {
		// TODO: If the default state for this entry is not set here,
		//       the toggle button does not show up in the application menu
		//       despite the state being set later
		{ "dark-look", toggle_action, null, "false", dark_look_action },
		{ "color-scheme", radio_action, "s", "''", color_scheme_action },
		{ "theme", radio_action, "s", "''", theme_action },
		{ "opacity", radio_action, "s", "''", opacity_action },
		{ "about", about_action },
		{ "quit", quit_action }
	};

	protected override void startup() {
		base.startup();

		app_menu = create_application_menu();

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

		register_color_schemable(this);
		register_themable(this);
	}

	protected override void activate() {
		// TODO: Use set_default_geometry instead?
		main_window.set_default_size(
				terminal_view.terminal_output_view.get_horizontal_padding() +
					(terminal.columns * theme.character_width),
				terminal_view.terminal_output_view.get_vertical_padding() +
					(terminal.lines * theme.character_height));

		main_window.present();

		// Restrict window resizing to multiples of character size
		// NOTE: Changing geometry before the window is presented
		//       results in a segmentation fault
		// TODO: Make this optional (user setting)
		var geometry = Gdk.Geometry();
		// TODO: Account for appearing / disappearing scrollbars
		geometry.base_width  = terminal_view.terminal_output_view.get_horizontal_padding();
		geometry.base_height = terminal_view.terminal_output_view.get_vertical_padding();
		// TODO: Update geometry when theme is changed
		geometry.width_inc   = theme.character_width;
		geometry.height_inc  = theme.character_height;
		// TODO: Move values into constants / settings
		geometry.min_width   = geometry.base_width + (20 * geometry.width_inc);
		geometry.min_height  = geometry.base_height + (5 * geometry.height_inc);
		main_window.get_window().set_geometry_hints(geometry,
				Gdk.WindowHints.BASE_SIZE | Gdk.WindowHints.RESIZE_INC | Gdk.WindowHints.MIN_SIZE);
	}

	private Menu create_application_menu() {
		add_action_entries(action_entries, this);

		// TODO: Apparently, Vala is incapable of compiling variables of type GLib.ActionEntry
		//       correctly (various GCC errors). This prevents a dynamic array of ActionEntries
		//       from being used here and necessitates this hack in order to dynamically set
		//       the entries' states based on Final Term settings.
		((SimpleAction)lookup_action("dark-look")).set_state(settings.dark);
		((SimpleAction)lookup_action("color-scheme")).set_state(settings.color_scheme_name);
		((SimpleAction)lookup_action("theme")).set_state(settings.theme_name);
		string opacity_string = ((int)Math.round(settings.opacity * 100.0)).to_string();
		((SimpleAction)lookup_action("opacity")).set_state(opacity_string);

		var menu = new Menu();
		Menu menu_section;

		menu_section = new Menu();
		menu_section.append("_Dark look", "app.dark-look");

		var color_scheme_menu = new Menu();
		foreach (var color_scheme_name in color_schemes.keys) {
			color_scheme_menu.append(color_scheme_name, "app.color-scheme::" + color_scheme_name);
		}
		menu_section.append_submenu("_Color scheme", color_scheme_menu);

		var theme_menu = new Menu();
		foreach (var theme_name in themes.keys) {
			theme_menu.append(theme_name, "app.theme::" + theme_name);
		}
		menu_section.append_submenu("_Theme", theme_menu);

		// TODO: This should be a slider item instead
		//       (cf. http://git.gnome.org/browse/gnome-shell/tree/js/ui/popupMenu.js:PopupSliderMenuItem),
		//       but that does not appear to be supported in an application menu
		var opacity_menu = new Menu();
		opacity_menu.append("0 % (transparent)", "app.opacity::0");
		for (int i = 10; i <= 90; i += 10) {
			opacity_menu.append(i.to_string() + " %", "app.opacity::" + i.to_string());
		}
		opacity_menu.append("100 % (opaque)", "app.opacity::100");
		menu_section.append_submenu("_Opacity", opacity_menu);

		menu.append_section("Appearance", menu_section);

		menu_section = new Menu();
		menu_section.append("_About Final Term", "app.about");
		menu_section.append("_Quit", "app.quit");
		menu.append_section(null, menu_section);

		return menu;
	}

	private void toggle_action(SimpleAction action, Variant? parameter) {
		var state = action.get_state().get_boolean();
		action.change_state(new Variant.boolean(!state));
	}

	private void radio_action(SimpleAction action, Variant? parameter) {
		action.change_state(parameter);
	}

	private void dark_look_action(SimpleAction action, Variant value) {
		if (value == null)
			return;

		var dark_value = value.get_boolean();
		set_color_scheme_all(color_scheme, dark_value);

		action.set_state(value);
	}

	private void color_scheme_action(SimpleAction action, Variant value) {
		if (value == null)
			return;

		var color_scheme_value = color_schemes.get(value.get_string());
		set_color_scheme_all(color_scheme_value, dark);

		action.set_state(value);
	}

	private void theme_action(SimpleAction action, Variant value) {
		if (value == null)
			return;

		var theme_value = themes.get(value.get_string());
		set_theme_all(theme_value);

		action.set_state(value);
	}

	private void opacity_action(SimpleAction action, Variant value) {
		if (value == null)
			return;

		opacity = double.parse(value.get_string()) / 100.0;
		set_background(color_scheme.get_background_color(dark), opacity);

		action.set_state(value);
	}

	private void about_action() {
		string[] authors = {
			"Philipp Emanuel Weidmann <pew@worldwidemann.com> (original author)",
			"Tom Beckmann <tomjonabc@gmail.com>",
			null };
		string[] artists = { "Matthieu James (Faenza icon, modified)", null };

		Gtk.show_about_dialog(main_window,
				"program-name", "Final Term",
				"logo-icon-name", "final-term",
				"version", "pre-alpha",
				"comments", "At last – a modern terminal emulator.",
				"copyright", "Copyright © 2013 Philipp Emanuel Weidmann & contributors",
				"license-type", Gtk.License.GPL_3_0,
				"authors", authors,
				"artists", artists,
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
		//message("Application key: %s", Gdk.keyval_name(event.keyval));

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

		unichar key_character = Gdk.keyval_to_unicode(event.keyval);

		if (key_character.isprint()) {
			// By default, printable keys are forwarded to the shell
			terminal.send_character(key_character);
			return true;
		} else {
			// By default, non-printable keys are ignored
			return false;
		}
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
				main_window.resize(main_window.screen.get_width(), 15 * theme.character_height);
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
			} catch (Error e) { warning("Launching %s failed: %s", url, e.message); }
			return;

		default:
			warning("Unsupported command: %s", command.command.to_string());
			return;
		}
	}

	public static int main(string[] args) {
		if (GtkClutter.init(ref args) != Clutter.InitError.SUCCESS) {
			critical("Failed to initialize Clutter");
			return Posix.EXIT_FAILURE;
		}

		Keybinder.init();

		Utilities.initialize();
		Metrics.initialize();
		KeyBindings.initialize();
		Command.initialize();

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
			} catch (Error e) {
				critical("Cannot access data directory: %s", e.message);
			}
		}

		application = new FinalTerm();

		FinalTerm.settings = new Settings.load_from_schema("org.gnome.finalterm");

		application.color_scheme = color_schemes.get(FinalTerm.settings.color_scheme_name);
		if (application.color_scheme == null)
			error("Color scheme %s does not exist - exiting.", FinalTerm.settings.color_scheme_name);
		application.dark = FinalTerm.settings.dark;
		application.set_color_scheme_all(application.color_scheme, application.dark);
		application.theme = themes.get(FinalTerm.settings.theme_name);
		if (application.theme == null)
			error("Theme %s does not exist - exiting.", FinalTerm.settings.theme_name);
		application.set_theme_all(application.theme);
		application.opacity = FinalTerm.settings.opacity;

		Command.execute_function = application.execute_command;

		autocompletion = new Autocompletion();
		autocompletion.load_entries_from_file(data_dir.get_path() + "/commands.ftcompletion");

		var result = application.run(args);

		autocompletion.save_entries_to_file(data_dir.get_path() + "/commands.ftcompletion");

		return result;
	}

	private void set_color_scheme_all(ColorScheme color_scheme, bool dark) {
		foreach (var color_schemable in color_schemables) {
			color_schemable.set_color_scheme(color_scheme, dark);
		}
	}

	private void set_theme_all(Theme theme) {
		foreach (var themable in themables) {
			themable.set_theme(theme);
		}
	}

	public void set_color_scheme(ColorScheme color_scheme, bool dark) {
		this.color_scheme = color_scheme;
		this.dark = dark;

		set_background(color_scheme.get_background_color(dark), opacity);
		Gtk.Settings.get_default().gtk_application_prefer_dark_theme = dark;
	}

	public void set_theme(Theme theme) {
		this.theme = theme;
	}

	private void set_background(Clutter.Color color, double opacity) {
		color.alpha = (uint8)(opacity * 255.0);
		stage.background_color = color;
	}

	public static void register_color_schemable(ColorSchemable color_schemable) {
		application.color_schemables.add(color_schemable);
		color_schemable.set_color_scheme(application.color_scheme, application.dark);
	}

	public static void register_themable(Themable themable) {
		application.themables.add(themable);
		themable.set_theme(application.theme);
	}

}
