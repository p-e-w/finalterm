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

	public string get_selected_text() {
		return terminal_output_view.get_selected_text();
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

	public bool is_active { get; set; }

	private Terminal terminal;
	private GtkClutter.Embed clutter_embed;

	private LineContainer line_container;

	private Mx.Label cursor;
	private Clutter.PropertyTransition blinking_animation;

	private Mx.Button menu_button;
	private Mx.Label menu_button_label;
	private string menu_button_text;
	private TextMenu text_menu;

	private Gee.Set<int> updated_lines = new Gee.HashSet<int>();

	private bool is_selecting = false;

	public TerminalOutputView(Terminal terminal, GtkClutter.Embed clutter_embed) {
		this.terminal = terminal;
		this.clutter_embed = clutter_embed;

		line_container = new LineContainer();
		add(line_container);

		// Initial synchronization with model
		add_line_views();

		// Reposition cursor when line container is scrolled
		// to make it scroll along with it
		line_container.horizontal_adjustment.changed.connect(() => {
			position_terminal_cursor(false);
		});
		line_container.vertical_adjustment.changed.connect(() => {
			position_terminal_cursor(false);
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
			// Clicking on menu button triggers an unwanted leave_event, which is
			// ignored if event coordinates are in the button
			if (event.x > menu_button.x && event.x < menu_button.x + menu_button.get_width()
					&& event.y > menu_button.y && event.y < menu_button.y + menu_button.get_height())
				return false;
			if (!menu_button.toggled)
				get_parent().remove(menu_button);
			return false;
		});
		menu_button.clicked.connect(on_menu_button_clicked);

		menu_button_label = new Mx.Label();
		menu_button_label.use_markup = true;
		menu_button.add(menu_button_label);

		// Cursor and menu button need to float above all other children of the TerminalOutputView
		// so they are added to the parent (TerminalView)
		parent_set.connect((old_parent) => {
			get_parent().add(cursor);
		});

		allocation_changed.connect(on_allocation_changed);

		notify["is-active"].connect(() => {
			if (is_active) {
				render_terminal_cursor();
			} else {
				cursor.hide();
			}
		});

		on_settings_changed(null);
		Settings.get_default().changed.connect(on_settings_changed);

		motion_event.connect(on_motion_event);
		button_press_event.connect(on_button_press_event);
		button_release_event.connect(on_button_release_event);
	}

	public string get_selected_text() {
		return line_container.get_selected_text();
	}

	private bool on_motion_event(Clutter.MotionEvent event) {
		if (is_selecting) {
			line_container.selecting(event.x, event.y);
		}
		return true;
	}

	private bool on_button_press_event(Clutter.ButtonEvent event) {
		is_selecting = true;
		line_container.selection_start(event.x, event.y);
		return true;
	}

	private bool on_button_release_event(Clutter.ButtonEvent event) {
		is_selecting = false;
		line_container.selection_end(event.x, event.y);
		return true;
	}	

	private void on_menu_button_clicked() {
		if (menu_button.toggled) {
			text_menu.text = menu_button_text;

			// TODO: Disconnect handler after menu has been closed
			text_menu.menu.deactivate.connect(() => {
				text_menu.menu.popdown();

				menu_button.toggled  = false;
				menu_button.disabled = false;

				get_parent().remove(menu_button);					
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
	public void add_line_views() {
		for (int i = line_container.get_line_count(); i < terminal.terminal_output.size; i++) {
			var line_view = new LineView(terminal.terminal_output[i], line_container);
			line_view.collapsed.connect(on_line_view_collapsed);
			line_view.expanded.connect(on_line_view_expanded);
			line_view.text_menu_element_hovered.connect(on_line_view_text_menu_element_hovered);

			line_container.add_line_view(line_view);
		}

		// Note that this suffices to ensure scrolling space is always in sync with the model,
		// because line_added is invoked after each adjustment to screen_offset in TerminalOutput
		adjust_scrolling_space();
	}

	private void on_line_view_collapsed(LineView line_view) {
		for (int i = line_container.get_line_view_index(line_view) + 1;
				i < line_container.get_line_count(); i++) {
			if (line_container.get_line_view(i).is_prompt_line)
				break;

			line_container.get_line_view(i).visible = false;
		}
	}

	private void on_line_view_expanded(LineView line_view) {
		for (int i = line_container.get_line_view_index(line_view) + 1;
				i < line_container.get_line_count(); i++) {
			if (line_container.get_line_view(i).is_prompt_line)
				break;

			line_container.get_line_view(i).visible = true;
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
				"<span font_desc=\"" + Settings.get_default().label_font_name + "\">" +
				Markup.escape_text(text_menu.label) + ":  " +
				"</span>" +
				"<span font_desc=\"" + Settings.get_default().terminal_font_name + "\">" +
				Markup.escape_text(text) +
				"</span>" +
				"<span foreground=\"" +
				Utilities.get_parsable_color_string(Settings.get_default().theme.menu_button_arrow_color) +
				"\">  ▼</span>";

		int descriptor_width;
		int descriptor_height;
		Utilities.get_text_size(Settings.get_default().label_font, text_menu.label + ":  ",
				out descriptor_width, out descriptor_height);

		float line_view_x;
		float line_view_y;
		line_view.get_transformed_position(out line_view_x, out line_view_y);
		// TODO: Get padding from style
		menu_button.x = (int)line_view_x + x - 3 - descriptor_width;
		menu_button.y = (int)line_view_y + y - 3;

		get_parent().add(menu_button);
	}

	public void mark_line_as_updated(int line_index) {
		updated_lines.add(line_index);
	}

	public void render_terminal_output() {
		render_terminal_text();
		render_terminal_cursor();
	}

	private void render_terminal_text() {
		terminal.terminal_output.print_transient_text();

		foreach (var i in updated_lines) {
			terminal.terminal_output[i].optimize();
			line_container.get_line_view(i).render_line();
		}

		updated_lines.clear();
	}

	private void render_terminal_cursor() {
		if (!position_terminal_cursor(true))
			return;

		TerminalOutput.CursorPosition cursor_position = terminal.terminal_output.cursor_position;
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
		cursor.clutter_text.font_name = Settings.get_default().terminal_font_name;

		// Rewind animation on each render (i.e. update) event
		// to match standard editor user experience
		blinking_animation.direction = Clutter.TimelineDirection.FORWARD;
		blinking_animation.rewind();
	}

	private bool position_terminal_cursor(bool animate) {
		TerminalOutput.CursorPosition cursor_position = terminal.terminal_output.cursor_position;

		if (!is_active || cursor_position.line >= line_container.get_line_count()) {
			cursor.hide();
			return false;
		}

		cursor.show();

		int cursor_x;
		int cursor_y;
		get_stage_position(cursor_position, out cursor_x, out cursor_y);

		if (animate) {
			cursor.save_easing_state();
			cursor.set_easing_mode(Clutter.AnimationMode.LINEAR);
			cursor.set_easing_duration(Settings.get_default().theme.cursor_motion_speed);
		}

		cursor.x = cursor_x;
		cursor.y = cursor_y;

		if (animate)
			cursor.restore_easing_state();

		return true;
	}

	private void adjust_scrolling_space() {
		int additional_lines = terminal.terminal_output.screen_offset +
				terminal.lines - terminal.terminal_output.size;
		double scrolling_space = additional_lines * Settings.get_default().character_height;

		line_container.set_scrolling_space(scrolling_space);
	}

	public void scroll_to_position(TerminalOutput.CursorPosition position = {-1, -1}) {
		if (position.line >= line_container.get_line_count())
			return;

		var geometry = Clutter.Geometry();

		if (position.line == -1 && position.column == -1) {
			// Default: Scroll to end
			// Note that this is much faster than the code below
			// because it avoids the expensive get_allocation_box
			geometry.x      = 0;
			geometry.y      = int.MAX;
			geometry.width  = 0;
			geometry.height = 0;
		} else {
			// NOTE: line_container.get_line_view(position.line).get_geometry() does not work here
			//       because the layout manager takes over positioning
			// TODO: Is that still true?
			var allocation_box = line_container.get_line_view(position.line).get_allocation_box();
			// TODO: This does not take the column into account
			geometry.x      = (int)allocation_box.get_x();
			geometry.y      = (int)allocation_box.get_y();
			geometry.width  = (uint)allocation_box.get_width();
			geometry.height = (uint)allocation_box.get_height();
		}

		ensure_visible(geometry);
	}

	private void get_position_coordinates(TerminalOutput.CursorPosition position, out int x, out int y) {
		line_container.get_line_view(position.line).get_character_coordinates(position.column, out x, out y);
	}

	private void get_stage_position(TerminalOutput.CursorPosition position, out int? x, out int? y) {
		if (position.line >= line_container.get_line_count()) {
			x = null;
			y = null;
			return;
		}

		float line_view_x;
		float line_view_y;
		line_container.get_line_view(position.line).get_transformed_position(out line_view_x, out line_view_y);

		int character_x;
		int character_y;
		get_position_coordinates(position, out character_x, out character_y);

		x = (int)line_view_x + character_x;
		y = (int)line_view_y + character_y;
	}

	public void get_screen_position(TerminalOutput.CursorPosition position, out int? x, out int? y) {
		if (position.line >= line_container.get_line_count()) {
			x = null;
			y = null;
			return;
		}

		int line_view_x;
		int line_view_y;
		Utilities.get_actor_screen_position(clutter_embed, line_container.get_line_view(position.line),
				out line_view_x, out line_view_y);

		int character_x;
		int character_y;
		get_position_coordinates(position, out character_x, out character_y);

		x = line_view_x + character_x;
		y = line_view_y + character_y;
	}

	public int get_horizontal_padding() {
		return
			// Scrollbar width + padding (see style.css)
			14 +
			// LineView padding
			Settings.get_default().theme.gutter_size +
				Settings.get_default().theme.margin_left +
				Settings.get_default().theme.margin_right;
	}

	public int get_vertical_padding() {
		return 0;
	}

	private void on_allocation_changed(Clutter.ActorBox box, Clutter.AllocationFlags flags) {
		// 45 pixels is the size of the margin used to hide
		// the ScrollView "shadow" (see above)
		int lines = ((int)box.get_height() - get_vertical_padding() - 45) /
				Settings.get_default().character_height;
		int columns = ((int)box.get_width() - get_horizontal_padding()) /
				Settings.get_default().character_width;

		if (lines <= 0 || columns <= 0)
			// Invalid size
			return;

		if (terminal.lines == lines && terminal.columns == columns)
			// No change in size
			return;

		// Notify terminal of size change
		terminal.lines   = lines;
		terminal.columns = columns;
		// TODO: Use Utilities.schedule_execution here?
		terminal.update_size();

		adjust_scrolling_space();
	}

	private void on_settings_changed(string? key) {
		style = Settings.get_default().theme.style;
		menu_button.style = Settings.get_default().theme.style;
		menu_button_label.style = Settings.get_default().theme.style;

		cursor.width  = Settings.get_default().character_width;
		cursor.height = Settings.get_default().character_height;

		// TODO: This animation forces constant (expensive) repainting of line_container
		var interval = new Clutter.Interval.with_values(typeof(int),
				Settings.get_default().theme.cursor_maximum_opacity,
				Settings.get_default().theme.cursor_minimum_opacity);
		blinking_animation.set_interval(interval);
		blinking_animation.duration = Settings.get_default().theme.cursor_blinking_interval;
		cursor.remove_transition("blinking-animation");
		cursor.add_transition("blinking-animation", blinking_animation);

		render_terminal_cursor();
	}

}


// A stack-layouting container similar in concept to Mx.BoxLayout,
// but with vastly higher performance
public class LineContainer : Clutter.Actor, Mx.Scrollable {

	private Gee.List<LineView> line_views = new Gee.ArrayList<LineView>();

	private struct Selection {
		private TerminalOutput.CursorPosition start;
		private TerminalOutput.CursorPosition finish;
		
		public Selection(TerminalOutput.CursorPosition position) {
			start = position;
		}

		public void update(TerminalOutput.CursorPosition position) {
			finish = position;
		}

		// end position can be before or after start position
		// this function returns them in correct order
		public void get_range(out TerminalOutput.CursorPosition beginning, out TerminalOutput.CursorPosition end) {
			if (start.compare(finish) > 0) {
				beginning = finish;
				end = start;
			} else {
				beginning = start;
				end = finish;
			} 
		}
	}

	private Selection current_selection;

	// PERFORMANCE: This data structure allows for efficient determination
	//              of which children are inside the scrolled area, making it
	//              possible to paint only those children that are visible to the user
	private Gee.SortedMap<int, Clutter.Actor> y_index = new Gee.TreeMap<int, Clutter.Actor>();

	public Mx.Adjustment horizontal_adjustment { owned get; set; default = new Mx.Adjustment(); }

	public Mx.Adjustment vertical_adjustment { owned get; set; default = new Mx.Adjustment(); }

	public void get_adjustments(out unowned Mx.Adjustment? hadjustment, out unowned Mx.Adjustment? vadjustment) {
		// TODO: This works, and takes care of all the owned/unowned difficulties,
		//       but is a hack nonetheless (Vala seems to implicitly create these variables)
		hadjustment = _horizontal_adjustment;
		vadjustment = _vertical_adjustment;
	}

	public void set_adjustments(Mx.Adjustment hadjustment, Mx.Adjustment vadjustment) {
		horizontal_adjustment = hadjustment;
		vertical_adjustment = vadjustment;
	}

	private double scrolling_space = 0;

	public void set_scrolling_space(double scrolling_space) {
		vertical_adjustment.upper += (scrolling_space - this.scrolling_space);
		this.scrolling_space = scrolling_space;
	}

	public void add_line_view(LineView line_view) {
		line_views.add(line_view);

		// PERFORMANCE: This appends line_view in constant time, while add_child
		//              takes linear (or even superlinear?) time, depending on the number
		//              of children already present in the LineContainer
		//              (cf. https://mail.gnome.org/archives/clutter-list/2013-September/msg00005.html)
		insert_child_at_index(line_view, -1);
	}

	public LineView get_line_view(int index) {
		return line_views[index];
	}

	public int get_line_view_index(LineView line_view) {
		return line_views.index_of(line_view);
	}

	public int get_line_count() {
		return line_views.size;
	}

	public void selecting(float x, double y) {
		current_selection.update(get_coordinates_position(x, y));
		TerminalOutput.CursorPosition beginning = TerminalOutput.CursorPosition();
		TerminalOutput.CursorPosition end = TerminalOutput.CursorPosition();

		current_selection.get_range(out beginning, out end);

		int from = 0;
		int to = 0;
		bool rectangle = false;

		for (int i = 0; i < get_line_count(); i++) {
			if (!line_views[i].visible) {
				continue;
			}

			from = to = 0;

			if (rectangle) {
				if (i >= beginning.line) {
					from = beginning.column;
				} 
				if (i >= beginning.line && i <= end.line) {
					to = end.column;
				} 
				if(i >= beginning.line && i <= end.line && from > to) {
					from = from + to;
					to = from - to;
					from = from - to;
				}
			} else  {
				if (i == beginning.line) {
					from = beginning.column;
				} 
				if (i >= beginning.line && i < end.line) {
					to = -1;
				} else if (i == end.line) {
					to = end.column;
				} 
			}

			line_views[i].set_selection(from, to);
			line_views[i].render_line();
		}

	}

	public void selection_start(float x, double y) {
		current_selection = Selection(get_coordinates_position(x, y));
		for (int i = 0; i < get_line_count(); i++) {
			line_views[i].set_selection(0, 0);
			line_views[i].render_line();
		}
	}

	public void selection_end(float x, double y) {

	}

	public string get_selected_text() {
		string text = "";
		TerminalOutput.CursorPosition beginning = TerminalOutput.CursorPosition();
		TerminalOutput.CursorPosition end = TerminalOutput.CursorPosition();
		current_selection.get_range(out beginning, out end);

		for (int i = beginning.line; i <= end.line; i++) {
			var line_text = line_views[i].get_selected_text().strip();
			if(line_text != "") {
				text += line_text + "\n";
			}
		}
		return text.strip();
	}

	private TerminalOutput.CursorPosition get_coordinates_position(float x, double y) {
		Mx.Adjustment hadjustment = new Mx.Adjustment();
		Mx.Adjustment vadjustment = new Mx.Adjustment();
		get_adjustments(out hadjustment, out vadjustment);

		TerminalOutput.CursorPosition position = TerminalOutput.CursorPosition();

		for (int i = 0; i < get_line_count(); i++) {
			if (!line_views[i].visible) {
				continue;
			}

			if (line_views[i].get_height() + line_views[i].get_allocation_box().get_y() >= y + vadjustment.value) {
				position.line = i;
				position.column = line_views[i].get_coordinates_character(x, (float)y);
				break;
			}
		}

		return position;
	}

	protected override void allocate(Clutter.ActorBox box, Clutter.AllocationFlags flags) {
		base.allocate(box, flags);

		var child_box = Clutter.ActorBox();
		child_box.x1 = box.x1;
		child_box.x2 = box.x2;

		float y_offset = 0;
		float child_height;

		y_index.clear();

		// Simple vertical stacking layout
		foreach (var line_view in line_views) {
			if (!line_view.visible)
				continue;

			// Index child with its vertical offset
			y_index.set((int)y_offset, line_view);

			line_view.get_preferred_height(child_box.get_width(), null, out child_height);

			child_box.y1 = y_offset;
			child_box.y2 = child_box.y1 + child_height;

			line_view.allocate(child_box, flags);

			y_offset = child_box.y2;
		}

		// The 15 additional pixels of scrolling space are required
		// to compensate for the margin used to hide the ScrollView
		// "shadow" (see above)
		vertical_adjustment.upper = y_offset + 15 + scrolling_space;
		vertical_adjustment.page_size = box.get_height();
		vertical_adjustment.step_increment = Settings.get_default().character_height;
		// Ensure that page_increment is an integer multiple of step_increment
		vertical_adjustment.page_increment =
				((int)(vertical_adjustment.page_size /
				       vertical_adjustment.step_increment)) *
				vertical_adjustment.step_increment;
	}

	// Many of the ideas in the following functions are taken from
	// https://github.com/clutter-project/mx/blob/master/mx/mx-box-layout.c
	protected override void apply_transform(ref Clutter.Matrix matrix) {
		base.apply_transform(ref matrix);

		// Translate the actor so that the scrolled area is visible
		matrix.translate(-(float)horizontal_adjustment.value, -(float)vertical_adjustment.value, 0);
	}

	protected override bool get_paint_volume(Clutter.PaintVolume volume) {
		if (!volume.set_from_allocation(this))
			return false;

		// Restrict painting to the scrolled area
		var origin = volume.get_origin();
		origin.x += (float)horizontal_adjustment.value;
		origin.y += (float)vertical_adjustment.value;
		volume.set_origin(origin);

		return true;
	}

	protected override void paint() {
		do_paint();
	}

	protected override void pick(Clutter.Color color) {
		do_paint();
	}

	private void do_paint() {
		// Paint only the children inside the scrolled area
		int y_start = (int)vertical_adjustment.value;
		int y_end   = y_start + (int)allocation.get_height();

		var children_to_paint = y_index.sub_map(y_start, y_end).values;

		foreach (var child in children_to_paint) {
			child.paint();
		}
	}

}
