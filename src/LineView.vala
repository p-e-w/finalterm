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

public class LineView : Clutter.Actor {

	private TerminalOutput.OutputLine original_output_line;
	private TerminalOutput.OutputLine output_line;
	
	private LineContainer line_container;

	private Mx.Button collapse_button = null;
	private Clutter.Text text_container;

	private struct LineSelection {
		int start;
		int end;
	}

	private LineSelection selection;
	
	public bool is_prompt_line { get {return original_output_line.is_prompt_line;}}

	public LineView(TerminalOutput.OutputLine output_line, LineContainer line_container) {
		layout_manager = new Clutter.BoxLayout();

		original_output_line = output_line;
		this.line_container = line_container;

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

		selection = LineSelection();
	}

	public void get_character_coordinates(int character_index, out int x, out int y) {
		float character_x;
		float character_y;
		text_container.position_to_coords(character_index, out character_x, out character_y);

		// NOTE: Because this function is called in every rendering cycle,
		//       it is highly performance critical.
		//       Theoretically, only text_container.get_allocation_box()
		//       is guaranteed to return an up-to-date result here; however,
		//       get_allocation_box forces a relayout (see Clutter source code)
		//       and is thus extremely slow, while text_container.allocation
		//       appears to behave identically for this case.
		x = (int)(character_x + text_container.allocation.get_x());
		y = (int)(character_y + text_container.allocation.get_y());
	}

	public int get_coordinates_character(float x, float y) {
		// TODO: coords_to_position seems to be buggy when working with non-latin characters
		// return text_container.coords_to_position(x - text_container.get_x(), y - text_container.get_y());
		int byte_index;
		int trailing;

		float text_container_x;
		float text_container_y;
		text_container.get_transformed_position(out text_container_x, out text_container_y);

		text_container.get_layout().xy_to_index(
				(int)(x - text_container_x) * Pango.SCALE,
				(int)(y - text_container_y) * Pango.SCALE,
				out byte_index, out trailing);

		return Utilities.byte_index_to_character_index(output_line.get_text(), byte_index) + 1;
	}

