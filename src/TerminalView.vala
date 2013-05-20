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

// TODO: Clean up the relationship between TerminalView and TerminalOutputView
public class TerminalView : Mx.BoxLayout {

	private Terminal terminal;
	private GtkClutter.Embed clutter_embed;

	private Clutter.Rectangle gutter;

	public TerminalOutputView terminal_output_view;

	private Clutter.Actor status_container;
	private Mx.ProgressBar progress_bar;
	private Mx.Label progress_label;
	private Mx.Label progress_label_shadow;

	public TerminalView(Terminal terminal, GtkClutter.Embed clutter_embed) {
		this.terminal = terminal;
		this.clutter_embed = clutter_embed;

		orientation = Mx.Orientation.VERTICAL;

		var container = new Clutter.Actor();

		gutter = new Clutter.Rectangle();
		container.add(gutter);
		gutter.x = -1;
		gutter.y = -1;
		gutter.has_border = true;
		gutter.border_width = 1;
		gutter.add_constraint(new Clutter.BindConstraint(container, Clutter.BindCoordinate.HEIGHT, 2));

		terminal_output_view = new TerminalOutputView(terminal, clutter_embed);
		container.add(terminal_output_view);

		add(container);
		child_set_expand(container, true);
		// TODO: Mx bug? If height of container is not set, it fails to expand properly
		container.height = 0;

		/*
		 * The goal here is to work around the fact that the Mx ScrollView "shadow"
		 * cannot be disabled by clipping the ScrollView and compensating for the clipping
		 * using padding (see style.css). However, multiple Mx bugs stand in the way.
		 * Notably, the ScrollView fails to calculate the child widget's height properly
		 * when padding is applied. The "solution" seen here was found by examining the
		 * Mx source code (https://github.com/clutter-project/mx/tree/master/mx)
		 * and currently only works with vertical scrolling.
		 */
		// TODO: Take padding into account when calculating terminal dimensions in characters
		// TODO: The scrollbar's top and bottom ranges lie slightly outside the visible part of the view
		terminal_output_view.add_constraint(new Clutter.BindConstraint(container, Clutter.BindCoordinate.X, 0));
		terminal_output_view.add_constraint(new Clutter.BindConstraint(container, Clutter.BindCoordinate.Y, -15));
		terminal_output_view.add_constraint(new Clutter.BindConstraint(container, Clutter.BindCoordinate.WIDTH, 0));
		terminal_output_view.add_constraint(new Clutter.BindConstraint(container, Clutter.BindCoordinate.HEIGHT, 45));
		container.clip_to_allocation = true;

		status_container = new Clutter.Actor();

		progress_bar = new Mx.ProgressBar();
		status_container.add(progress_bar);
		progress_bar.add_constraint(new Clutter.BindConstraint(status_container, Clutter.BindCoordinate.SIZE, 0));

		progress_label_shadow = new Mx.Label();
		progress_label_shadow.style_class = "progress-label-shadow";
		status_container.add(progress_label_shadow);
		progress_label = new Mx.Label();
		progress_label.style_class = "progress-label";
		status_container.add(progress_label);

		add(status_container);

		status_container.visible = false;

		on_settings_changed(null);
		Settings.get_default().changed.connect(on_settings_changed);
	}

	public void show_progress(int percentage, string label = "") {
		status_container.visible = true;
		progress_bar.visible = true;
		progress_label.text = label;
		progress_label_shadow.text = label;
		progress_bar.progress = (double)percentage / 100.0;
	}

	public void hide_progress() {
		status_container.visible = false;
	}

	public bool window_has_focus() {
		return (clutter_embed.get_toplevel() as Gtk.Window).has_toplevel_focus;
	}

	private void on_settings_changed(string? key) {
		gutter.width = Settings.get_default().theme.gutter_size;
		gutter.color = Settings.get_default().theme.gutter_color;
		gutter.border_color = Settings.get_default().theme.gutter_border_color;

		progress_bar.style = Settings.get_default().theme.style;
		progress_label.style = Settings.get_default().theme.style;
		progress_label_shadow.style = Settings.get_default().theme.style;
	}

}


// TODO: Reimplement this on top of ScrollableListView
public class TerminalOutputView : Mx.ScrollView {

	private Terminal terminal;
	private GtkClutter.Embed clutter_embed;

	private Mx.BoxLayout line_container;

	private Mx.Label cursor;
	private Clutter.PropertyTransition blinking_animation;

