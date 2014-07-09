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

public class NestingContainer : Gtk.Box, NestingContainerChild {

	// This property is maintained under the contract
	// "is_active = has_active_descendant"
	public bool is_active { get; set; }

	// This property is maintained under the contract
	// "title = title_of_active_descendant"
	public unowned string title { get; set; }

	public Gee.List<NestingContainerChild> children;

	private Gtk.Paned paned;
	private Gtk.Notebook notebook;

	private ContainerState container_state;

	private enum ContainerState {
		// Container contains a single child widget
		CHILD,
		// Container is split into two panes horizontally or vertically,
		// containing one container each
		SPLIT,
		// Container shows multiple tabs, containing one container each
		TABBED
	}

	public delegate NestingContainerChild ChildFactoryFunction();

	private ChildFactoryFunction child_factory_function;

	public NestingContainer(ChildFactoryFunction child_factory_function) {
		this.with_child(child_factory_function, child_factory_function());
	}

	private NestingContainer.with_child(ChildFactoryFunction child_factory_function,
				NestingContainerChild child) {
		this.child_factory_function = child_factory_function;

		children = new Gee.ArrayList<NestingContainerChild>();
		children.add(child);

		if (child.parent == null) {
			add(child);
		} else {
			child.reparent(this);
		}

		container_state = ContainerState.CHILD;

		update_is_active();
		update_title();
		connect_signal_handlers();

		show_all();
	}

	// Transfers the primary child to a new container
	// and splits the view into that container and another one
	private void do_split(Gtk.Orientation orientation) {
		assert(container_state == ContainerState.CHILD);

		var current_child = children.get(0);
		children.clear();

		paned = new Gtk.Paned(orientation);

		var child_container_1 = new NestingContainer.with_child(child_factory_function, current_child);
		children.add(child_container_1);
		paned.pack1(child_container_1, true, true);

		var child_container_2 = new NestingContainer(child_factory_function);
		children.add(child_container_2);
		paned.pack2(child_container_2, true, true);

		// Explicitly set divider position to avoid pane collapsing
		// when a notebook widget is added to the other pane
		Gtk.Allocation allocation;
		get_allocation(out allocation);
		paned.position = (orientation == Gtk.Orientation.HORIZONTAL) ?
				allocation.width / 2 : allocation.height / 2;

		pack_start(paned);

		container_state = ContainerState.SPLIT;

		update_is_active();
		update_title();
		connect_signal_handlers();

		show_all();
	}

	// Transfers the primary child to a new container
	// and tabs the view into that container and another one
	// OR adds a new tab if the container is already tabbed
	private void do_add_tab() {
		if (container_state == ContainerState.CHILD) {
			if (parent is Gtk.Notebook && parent.parent is NestingContainer) {
				// Already inside a tabbed container
				(parent.parent as NestingContainer).do_add_tab();
				return;
			}

			var current_child = children.get(0);
			children.clear();

			notebook = new Gtk.Notebook();
			// Identifier for drag and drop compatibility
			notebook.group_name = "NestingContainer";

			pack_start(notebook);

			container_state = ContainerState.TABBED;

			show_all();

			add_tab_with_child(current_child);
		}

		add_tab_with_child(child_factory_function());
	}

	private void add_tab_with_child(NestingContainerChild child, bool signals = true) {
		assert(container_state == ContainerState.TABBED);

		var child_container = new NestingContainer.with_child(child_factory_function, child);
		children.add(child_container);
		notebook.append_page(child_container, new TabLabel(child_container.title));

		notebook.set_tab_detachable(child_container, true);
		notebook.set_tab_reorderable(child_container, true);
        
        update_is_active();
        update_title();
        connect_signal_handlers();
	}

	// Merges this container and another one into a single container
	// with the properties of the latter
	private void merge(NestingContainer container) {
		assert(container_state != ContainerState.CHILD);

		switch (container.container_state) {
		case ContainerState.CHILD:
			container.children.get(0).reparent(this);
			break;
		case ContainerState.SPLIT:
			container.paned.reparent(this);
			break;
		case ContainerState.TABBED:
			container.notebook.reparent(this);
			break;
		}

		switch (container_state) {
		case ContainerState.SPLIT:
			remove(paned);
			break;
		case ContainerState.TABBED:
			remove(notebook);
			break;
		}

		children = container.children;
		paned = container.paned;
		notebook = container.notebook;
		container_state = container.container_state;

		update_is_active();
		update_title();
		connect_signal_handlers();
	}

	private void activate_child() {
		switch (container_state) {
		case ContainerState.CHILD:
			(children.get(0) as NestingContainerChild).is_active = true;
			return;
		case ContainerState.SPLIT:
			(paned.get_child1() as NestingContainer).activate_child();
			return;
		case ContainerState.TABBED:
			(notebook.get_nth_page(notebook.get_current_page()) as NestingContainer).activate_child();
			return;
		}
	}

	private void update_is_active() {
		foreach (var child in children) {
			if (child.is_active) {
				is_active = true;
				return;
			}
		}

		is_active = false;
	}

	private void update_title() {
		foreach (var child in children) {
			if (child.is_active) {
				title = child.title;
				return;
			}
		}

		title = children.get(0).title;
	}

	private Gee.Map<Object, Gee.Set<ulong>> signal_handlers = new Gee.HashMap<Object, Gee.Set<ulong>>();

