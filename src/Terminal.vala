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

// TODO: Rename to "TerminalController"?
public class Terminal : Object {

	public int lines { get; set; }
	public int columns { get; set; }

	public TerminalStream terminal_stream { get; set; default = new TerminalStream(); }
	public TerminalOutput terminal_output { get; set; }
	public TerminalView terminal_view { get; set; }

	private int command_file;
	private IOChannel command_channel;

	// Store class instances indexed by the shell process' PID
	// – an ugly necessity because of Vala's closure limitations
	private static Gee.Map<int, Terminal> terminals_by_pid = new Gee.HashMap<int, Terminal>();

	public Terminal() {
		lines = Settings.get_default().terminal_lines;
		columns = Settings.get_default().terminal_columns;

		terminal_stream.element_added.connect(on_stream_element_added);
		terminal_stream.transient_text_updated.connect(on_stream_transient_text_updated);

		terminal_output = new TerminalOutput(this);
		terminal_output.line_added.connect(on_output_line_added);
		terminal_output.text_updated.connect(on_output_text_updated);
		terminal_output.command_updated.connect(on_output_command_updated);
		terminal_output.command_executed.connect(on_output_command_executed);
#if HAS_NOTIFY
		terminal_output.command_finished.connect(on_output_command_finished);
#endif
		terminal_output.title_updated.connect(on_output_title_updated);
		terminal_output.progress_updated.connect(on_output_progress_updated);
		terminal_output.progress_finished.connect(on_output_progress_finished);
		terminal_output.cursor_position_changed.connect(on_output_cursor_position_changed);

		initialize_pty();

		on_settings_changed(null);
		Settings.get_default().changed.connect(on_settings_changed);
	}

	public bool is_autocompletion_active() {
		return terminal_output.command_mode && FinalTerm.autocompletion.is_popup_visible();
	}

	public void update_autocompletion_position() {
		int x;
		int y;
		terminal_view.terminal_output_view.get_screen_position(
				terminal_output.command_start_position, out x, out y);
		// Move popup one character down so it doesn't occlude the input
		y += Settings.get_default().character_height;
		FinalTerm.autocompletion.move_popup(x, y);
	}

	public void clear_command() {
		// TODO: Handle cases where cursor is not at the end of the line
		for (int i = 0; i < terminal_output.get_command().char_count(); i++) {
			// Delete last character (backspace)
			send_text("\x7F");
		}
	}

	public void set_command(string command) {
		clear_command();
		send_text(command);
	}

	public void run_command(string command) {
		set_command(command);
		send_text("\n");
	}

	private void on_stream_element_added(TerminalStream.StreamElement stream_element) {
		terminal_output.parse_stream_element(stream_element);
	}

	private void on_stream_transient_text_updated(string transient_text) {
		terminal_output.parse_transient_text(transient_text);
	}

	private void on_output_line_added() {
		terminal_view.terminal_output_view.add_line_views();

		// Schedule autoscroll with low priority to ensure it is performed
		// only after all layout changes triggered by adding the new line
		// are complete
		// TODO: Add information about instance to key
		Utilities.schedule_execution(() => {
			terminal_view.terminal_output_view.scroll_to_position();
		}, "scroll_to_position", 0, Priority.DEFAULT_IDLE);
	}

	private void on_output_text_updated(int line_index) {
		terminal_view.terminal_output_view.mark_line_as_updated(line_index);

		// TODO: Add information about instance to key
		Utilities.schedule_execution(terminal_view.terminal_output_view.render_terminal_output,
				"render_terminal_output", Settings.get_default().render_interval);
	}

	private void on_output_command_updated(string command) {
		message(_("Command updated: '%s'"), command);

		// TODO: This should be scheduled to avoid congestion
		FinalTerm.autocompletion.show_popup(command);
		update_autocompletion_position();
	}

	private void on_output_command_executed(string command) {
		message(_("Command executed: '%s'"), command);
		FinalTerm.autocompletion.hide_popup();
		FinalTerm.autocompletion.add_command(command.strip());
	}

	private void on_output_title_updated(string new_title) {
		title_updated(new_title);
	}

