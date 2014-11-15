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

public class Autocompletion : Object {

	private Gtk.Window popup_window;
	private Clutter.Stage stage;

	private NotifyingList<AutocompletionEntry> entries;

	private ScrollableListView<AutocompletionEntry, AutocompletionEntryView> scrollable_list_view;

	private int selected_index;
	private string current_command = "";

	public Autocompletion() {
		popup_window = new Gtk.Window(Gtk.WindowType.POPUP);

		var clutter_embed = new GtkClutter.Embed();
		clutter_embed.show();
		popup_window.add(clutter_embed);

		stage = (Clutter.Stage)clutter_embed.get_stage();

		entries = new NotifyingList<AutocompletionEntry>();

		scrollable_list_view = new ScrollableListView<AutocompletionEntry, AutocompletionEntryView>(
				entries, typeof(AutocompletionEntry), typeof(AutocompletionEntryView), "entry");
		stage.add(scrollable_list_view);

		scrollable_list_view.set_filter_function(filter_function);
		scrollable_list_view.set_sort_function(sort_function);
		scrollable_list_view.item_hovered.connect(on_item_hovered);
		scrollable_list_view.item_clicked.connect(on_item_clicked);

		on_settings_changed(null);
		Settings.get_default().changed.connect(on_settings_changed);
	}

	public void save_entries_to_file(string filename) {
		Utilities.save_list_to_file<AutocompletionEntry>(entries, filename);
	}

	public void load_entries_from_file(string filename) {
		entries.add_all(Utilities.load_list_from_file<AutocompletionEntry>(
				typeof(AutocompletionEntry),
				filename));
	}

	// Ensures that only entries containing the current command are shown
	private bool filter_function(AutocompletionEntry item) {
		if (Settings.get_default().case_sensitive_autocompletion) {
			return item.text.contains(current_command);
		} else {
			return item.text.casefold().contains(current_command.casefold());
		}
	}

	// Ranks entries so that the most relevant ones are shown first
	private int sort_function(AutocompletionEntry item_1, AutocompletionEntry item_2) {
		int index_1 = item_1.text.index_of(current_command);
		int index_2 = item_2.text.index_of(current_command);

		if (index_1 == -1 || index_2 == -1) {
			// This condition actually occurs on each sort
			// (apparently, the filter function is not taken into consideration when sorting):
			//warning(_("Attempting to sort entries that do not both contain the current command: '%s' and '%s'"),
			//		item_1.text, item_2.text);
			return 0;
		}

		// Prefer an entry that starts with the current command
		// to an entry that does not
		if (index_1 == 0 && index_2 > 0)
			return -1;
		if (index_2 == 0 && index_1 > 0)
			return 1;

		// Prefer the more frequently used entry
		if (item_1.uses != item_2.uses)
			return item_2.uses - item_1.uses;

		// Prefer the more recently used entry
		return item_2.last_used - item_1.last_used;
	}

	public void add_command(string command) {
		foreach (var entry in entries) {
			if (entry.text == command) {
				entry.uses++;
				entry.last_used = (int)Time.local(time_t()).mktime();
				return;
			}
		}

		// Command not found in entry list
		var entry = new AutocompletionEntry();
		entry.text = command;
		entry.uses = 1;
		entry.last_used = (int)Time.local(time_t()).mktime();
		entries.add(entry);
	}

	public bool is_command_selected() {
		return scrollable_list_view.is_valid_item_index(selected_index);
	}

	public string? get_selected_command() {
		if (is_command_selected())
			return scrollable_list_view.get_item(selected_index).text;

		return null;
	}

	public void select_previous_command() {
		if (selected_index > 0)
			select_entry(selected_index - 1);
	}

	public void select_next_command() {
		// Note that this will select the first entry
		// if selected_entry is -1 (as desired)
		if (selected_index < scrollable_list_view.get_number_of_items() - 1)
			select_entry(selected_index + 1);
	}

	private void select_entry(int index) {
		selected_index = index;

		AutocompletionEntryView.selected_index = index;
		for (int i = 0; i < scrollable_list_view.get_number_of_items(); i++) {
			scrollable_list_view.update_item(i);
		}

		scrollable_list_view.scroll_to_item(index);
	}

