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

// TODO: Make this a namespace?
public class Utilities : Object {

	public static void initialize() {
		scheduled_functions = new Gee.HashSet<string>();
	}

	// Returns the absolute path of a file that is given relative to another file
	public static string get_absolute_filename(string filename, string relative_filename) {
		return File.new_for_path(filename).get_parent().get_child(relative_filename).get_path();
	}

	public static Gee.Set<string> get_files_in_directory(string directory_name, string extension = "", bool recursive = false) {
		var files = new Gee.HashSet<string>();

		Dir directory = null;
		try {
			directory = Dir.open(directory_name);
		} catch (Error e) { error(_("Failed to get %s files in %s: %s"), extension, directory_name, e.message); }

		Regex pattern = null;
		try {
			pattern = new Regex(".*" + Regex.escape_string(extension) + "$", RegexCompileFlags.OPTIMIZE);
		} catch (Error e) { error(e.message); }

		string filename;
		while ((filename = directory.read_name()) != null) {
			string path_name = Path.build_filename(directory_name, filename);

			if (pattern.match(filename))
				files.add(path_name);

			if (recursive && FileUtils.test(path_name, FileTest.IS_DIR))
				files.add_all(get_files_in_directory(path_name, extension, recursive));
		}

		return files;
	}

	public static int byte_index_to_character_index(string text, int byte_index) {
		if (!text.valid_char(byte_index))
			error(_("No character found at byte index %i"), byte_index);

		for (int i = 0; i < text.char_count(); i++) {
			if (text.index_of_nth_char(i) == byte_index)
				return i;
		}

		assert_not_reached();
	}

	public static string repeat_string(string text, int count) {
		var text_builder = new StringBuilder();
		for (int i = 0; i < count; i++)
			text_builder.append(text);

		return text_builder.str;
	}

	public static Clutter.Color get_rgb_color(int red, int green, int blue) {
		// TODO: A Vala bug prevents using this (linker error):
		//return Clutter.Color().init((uint8)red, (uint8)green, (uint8)blue, 255);
		
		var color = Clutter.Color();
		color.red   = (uint8)red;
		color.green = (uint8)green;
		color.blue  = (uint8)blue;
		color.alpha = 255;
		return color;
	}

	// Returns a string representation of the specified color
	// that can be parsed by the Pango markup parser
	public static string get_parsable_color_string(Clutter.Color color) {
		// Note that color.to_string() returns a string of the form "#rrggbbaa"
		// while the Pango markup parser expects the form "#rrggbb"
		return color.to_string().substring(0, 7);
	}

	public static void get_text_size(Pango.FontDescription font, string text, out int width, out int height) {
		var dummy_label = new Gtk.Label(null);
		dummy_label.override_font(font);
		var layout = new Pango.Layout(dummy_label.get_pango_context());
		layout.set_text(text, -1);
		layout.get_pixel_size(out width, out height);
	}

	public static T get_enum_value_from_name<T>(Type type, string name) {
		EnumClass enum_class = (EnumClass)type.class_ref();
		unowned EnumValue? enum_value = enum_class.get_value_by_name(name);

		if (enum_value == null) {
			warning(_("Invalid enum value name: '%s'"), name);
			return 0;
		}

		return (T)enum_value.value;
	}

	// TODO: These methods should of course use Json.Builder and Json.Reader;
	//       unfortunately, trying to employ those libraries resulted in multiple
	//       segmentation faults and other problems (Vala code generation issues?)
	public static void save_list_to_file<T>(Gee.List<T> list, string filename) {
		var file_stream = FileStream.open(filename, "w");

		foreach (var item in list) {
			var line = Json.gobject_to_data((Object)item, null);
			line = line.replace("\n", "");
			file_stream.puts(line + "\n");
		}

		file_stream.flush();
	}

	public static Gee.List<T>? load_list_from_file<T>(Type item_type, string filename) {
		var file_stream = FileStream.open(filename, "r");

		if (file_stream == null) {
			warning(_("Error while opening file '%s' for reading"), filename);
			return null;
		}

		var list = new Gee.ArrayList<T>();

		while (!file_stream.eof()) {
			var line = file_stream.read_line();

			if (line == null)
				break;

			try {
				T item = Json.gobject_from_data(item_type, line);
				list.add(item);
			} catch (Error e) { warning(_("Error while parsing JSON file %s: %s"), filename, e.message); }
		}

		return list;
	}

	public static void set_clipboard_text(Gtk.Widget widget, string text) {
		var clipboard = Gtk.Clipboard.get_for_display(widget.get_display(), Gdk.SELECTION_CLIPBOARD);
		clipboard.set_text(text, -1);
	}

	public static void get_actor_screen_position(GtkClutter.Embed clutter_embed, Clutter.Actor actor, out int x, out int y) {
		// Position of parent window on screen
		int window_x;
		int window_y;
		clutter_embed.get_parent_window().get_origin(out window_x, out window_y);

		// Position of Clutter widget within parent window
		// TODO: Is this always relative to the parent window?
		Gtk.Allocation embed_allocation;
		clutter_embed.get_allocation(out embed_allocation);

		// Position of actor within Clutter widget (stage)
		float actor_x;
		float actor_y;
		actor.get_transformed_position(out actor_x, out actor_y);

		x = window_x + embed_allocation.x + (int)actor_x;
		y = window_y + embed_allocation.y + (int)actor_y;
	}

	public delegate void ScheduleFunction();

	private static Gee.Set<string> scheduled_functions;

	// Executes function under the following contract:
	// - function is guaranteed to be executed after at most interval milliseconds
	// - If function is scheduled for execution again before it has been executed
	//   (as identified by function_name), function will only be executed once
	public static void schedule_execution(ScheduleFunction function, string function_name,
				uint interval, int priority = Priority.DEFAULT) {
		if (scheduled_functions.contains(function_name))
			// function already scheduled for execution
			return;

		scheduled_functions.add(function_name);

		Timeout.add(interval, () => {
			scheduled_functions.remove(function_name);
			function();
			return false;
		}, priority);
	}

}
