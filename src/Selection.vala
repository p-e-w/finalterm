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

public class Selection {
	private TerminalOutput.CursorPosition start;
	private TerminalOutput.CursorPosition finish;

	public enum SelectionMode {
		NORMAL,
		WORD,
		LINE,
		COLUMN // Does not work
	}

	public SelectionMode mode {get; set;}
	
	public Selection(TerminalOutput.CursorPosition position, SelectionMode mode) {
		start = position;
		this.mode = mode;
		if(this.mode == SelectionMode.LINE) {
			start.column = 0;
			finish = start;
			finish.column = 1;
		}
	}

	public void update(TerminalOutput.CursorPosition position) {
		finish = position;
	}

	public void get_line_range(int line, out int from, out int to) {
		TerminalOutput.CursorPosition beginning = TerminalOutput.CursorPosition();
		TerminalOutput.CursorPosition end = TerminalOutput.CursorPosition();

		get_range(out beginning, out end);

		from = to = 0;

		if (mode == SelectionMode.COLUMN) {
			if (line >= beginning.line && line <= end.line) {
				from = int.min(beginning.column, end.column);
				to = int.max(beginning.column, end.column);
			} 
		} else if (mode == SelectionMode.WORD) {
			if (line == beginning.line) {
				from = beginning.column;
			} 
			if (line >= beginning.line && line < end.line) {
				to = -1;
			} else if (line == end.line) {
				to = end.column;
			} 
		} else if (mode == SelectionMode.LINE) {
			if (line >= beginning.line && line <= end.line) {
				from = 0;
				to = -1;
			}
		} else  {
			if (line == beginning.line) {
				from = beginning.column;
			} 
			if (line >= beginning.line && line < end.line) {
				to = -1;
			} else if (line == end.line) {
				to = end.column;
			} 
		}
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