	private Mx.Button menu_button;
	private Mx.Label menu_button_label;
	private string menu_button_text;
	private TextMenu text_menu;

	private Gee.List<LineView> line_views = new Gee.ArrayList<LineView>();

	private Gee.Set<int> updated_lines = new Gee.HashSet<int>();

	public TerminalOutputView(Terminal terminal, GtkClutter.Embed clutter_embed) {
		this.terminal = terminal;
		this.clutter_embed = clutter_embed;

		// TODO: Set scrolling adjustments (increment should equal character size)

		line_container = new Mx.BoxLayout();
		line_container.orientation = Mx.Orientation.VERTICAL;
		line_container.allocation_changed.connect(on_line_container_allocation_changed);
		add(line_container);

		// Reposition cursor when line container is scrolled
		// to make it scroll along with it
		line_container.horizontal_adjustment.changed.connect(() => {
			position_terminal_cursor();
		});
		line_container.vertical_adjustment.changed.connect(() => {
			position_terminal_cursor();
		});

		cursor = new Mx.Label();
		cursor.use_markup = true;

		blinking_animation = new Clutter.PropertyTransition("opacity");
		blinking_animation.repeat_count = -1;
		blinking_animation.auto_reverse = true;
		blinking_animation.progress_mode = Clutter.AnimationMode.EASE_IN_CUBIC;

		menu_button = new Mx.Button();
		menu_button.is_toggle = true;
		menu_button.style_class = "menu-button";
		menu_button.leave_event.connect((event) => {
			if (!menu_button.toggled)
				menu_button.visible = false;
			return false;
		});
		menu_button.clicked.connect(on_menu_button_clicked);
		menu_button.visible = false;

		menu_button_label = new Mx.Label();
		menu_button_label.use_markup = true;
		menu_button.add(menu_button_label);

		// Cursor and menu button need to float above all other actors
		// so they are added directly to the stage. However, get_stage()
		// returns null before the TerminalOutputView is added to a stage
		// (i.e. "realized").
		realize.connect(() => {
			get_stage().add(cursor);
			get_stage().add(menu_button);
		});

		on_settings_changed(null);
		Settings.get_default().changed.connect(on_settings_changed);
	}

	private void on_menu_button_clicked() {
		if (menu_button.toggled) {
			text_menu.text = menu_button_text;

			// TODO: Disconnect handler after menu has been closed
			text_menu.menu.deactivate.connect(() => {
				text_menu.menu.popdown();

				menu_button.toggled  = false;
				menu_button.disabled = false;

				// TODO: This does not work reliably
				//if (!menu_button.has_pointer)
					menu_button.visible = false;
			});

			text_menu.menu.popup(null, null, (menu, out x, out y, out push_in) => {
				Utilities.get_actor_screen_position(clutter_embed, menu_button, out x, out y);
				y += (int)menu_button.height;
				push_in = true;
			}, 0, 0);

			// The button is disabled here (and re-enabled when the menu is closed)
			// because the menu's "deactivate" and the button's "clicked" signal get called
			// in the wrong order, causing a click on the button while the menu is shown
			// to first close and then immediately reopen the menu. Disabling the button
			// while the menu is shown prevents this from happening.
			menu_button.disabled = true;

		} else {
			text_menu.menu.popdown();
		}
	}

	// Expands the list of line views until it contains as many elements as the model
	private void add_line_views() {
		for (int i = line_views.size; i < terminal.terminal_output.size; i++) {
			var line_view = new LineView(terminal.terminal_output[i]);
			line_view.collapsed.connect(on_line_view_collapsed);
			line_view.expanded.connect(on_line_view_expanded);
			line_view.text_menu_element_hovered.connect(on_line_view_text_menu_element_hovered);
			line_views.add(line_view);
			line_container.add(line_view);
		}
	}

	private void on_line_view_collapsed(LineView line_view) {
		for (int i = line_views.index_of(line_view) + 1; i < line_views.size; i++) {
			if (line_views[i].is_collapsible_end)
				break;

			line_views[i].visible = false;
		}
	}

	private void on_line_view_expanded(LineView line_view) {
		for (int i = line_views.index_of(line_view) + 1; i < line_views.size; i++) {
			if (line_views[i].is_collapsible_end)
				break;

			line_views[i].visible = true;
		}
	}