	private void connect_signal_handlers() {
        // Disconnect existing handlers
		foreach (var object in signal_handlers.keys) {
			foreach (var signal_handler in signal_handlers.get(object)) {
				object.disconnect(signal_handler);
			}
		}

		signal_handlers.clear();
        
		foreach (var child in children) {
			var child_signal_handlers = new Gee.HashSet<ulong>();

			child_signal_handlers.add(child.notify["is-active"].connect(() => {
				if (child.is_active) {
					// Child has (possibly through a descendant) been activated
					// => activate container
					is_active = true;

					// Deactivate all other children (this action recurses
					// through the signal handler on the container)
					foreach (var current_child in children) {
						if (current_child != child)
							current_child.is_active = false;
					}

					title = child.title;

				} else {
					if (child is NestingContainer) {
						// Deactivate children recursively
						foreach (var child_child in (child as NestingContainer).children)
							child_child.is_active = false;
					}
				}
			}));

			child_signal_handlers.add(child.notify["title"].connect(() => {
				if (container_state == ContainerState.TABBED) {
					var tab_label = notebook.get_tab_label(child) as TabLabel;
					tab_label.set_text(child.title);
				}

				update_title();
			}));

			child_signal_handlers.add(child.split.connect((orientation) => {
				do_split(orientation);
			}));

			child_signal_handlers.add(child.add_tab.connect(() => {
				do_add_tab();
			}));

			child_signal_handlers.add(child.close.connect(() => {
                children.remove(child);
				connect_signal_handlers();

				if (child is NestingContainer) {
					// Close children recursively
					foreach (var child_child in (child as NestingContainer).children) {
						child_child.close();
                    }
				}

				bool was_active = is_active;

				switch (container_state) {
				case ContainerState.CHILD:
					// No pane/tab to close => close the entire container
					remove(child);
					close();
					return;

				case ContainerState.SPLIT:
					// Revert to single-child mode with other child
					if (child == paned.get_child1()) {
						merge(paned.get_child2() as NestingContainer);
					} else if (child == paned.get_child2()) {
						merge(paned.get_child1() as NestingContainer);
					} else {
						assert_not_reached();
					}
					if (was_active && !is_active) {
						activate_child();
                    }
					return;

				case ContainerState.TABBED:
					if (notebook.get_n_pages() == 2) {
						// Revert to single-child mode with other child
						int page_index = 1 - notebook.page_num(child);
						merge(notebook.get_nth_page(page_index) as NestingContainer);
					} else if (notebook.get_n_pages() > 2) {
						// Close tab associated with child
                        notebook.remove_page(notebook.page_num(child));
					} else {
						assert_not_reached();
					}
					if (was_active && !is_active) {
						activate_child();
                    }
					update_title();
					return;
				}
			}));

			if (container_state == ContainerState.TABBED) {
				var tab_label = notebook.get_tab_label(child) as TabLabel;
				var tab_label_signal_handlers = new Gee.HashSet<ulong>();

				tab_label_signal_handlers.add(tab_label.close_button_clicked.connect(() => {
					child.close();
				}));

				signal_handlers.set(tab_label, tab_label_signal_handlers);
			}

			signal_handlers.set(child, child_signal_handlers);
		}

		if (container_state == ContainerState.TABBED) {
			var notebook_signal_handlers = new Gee.HashSet<ulong>();

			notebook_signal_handlers.add(notebook.switch_page.connect((page, page_num) => {
				(page as NestingContainer).activate_child();
				update_title();
			}));

			signal_handlers.set(notebook, notebook_signal_handlers);
		}
	}


	// Blueprint for close button setup taken from
	// http://www.micahcarrick.com/gtk-notebook-tabs-with-close-button.html
	// and https://git.gnome.org/browse/gnome-terminal/tree/src/terminal-close-button.c
	private class TabLabel : Gtk.Box {

		private Gtk.Label label;
		private Gtk.Button close_button;

		public TabLabel(string text) {
			orientation = Gtk.Orientation.HORIZONTAL;
			spacing = 5;

			label = new Gtk.Label(text);
			pack_start(label);

			close_button = new Gtk.Button();
			close_button.relief = Gtk.ReliefStyle.NONE;
			close_button.focus_on_click = false;
			close_button.add(
					new Gtk.Image.from_gicon(
						new ThemedIcon.with_default_fallbacks("window-close-symbolic"),
						Gtk.IconSize.MENU));

			var css_provider = new Gtk.CssProvider();
			css_provider.load_from_data(
					".button {\n" +
					"-GtkButton-default-border: 0px;\n" +
					"-GtkButton-default-outside-border: 0px;\n" +
					"-GtkButton-inner-border: 0px;\n" +
					"-GtkWidget-focus-line-width: 0px;\n" +
					"-GtkWidget-focus-padding: 0px;\n" +
					"padding: 0px;\n" +
					"}", -1);
			close_button.get_style_context().add_provider(css_provider,
					Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

			close_button.clicked.connect(() => {
				close_button_clicked();
			});

			pack_start(close_button, false, false);

			show_all();
		}

		public void set_text(string text) {
			label.label = text;
		}

		public signal void close_button_clicked();

	}

}


public interface NestingContainerChild : Gtk.Widget {

	// The widget can use this property to indicate
	// whether it is in an "active" state or not
	// (interpretation of that state is up to the widget).
	// NestingContainer ensures that at most one
	// of its descendants is active at any given time.
	public abstract bool is_active { get; set; }

	// The widget can use this property to control the text
	// that is used to label the tab containing it
	public abstract string title { get; set; }

	// The widget can use this signal to be split
	// into two widgets of the same type
	public signal void split(Gtk.Orientation orientation);

	// The widget can use this signal to add a tab
	// containing a widget of the same type
	public signal void add_tab();

	// The widget can use this signal to remove itself
	// from the container. It will also be emitted
	// when the user clicks the close button of a tab
	// that contains the widget.
	public signal void close();

}