	public void show_popup(string command) {
		this.current_command = command;

		// Force refilter + resort
		scrollable_list_view.set_filter_function(filter_function);
		scrollable_list_view.set_sort_function(sort_function);

		try {
			AutocompletionEntryView.highlight_pattern = new Regex(Regex.escape_string(command),
					RegexCompileFlags.CASELESS | RegexCompileFlags.OPTIMIZE);
		} catch (Error e) { error(_("Highlight regex compilation error: %s"), e.message); }

		for (int i = 0; i < scrollable_list_view.get_number_of_items(); i++) {
			scrollable_list_view.update_item(i);
		}

		int matches = scrollable_list_view.get_number_of_items();

		if (matches == 0) {
			hide_popup();
			return;
		}

		// Deselect all entries
		select_entry(-1);

		// Determine optimal size for popup window
		int maximum_length = 0;
		for (int i = 0; i < scrollable_list_view.get_number_of_items(); i++) {
			maximum_length = int.max(maximum_length, scrollable_list_view.get_item(i).text.char_count());
		}

		// TODO: Move values into constants / settings
		int width  = 50 + (int.min(40, maximum_length) * Settings.get_default().character_width);
		// TODO: If line breaking is required, the height determined here may be too low
		//       to show even a single match completely
		int height = int.min(8, matches) * Settings.get_default().character_height;
		popup_window.resize(width, height);
		scrollable_list_view.width  = width;
		scrollable_list_view.height = height;

		popup_window.show_all();
	}

	public void move_popup(int x, int y) {
		popup_window.move(x, y);
	}

	public void hide_popup() {
		popup_window.hide();
	}

	public bool is_popup_visible() {
		return popup_window.visible;
	}

	private void on_settings_changed(string? key) {
		stage.set_background_color(Settings.get_default().foreground_color);
	}

	private void on_item_hovered(int index) {
		select_entry(index);
	}

	private void on_item_clicked(int index) {
		run_command(scrollable_list_view.get_item(index).text);
	}

	public signal void run_command(string command);

	private class AutocompletionEntry : Object {

		public string text { get; set; }
		public int uses { get; set; }
		// TODO: This should be a long value (timestamp), but
		//       Json.gobject_from_data fails to load it properly
		public int last_used { get; set; }

	}


	private class AutocompletionEntryView : Mx.Label, ItemView {

		public static int selected_index { get; set; }
		public static Regex highlight_pattern { get; set; }

		public AutocompletionEntry entry { get; set; }

		public AutocompletionEntryView() {
			// DOES NOT GET CALLED (GObject-style construction)
		}

		public void construct() {
			use_markup = true;
			clutter_text.line_wrap = true;
			clutter_text.line_wrap_mode = Pango.WrapMode.WORD_CHAR;

			on_settings_changed(null);
			Settings.get_default().changed.connect(on_settings_changed);
		}

		public void update() {
			if (get_parent() == null)
				return;

			if (entry == null)
				return;

			// TODO: Highlight using CSS classes and Mx stylesheet

			// Highlight entry if selected
			var index = get_parent().get_children().index(this);
			if (index == selected_index) {
				// TODO: Allow setting of highlight color in color scheme
				background_color = Settings.get_default().color_scheme
						.get_indexed_color(3, Settings.get_default().dark);
			} else {
				background_color = Settings.get_default().foreground_color;
			}

			string markup;

			if (highlight_pattern == null) {
				markup = Markup.escape_text(entry.text);
			} else {
				// Highlight text in entry:
				// Step 1: Place markers around text to be highlighted
				try {
					markup = highlight_pattern.replace(entry.text, -1, 0, "{$$$}\\0{/$$$}");
				} catch (Error e) { error(_("Highlight regex error: %s"), e.message); }
				// Step 2: Replace reserved characters with markup entities
				markup = Markup.escape_text(markup);
				// Step 3: Replace markers with highlighting markup tags
				markup = markup.replace("{$$$}", "<b>");
				markup = markup.replace("{/$$$}", "</b>");
			}

			// Color terminal commands differently
			var text_color = (entry.text.substring(0, 1) == ",") ?
					Settings.get_default().color_scheme.get_indexed_color(5, !Settings.get_default().dark) :
					Settings.get_default().background_color;

			text = "<span foreground='" +
					Utilities.get_parsable_color_string(text_color) +
					"' font_desc='" +
					Settings.get_default().terminal_font_name + "'>" + markup + "</span>";
		}

		private void on_settings_changed(string? key) {
			update();
		}

	}

}