	private void on_line_view_text_menu_element_hovered(LineView line_view, int x, int y, int width, int height,
			string text, TextMenu text_menu) {
		if (menu_button.toggled)
			return;

		menu_button_text = text;
		this.text_menu   = text_menu;

		menu_button.toggled = false;
		menu_button.background_color = Settings.get_default().color_scheme.get_indexed_color(
				text_menu.color, Settings.get_default().dark);

		menu_button_label.text =
				"<span font_desc=\"" + Settings.get_default().theme.proportional_font.to_string() + "\">" +
				Markup.escape_text(text_menu.label) + ":  " +
				"</span>" +
				"<span font_desc=\"" + Settings.get_default().theme.monospaced_font.to_string() + "\">" +
				Markup.escape_text(text) +
				"</span>" +
				"<span foreground=\"" +
				Utilities.get_parsable_color_string(Settings.get_default().theme.menu_button_arrow_color) +
				"\">  ▼</span>";

		int descriptor_width;
		int descriptor_height;
		Utilities.get_text_size(Settings.get_default().theme.proportional_font, text_menu.label + ":  ",
				out descriptor_width, out descriptor_height);

		float line_view_x;
		float line_view_y;
		line_view.get_transformed_position(out line_view_x, out line_view_y);
		// TODO: Get padding from style
		menu_button.x = (int)line_view_x + x - 3 - descriptor_width;
		menu_button.y = (int)line_view_y + y - 3;

		menu_button.visible = true;
	}

	public void mark_line_as_updated(int line_index) {
		updated_lines.add(line_index);
		// TODO: Move this(?)
		add_line_views();
	}

	public void render_terminal_output() {
		render_terminal_text();
		render_terminal_cursor();
	}

	private void render_terminal_text() {
		Metrics.start_block_timer(Log.METHOD);

		terminal.terminal_output.print_transient_text();

		foreach (var i in updated_lines) {
			terminal.terminal_output[i].optimize();
			line_views[i].render_line();
		}

		updated_lines.clear();

		scroll_to_position(terminal.terminal_output.cursor_position);

		Metrics.stop_block_timer(Log.METHOD);
	}

	private void render_terminal_cursor() {
		Metrics.start_block_timer(Log.METHOD);

		position_terminal_cursor();

		TerminalOutput.CursorPosition cursor_position = terminal.terminal_output.cursor_position;

		if (cursor_position.line >= line_views.size) {
			// If the cursor cannot be rendered correctly, hide it
			cursor.hide();
			Metrics.stop_block_timer(Log.METHOD);
			return;
		}

		cursor.show();

		var character_elements = terminal.terminal_output[cursor_position.line].explode();

		string cursor_character;
		TextAttributes cursor_attributes;
		if (cursor_position.column >= character_elements.size) {
			// Cursor is at the end of the line
			cursor_character = "";
			// Default attributes
			cursor_attributes = new CharacterAttributes().get_text_attributes(
					Settings.get_default().color_scheme, Settings.get_default().dark);
		} else {
			cursor_character  = character_elements[cursor_position.column].text;
			cursor_attributes = character_elements[cursor_position.column].attributes
					.get_text_attributes(Settings.get_default().color_scheme, Settings.get_default().dark);
		}

		// Switch foreground and background colors for cursor
		cursor.background_color = cursor_attributes.foreground_color;
		cursor_attributes.foreground_color = cursor_attributes.background_color;
		// Set attributes' background color to default to leave background color rendering
		// to the actor rather than Pango (more reliable and consistent)
		cursor_attributes.background_color = Settings.get_default().background_color;

		var markup_attributes = cursor_attributes.get_markup_attributes(
				Settings.get_default().color_scheme, Settings.get_default().dark);

		cursor.text =
				"<span" + markup_attributes + ">" +
				Markup.escape_text(cursor_character) +
				"</span>";

		// Apparently, Mx recreates the Clutter text actor each time
		// the label text is set, so the font has to be reset afterwards
		cursor.clutter_text.font_name = Settings.get_default().theme.monospaced_font.to_string();

		// Rewind animation on each render (i.e. update) event
		// to match standard editor user experience
		blinking_animation.direction = Clutter.TimelineDirection.FORWARD;
		blinking_animation.rewind();

		Metrics.stop_block_timer(Log.METHOD);
	}

	private void position_terminal_cursor() {
		Metrics.start_block_timer(Log.METHOD);

		TerminalOutput.CursorPosition cursor_position = terminal.terminal_output.cursor_position;

		if (cursor_position.line >= line_views.size) {
			// If the cursor cannot be positioned correctly, hide it
			cursor.hide();
			Metrics.stop_block_timer(Log.METHOD);
			return;
		}

		cursor.show();

		int cursor_x;
		int cursor_y;
		get_stage_position(cursor_position, out cursor_x, out cursor_y);
		cursor.x = cursor_x;
		cursor.y = cursor_y;

		Metrics.stop_block_timer(Log.METHOD);
	}

