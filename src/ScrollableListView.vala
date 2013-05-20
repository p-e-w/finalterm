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

public class ScrollableListView<T, E> : Clutter.Actor {

	private Mx.ScrollView scroll_view;
	private Mx.ListView list_view;

	private Clutter.Model list_model;

	public ScrollableListView(NotifyingList<T> list, Type item_type, Type item_view_type, string item_property_name) {
		scroll_view = new Mx.ScrollView();
		add(scroll_view);

		/*
		 * The goal here is to work around the fact that the Mx ScrollView "shadow"
		 * cannot be disabled by clipping the ScrollView and compensating for the clipping
		 * using padding (see style.css). However, multiple Mx bugs stand in the way.
		 * Notably, the ScrollView fails to calculate the child widget's height properly
		 * when padding is applied. The "solution" seen here was found by examining the
		 * Mx source code (https://github.com/clutter-project/mx/tree/master/mx)
		 * and currently only works with vertical scrolling.
		 */
		// TODO: The scrollbar's top and bottom ranges lie slightly outside the visible part of the view
		scroll_view.add_constraint(new Clutter.BindConstraint(this, Clutter.BindCoordinate.X, 0));
		scroll_view.add_constraint(new Clutter.BindConstraint(this, Clutter.BindCoordinate.Y, -15));
		scroll_view.add_constraint(new Clutter.BindConstraint(this, Clutter.BindCoordinate.WIDTH, 0));
		scroll_view.add_constraint(new Clutter.BindConstraint(this, Clutter.BindCoordinate.HEIGHT, 45));
		clip_to_allocation = true;

		list_view = new Mx.ListView();
		list_view.factory = new ItemViewFactory<E>(item_view_type);
		list_model = new Clutter.ListModel(1, item_type, null);
		list_view.model = list_model;
		list_view.add_attribute(item_property_name, 0);

		scroll_view.add(list_view);

		// Synchronize model with list
		foreach (var item in list) {
			list_model.append(0, item, -1);
		}
		list.item_inserted.connect((index, item) => {
			list_model.insert(index, 0, item, -1);
		});
		list.item_removed.connect((index, item) => {
			list_model.remove(index);
		});
		list.item_modified.connect((index, item) => {
			// TODO
		});

		on_settings_changed(null);
		Settings.get_default().changed.connect(on_settings_changed);
	}

	// TODO: This does not work (Vala crash):
	//public delegate bool FilterFunction(T item);
	//public delegate int SortFunction(T item_1, T item_2);
	public delegate bool FilterFunction<G>(G item);
	public delegate int SortFunction<G>(G item_1, G item_2);

	public void set_filter_function(FilterFunction<T> filter_function) {
		list_model.set_filter((model, iter) => {
			return filter_function((T)iter.get_value(0).get_object());
		});
	}

	public void set_sort_function(SortFunction<T> sort_function) {
		list_model.set_sort(0, (model, a, b) => {
			return sort_function((T)a.get_object(), (T)b.get_object());
		});
	}

	// Returns the number of items that are actually displayed
	public int get_number_of_items() {
		return (int)list_model.get_n_rows();
	}

	public bool is_valid_item_index(int item_index) {
		return (item_index >= 0 && item_index < get_number_of_items());
	}

	// Returns the item at the specified index,
	// taking into account filtering and sorting
	// (i.e. considering the items as they are displayed)
	public T? get_item(int item_index) {
		if (!is_valid_item_index(item_index))
			return null;

		return (T)list_model.get_iter_at_row(item_index).get_value(0).get_object();
	}

	// TODO: This method should return an object of type E, but Vala
	//       does not support constraints on generic parameters ("E implements ItemView"),
	//       so it is more convenient to return an ItemView here
	private ItemView? get_item_view(int item_index) {
		if (!is_valid_item_index(item_index))
			return null;

		return (ItemView)list_view.get_child_at_index(item_index);
	}

	public void update_item(int item_index) {
		if (!is_valid_item_index(item_index))
			return;

		get_item_view(item_index).update();
	}

	public void scroll_to_item(int item_index) {
		if (!is_valid_item_index(item_index))
			return;

		// NOTE: item.get_geometry() does not work here
		//       because the layout manager takes over positioning
		var geometry = Clutter.Geometry();
		var allocation_box = get_item_view(item_index).get_allocation_box();
		geometry.x      = (int)allocation_box.get_x();
		geometry.y      = (int)allocation_box.get_y();
		geometry.width  = (uint)allocation_box.get_width();
		geometry.height = (uint)allocation_box.get_height();

		scroll_view.ensure_visible(geometry);
	}

	private void on_settings_changed(string? key) {
		scroll_view.style = Settings.get_default().theme.style;
		list_view.style = Settings.get_default().theme.style;
	}


	private class ItemViewFactory<G> : Object, Mx.ItemFactory {

		private Type type;

		public ItemViewFactory(Type type) {
			this.type = type;
		}

		public Clutter.Actor create() {
			var object = Object.new(type);
			if (object is ItemView) {
				((ItemView)object).construct();
			} else {
				critical("Object does not implement the ItemView interface");
			}
			return (Clutter.Actor)object;
		}

	}

}


// TODO: Rename (Mx also provides a class called "ItemView")?
public interface ItemView : Clutter.Actor {

	public abstract void construct();
	public abstract void update();

}