	public void set_selection(int start, int end, Selection.SelectionMode mode) {
		selection.start = start;
		selection.end = end;

		if (mode == Selection.SelectionMode.WORD &&
			(selection.start != 0 || selection.end != 0)) {
			string text = output_line.get_text();
			
			while (selection.start > 0 &&
				!" \t\n\r-:\'\"".contains(text.substring(selection.start-1, 1))) {
				selection.start--;
			}
			while (selection.end < text.char_count() &&
				selection.end > 0 &&
				!" \t\n\r-:\'\"".contains(text.substring(selection.end, 1))) {
				selection.end++;
			}
		}
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

	public void render_line() {
		output_line = original_output_line.generate_text_menu_elements();

		if (is_prompt_line && collapse_button == null) {
			// Collapse button has not been created yet
			collapse_button = new Mx.Button.with_label("●");

			collapse_button.style_class = "collapse-button";
			collapse_button.clicked.connect(on_collapse_button_clicked);

			update_collapse_button();

			// BoxLayout will arrange the LineView's children
			// from left to right in their natural order, so the
			// collapse button has to be inserted before the
			// text container to be placed on the left
			insert_child_at_index(collapse_button, 0);

		} else if (collapse_button != null) {
			collapse_button.visible = is_prompt_line;
			if (is_collapsible()) {
				collapse_button.is_toggle = true;
				if (collapse_button.toggled) {
					collapse_button.set_label("▶");
				} else {
					collapse_button.set_label("▼");
				}
			}
		}

		if (is_prompt_line) {
			if (output_line.return_code == 0) {
				collapse_button.style_pseudo_class_remove("error");
				collapse_button.tooltip_text = null;
			} else {
				collapse_button.style_pseudo_class_add("error");
				collapse_button.tooltip_text = _("Return code") + ": " + output_line.return_code.to_string();
			}
		}

		// If the collapse button is visible, the text container will
		// already be pushed to the left, so we need to subtract that
		text_container.margin_left = Settings.get_default().theme.margin_left +
				(is_prompt_line ?
				 Settings.get_default().theme.gutter_size -
				 	Settings.get_default().theme.collapse_button_width -
				 	Settings.get_default().theme.collapse_button_x :
				 Settings.get_default().theme.gutter_size);

		text_container.set_markup(get_markup(output_line));
	}

	public string get_selected_text() {
		int element_offset = 0;
		int len = 0;
		int offset = 0;
		string text = "";
		foreach (var text_element in output_line) {
			// TODO: make this block of code less ugly
			len = offset = 0;
			if ((selection.end >= element_offset || selection.end == -1)&& 
				selection.start < element_offset + text_element.text.char_count()) {
				offset = int.max(selection.start - element_offset, 0);
				if (selection.end == -1 ||
					selection.end > element_offset + text_element.text.char_count()) {
					len = text_element.text.char_count() - offset;					
				} else 
					len = selection.end - offset - element_offset;
			}

			var offset_index = text_element.text.index_of_nth_char(offset);
			var len_index = text_element.text.index_of_nth_char(offset + len);

			text += text_element.text.substring(offset_index, len_index - offset_index);

			element_offset += text_element.text.char_count();
		}

		return text;
	}

	private void update_collapse_button() {
		collapse_button.style = Settings.get_default().theme.style;

		collapse_button.margin_left = Settings.get_default().theme.collapse_button_x;
		collapse_button.margin_top = Settings.get_default().theme.collapse_button_y;
		collapse_button.width = Settings.get_default().theme.collapse_button_width;
		collapse_button.height = Settings.get_default().theme.collapse_button_height;
	}

	private string get_markup(TerminalOutput.OutputLine output_line) {
		var markup_builder = new StringBuilder();

		int element_offset = 0;
		int len = 0;
		int offset = 0;

		foreach (var text_element in output_line) {
			// TODO: make this block of code less ugly
			len = offset = 0;
			if ((selection.end >= element_offset || selection.end == -1)&& 
				selection.start < element_offset + text_element.text.char_count()) {
				offset = int.max(selection.start - element_offset, 0);
				if (selection.end == -1 ||
					selection.end > element_offset + text_element.text.char_count()) {
					len = text_element.text.char_count() - offset;
				} else {
					len = selection.end - offset - element_offset;
				}
			}

			var offset_index = text_element.text.index_of_nth_char(offset);
			var len_index = text_element.text.index_of_nth_char(offset + len);

			var text_attributes = text_element.attributes.get_text_attributes(
					Settings.get_default().color_scheme, Settings.get_default().dark);
			var markup_attributes = text_attributes.get_markup_attributes(
					Settings.get_default().color_scheme, Settings.get_default().dark);

			var pre_selection_text = Markup.escape_text(text_element.text.substring(0, offset_index));
			var selection_text = Markup.escape_text(text_element.text.substring(offset_index, len_index - offset_index));
			var post_selection_text = Markup.escape_text(text_element.text.substring(len_index));
			
			// TODO: make selection stylable
			if (markup_attributes.length > 0) {
				markup_builder.append(
						"<span" + markup_attributes + ">" +
						pre_selection_text +
						"</span>" +
						"<span background='#ffffff' foreground='#000000'>" +
						selection_text +
						"</span>" +
						"<span" + markup_attributes + ">" +
						post_selection_text +
						"</span>"
						);
			} else {
				markup_builder.append(
						pre_selection_text +
						"<span background='#ffffff' foreground='#000000'>" +
						selection_text +
						"</span>" +
						post_selection_text
						);

			}
			element_offset += text_element.text.char_count();
		}

		return markup_builder.str;
	}

	private void on_settings_changed(string? key) {
		if (collapse_button != null)
			update_collapse_button();

		text_container.margin_right = Settings.get_default().theme.margin_right;

		text_container.color = Settings.get_default().foreground_color;

		// TODO: Clutter bug? The following sometimes does not work:
		//text_container.font_description = Settings.get_default().terminal_font;
		text_container.font_name = Settings.get_default().terminal_font_name;

		render_line();
	}

	private void on_collapse_button_clicked() {
		if (is_collapsible()) {
			if (collapse_button.toggled) {
				collapse_button.set_label("▶");
				collapsed(this);
			} else {
				collapse_button.set_label("▼");
				expanded(this);
			}
		}
	}

	private bool is_collapsible() {
		if (!is_prompt_line)
			return false;
		int index = line_container.get_line_view_index(this) + 1;
		if (index >= line_container.get_line_count()) {
			return false;
		} else {
			return (!line_container.get_line_view(index).is_prompt_line);
		}
	}

	public signal void text_menu_element_hovered(LineView line_view, int x, int y, int width, int height,
			string text, TextMenu text_menu);

	public signal void collapsed(LineView line_view);

	public signal void expanded(LineView line_view);

}
