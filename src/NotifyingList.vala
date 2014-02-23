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

// Drop-in replacement for ArrayList that provides notifications
// for events affecting the list's contents

// TODO: Only send signals if operations succeed
// TODO: Make this thread-safe
public class NotifyingList<T> : Gee.ArrayList<T> {

	public override void set(int index, T item) {
		T old_item = get(index);
		base.set(index, item);
		item_removed(index, old_item);
		item_inserted(index, item);
	}

	public override bool add(T item) {
		var result = base.add(item);
		item_inserted(size - 1, item);
		return result;
	}

	public override void insert(int index, T item) {
		base.insert(index, item);
		item_inserted(index, item);
	}

	public override bool remove(T item) {
		var index = index_of(item);
		var result = base.remove(item);
		item_removed(index, item);
		return result;
	}

	public override T remove_at(int index) {
		var item = base.remove_at(index);
		item_removed(index, item);
		return item;
	}

	public override void clear() {
		var items = new Gee.ArrayList<T>();
		items.add_all(this);

		base.clear();

		// Send remove signals in an order that allows
		// a secondary list to be synchronized with this one
		for (int i = items.size - 1; i >= 0; i--) {
			item_removed(i, items[i]);
		}
	}

	// TODO: "new" keyword required to suppress warning about method hiding,
	//       but "override" is not allowed here
	public new bool add_all(Gee.Collection<T> collection) {
		var original_size = size;

		var result = base.add_all(collection);

		int i = 0;
		foreach (var item in collection) {
			item_inserted(original_size + i, item);
			i++;
		}

		return result;
	}

	public signal void item_inserted(int index, T item);

	public signal void item_removed(int index, T item);

	// This method is intended to be called by subclasses
	// since there is no way for this class to know when
	// an item's internal state changes
	public signal void item_modified(int index, T item);

}
