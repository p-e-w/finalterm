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

public class LineView : Clutter.Actor {

	private TerminalOutput.OutputLine original_output_line;
	private TerminalOutput.OutputLine output_line;

	private Mx.Button collapse_button;
	private Clutter.Text text_container;

	// If set to true, everything between this line
	// and the next line with collapsible_end = true
	// can be collapsed
	public bool is_collapsible_start { get; set; default = false; }
	public bool is_collapsible_end   { get; set; default = false; }

	public LineView(TerminalOutput.OutputLine output_line) {
		layout_manager = new Clutter.BoxLayout();

		original_output_line = output_line;

		collapse_button = new Mx.Button.with_label("▼");
		collapse_button.is_toggle = true;
		collapse_button.toggled = false;

		collapse_button.style_class = "collapse-button";
		collapse_button.clicked.connect(on_collapse_button_clicked);

		add(collapse_button);

		text_container = new Clutter.Text();

		// This should simply be
		//   text_container.x_expand = true;
		// but that causes compilation problems on platforms having
		// outdated versions of Clutter or its Vala bindings
		(layout_manager as Clutter.BoxLayout).set_expand(text_container, true);
		(layout_manager as Clutter.BoxLayout).set_fill(text_container, true, false);

		text_container.line_wrap = true;
		text_container.line_wrap_mode = Pango.WrapMode.CHAR;

		text_container.reactive = true;
		text_container.motion_event.connect(on_text_container_motion_event);

		add(text_container);

		on_settings_changed(null);
		Settings.get_default().changed.connect(on_settings_changed);
	}

	private void on_collapse_button_clicked() {
		if (is_collapsible_start) {
			if (collapse_button.toggled) {
				collapse_button.set_label("▶");
				collapsed(this);
			} else {
				collapse_button.set_label("▼");
				expanded(this);
			}
		}
	}

	public signal void collapsed(LineView line_view);

	public signal void expanded(LineView line_view);

	public void get_character_coordinates(int character_index, out int x, out int y) {
		float character_x;
		float character_y;
		text_container.position_to_coords(character_index, out character_x, out character_y);
		x = (int)(character_x + text_container.x);
		y = (int)(character_y + text_container.y);
	}

	private bool on_text_container_motion_event(Clutter.MotionEvent event) {
		// Apparently, motion event coordinates are relative to the stage
		// (the Clutter documentation does not specify this)
		float text_container_x;
		float text_container_y;
		text_container.get_transformed_position(out text_container_x, out text_container_y);

		int byte_index;
		int trailing;
		if (text_container.get_layout().xy_to_index(
				(int)(event.x - text_container_x) * Pango.SCALE,
				(int)(event.y - text_container_y) * Pango.SCALE,
				out byte_index, out trailing)) {

			var character_index = Utilities.byte_index_to_character_index(
					output_line.get_text(), byte_index);

			TerminalOutput.TextElement text_element;
			int position;
			output_line.get_text_element_from_index(character_index, out text_element, out position);

			if (text_element.attributes.text_menu != null) {
				int character_x;
				int character_y;
				get_character_coordinates(position, out character_x, out character_y);

				text_menu_element_hovered(
						this,
						character_x,
						character_y,
						text_element.get_length() * Settings.get_default().character_width,
						Settings.get_default().character_height,
						text_element.text,
						text_element.attributes.text_menu);
			}
		}

		return false;
	}

	public signal void text_menu_element_hovered(LineView line_view, int x, int y, int width, int height,
			string text, TextMenu text_menu);

	public void render_line() {
		Metrics.start_block_timer(Log.METHOD);

		// Create a local copy of the output line object so that
		// manipulations for display purposes do not affect the model
		output_line = new TerminalOutput.OutputLine.copy(original_output_line);
		output_line.generate_text_menu_elements();

		is_collapsible_start = output_line.is_prompt_line;
		is_collapsible_end   = output_line.is_prompt_line;

		collapse_button.visible = is_collapsible_start;

		// If the collapse button is visible, the text container will
		// already be pushed to the left, so we need to subtract that
		text_container.margin_left = Settings.get_default().theme.margin_left +
				(is_collapsible_start ?
				 Settings.get_default().theme.gutter_size -
				 	Settings.get_default().theme.collapse_button_width -
				 	Settings.get_default().theme.collapse_button_x :
				 Settings.get_default().theme.gutter_size);

		text_container.set_markup(get_markup(output_line));

		Metrics.stop_block_timer(Log.METHOD);
	}

	private string get_markup(TerminalOutput.OutputLine output_line) {
		var markup_builder = new StringBuilder();

		foreach (var text_element in output_line) {
			var text_attributes = text_element.attributes.get_text_attributes(
					Settings.get_default().color_scheme, Settings.get_default().dark);
			var markup_attributes = text_attributes.get_markup_attributes(
					Settings.get_default().color_scheme, Settings.get_default().dark);

			if (markup_attributes.length > 0) {
				markup_builder.append(
						"<span" + markup_attributes + ">" +
						Markup.escape_text(text_element.text) +
						"</span>");
			} else {
				markup_builder.append(Markup.escape_text(text_element.text));
			}
		}

		return markup_builder.str;
	}

	private void on_settings_changed(string? key) {
		text_container.color = Settings.get_default().foreground_color;

		collapse_button.style = Settings.get_default().theme.style;

		collapse_button.margin_left = Settings.get_default().theme.collapse_button_x;
		collapse_button.margin_top = Settings.get_default().theme.collapse_button_y;
		collapse_button.width = Settings.get_default().theme.collapse_button_width;
		collapse_button.height = Settings.get_default().theme.collapse_button_height;

		text_container.margin_right = Settings.get_default().theme.margin_right;

		// TODO: Clutter bug? The following sometimes does not work:
		//text_container.font_description = Settings.get_default().terminal_font;
		text_container.font_name = Settings.get_default().terminal_font_name;

		render_line();
	}

}