	public void scroll_to_position(TerminalOutput.CursorPosition position) {
		if (position.line >= line_views.size)
			return;

		// NOTE: line_views[position.line].get_geometry() does not work here
		//       because the layout manager takes over positioning
		var geometry = Clutter.Geometry();
		var allocation_box = line_views[position.line].get_allocation_box();
		geometry.x      = (int)allocation_box.get_x();
		geometry.y      = (int)allocation_box.get_y();
		geometry.width  = (uint)allocation_box.get_width();
		geometry.height = (uint)allocation_box.get_height();

		// TODO: This does not take the column into account
		ensure_visible(geometry);
	}

	private void get_position_coordinates(TerminalOutput.CursorPosition position, out int x, out int y) {
		line_views[position.line].get_character_coordinates(position.column, out x, out y);
	}

	private void get_stage_position(TerminalOutput.CursorPosition position, out int? x, out int? y) {
		if (position.line >= line_views.size) {
			x = null;
			y = null;
			return;
		}

		float line_view_x;
		float line_view_y;
		line_views[position.line].get_transformed_position(out line_view_x, out line_view_y);

		int character_x;
		int character_y;
		get_position_coordinates(position, out character_x, out character_y);

		x = (int)line_view_x + character_x;
		y = (int)line_view_y + character_y;
	}

	public void get_screen_position(TerminalOutput.CursorPosition position, out int? x, out int? y) {
		if (position.line >= line_views.size) {
			x = null;
			y = null;
			return;
		}

		int line_view_x;
		int line_view_y;
		Utilities.get_actor_screen_position(clutter_embed, line_views[position.line],
				out line_view_x, out line_view_y);

		int character_x;
		int character_y;
		get_position_coordinates(position, out character_x, out character_y);

		x = line_view_x + character_x;
		y = line_view_y + character_y;
	}

	private int get_visible_lines() {
		// 45 pixels is the size of the margin used to hide
		// the ScrollView "shadow" (see above)
		return ((int)height - get_vertical_padding() - 45) /
			   Settings.get_default().theme.character_height;
	}

	private int get_visible_columns() {
		if (line_container.width > Settings.get_default().theme.gutter_size) {
			return ((int)width - get_horizontal_padding()) /
				   Settings.get_default().theme.character_width;
		} else {
			return 0;
		}
	}

	public int get_horizontal_padding() {
		return
			// Account for scrollbar (if shown)
			(int)(width - line_container.width) +
			// Account for LineView padding
			Settings.get_default().theme.gutter_size +
				Settings.get_default().theme.margin_left +
				Settings.get_default().theme.margin_right;
	}

	public int get_vertical_padding() {
		return 0;
	}

	// Called when size (or position) of line container changes
	private void on_line_container_allocation_changed(Clutter.ActorBox box, Clutter.AllocationFlags flags) {
		// TODO: Add information about instance to key
		Utilities.schedule_execution(resize_terminal, "resize", Settings.get_default().resize_interval);
	}

	private void resize_terminal() {
		int lines   = get_visible_lines();
		int columns = get_visible_columns();

		if (lines == 0 || columns == 0)
			return;

		if (terminal.lines == lines && terminal.columns == columns)
			// No change in size
			return;

		// Notify terminal of size change
		terminal.lines   = lines;
		terminal.columns = columns;
		terminal.update_size();
	}

	private void on_settings_changed(string? key) {
		style = Settings.get_default().theme.style;
		line_container.style = Settings.get_default().theme.style;
		menu_button.style = Settings.get_default().theme.style;
		menu_button_label.style = Settings.get_default().theme.style;

		cursor.width  = Settings.get_default().theme.character_width;
		cursor.height = Settings.get_default().theme.character_height;

		var interval = new Clutter.Interval.with_values(typeof(int),
				Settings.get_default().theme.cursor_maximum_opacity,
				Settings.get_default().theme.cursor_minimum_opacity);
		blinking_animation.set_interval(interval);
		blinking_animation.duration = Settings.get_default().theme.cursor_animation_duration;
		cursor.remove_transition("blinking-animation");
		cursor.add_transition("blinking-animation", blinking_animation);

		render_terminal_cursor();
	}

}