	private void on_output_progress_updated(int percentage, string operation) {
#if HAS_UNITY
		FinalTerm.launcher.progress_visible = true;
		FinalTerm.launcher.progress = percentage / 100.0;
#endif

		terminal_view.show_progress(percentage, operation);
	}

	private void on_output_progress_finished() {
#if HAS_UNITY
		FinalTerm.launcher.progress_visible = false;
#endif

		terminal_view.hide_progress();
	}

#if HAS_NOTIFY
	private void on_output_command_finished(string command) {
		if (terminal_view.window_has_focus())
			return;

		var notification = new Notify.Notification(_("Command finished"), command, "final-term");
		try {
			notification.show();
		} catch (Error e) { warning(_("Failed to show notification: %s"), e.message); }
	}
#endif

	private void on_output_cursor_position_changed(TerminalOutput.CursorPosition new_position) {
		// TODO: Add information about instance to key
		Utilities.schedule_execution(terminal_view.terminal_output_view.render_terminal_output,
				"render_terminal_output", Settings.get_default().render_interval);
	}

	public void send_text(string text) {
		size_t bytes_written;
		try {
			command_channel.write_chars((char[])text.data, out bytes_written);
			command_channel.flush();
		} catch (Error e) { warning(_("Sending text failed: %s"), e.message); }
	}

	// Makes the PTY aware that the size (lines and columns)
	// of the terminal has been changed
	public void update_size() {
		Linux.winsize terminal_size = { (ushort)lines, (ushort)columns, 0, 0 };
		Linux.ioctl(command_file, Linux.Termios.TIOCSWINSZ, terminal_size);
	}

	private void initialize_pty() {
		int pty_master;
		char[] slave_name = null;
		Linux.winsize terminal_size = { (ushort)lines, (ushort)columns, 0, 0 };

		var fork_pid = Linux.forkpty(out pty_master, slave_name, null, terminal_size);

		switch (fork_pid) {
		case -1: // Error
			critical(_("Fork failed"));
			break;

		case 0: // This is the child process
			run_shell();
			break;

		default: // This is the parent process
			command_file = pty_master;
			initialize_read();

			// Store instance reference to be retrieved from inside the closure
			terminals_by_pid.set((int)fork_pid, this);

			Posix.@signal(Posix.SIGCHLD, (@signal) => {
				// Some child process terminated
				Posix.pid_t child_pid;

				// Do not let the shell process turn defunct
				// Note that multiple child processes might have terminated simultaneously
				// as noted in http://stackoverflow.com/questions/2595503/determine-pid-of-terminated-process
				while ((child_pid = Posix.waitpid(-1, null, Posix.WNOHANG)) != -1) {
					var this_terminal = terminals_by_pid.get((int)child_pid);
					this_terminal.shell_terminated();
				}
			});

			break;
		}
	}

	private void run_shell() {
		Environment.set_variable("TERM", Settings.get_default().emulated_terminal, true);

		string[] arguments = { Settings.get_default().shell_path, "--rcfile",
				Config.PKGDATADIR + "/Startup/bash_startup", "-i" };

		// Add custom shell arguments
		foreach (var argument in Settings.get_default().shell_arguments) {
			arguments += argument;
		}

		// Replace child process with shell process
		Posix.execvp(Settings.get_default().shell_path, arguments);

		// If this line is reached, execvp() must have failed
		critical(_("execvp failed"));
		Posix.exit(Posix.EXIT_FAILURE);
	}

	private void initialize_read() {
		command_channel = new IOChannel.unix_new(command_file);

		command_channel.add_watch(IOCondition.IN, (source, condition) => {
			if (condition == IOCondition.HUP) {
				message(_("Connection broken"));
				return false;
			}

			// TODO: Read all available characters rather than one
			unichar character;
			try {
				command_channel.read_unichar(out character);
			} catch (Error e) { warning(_("Reading unichar failed: %s"), e.message); }

			terminal_stream.parse_character(character);

			return true;
		});
	}

	private void on_settings_changed(string? key) {
		if (is_autocompletion_active())
			update_autocompletion_position();
	}

	// TODO: Rename to "title_changed"?
	public signal void title_updated(string new_title);

	public signal void shell_terminated();

}
