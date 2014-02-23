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

// TODO: Make this a namespace?
public class Metrics : Object {

	private class BlockMetrics : Object {
		public int start_timer_count { get; set; default = 0; }
		public int stop_timer_count { get; set; default = 0; }
		// TODO: Vala bug? Auto getters and setters don't compile
		public Timer timer = new Timer();
	}

	private static Gee.Map<string, BlockMetrics> block_metrics_by_block;

	public static void initialize() {
		block_metrics_by_block = new Gee.HashMap<string, BlockMetrics>();
	}

	public static void start_block_timer(string block_name) {
		if (block_metrics_by_block.has_key(block_name)) {
			var block_metrics = block_metrics_by_block.get(block_name);

			if (block_metrics.stop_timer_count == 0) {
				critical(_("Attempting to restart a timer that has not been stopped"));
				return;
			}

			block_metrics.start_timer_count++;
			block_metrics.timer.continue();

		} else {
			var block_metrics = new BlockMetrics();
			block_metrics_by_block.set(block_name, block_metrics);
			block_metrics.start_timer_count++;
			block_metrics.timer.start();
		}
	}

	public static void stop_block_timer(string block_name) {
		if (!block_metrics_by_block.has_key(block_name)) {
			critical(_("Attempting to stop a timer that does not exist"));
			return;
		}

		var block_metrics = block_metrics_by_block.get(block_name);

		if (block_metrics.stop_timer_count >= block_metrics.start_timer_count) {
			critical(_("Attempting to stop a timer that has not been started"));
			return;
		}

		block_metrics.timer.stop();
		block_metrics.stop_timer_count++;
	}

	public static void print_block_statistics() {
		var message_builder = new StringBuilder();
		message_builder.append(_("\nBLOCK STATISTICS:"));

		int maximum_length = 0;
		foreach (var block_name in block_metrics_by_block.keys) {
			maximum_length = int.max(maximum_length, block_name.char_count());
		}

		double grand_total_time = 0.0;

		foreach (var entry in block_metrics_by_block.entries) {
			double total_time = entry.value.timer.elapsed();
			double mean_time  = total_time / (double)entry.value.stop_timer_count;
			grand_total_time += total_time;

			message_builder.append("\n");
			
			message_builder.append(entry.key);
			// Pad block name to align metrics for better readability
			message_builder.append(string.nfill(maximum_length - entry.key.char_count(), ' '));

			message_builder.append_printf(_("\tTotal time: %f"), total_time);
			message_builder.append_printf(_(",\tMean time: %f"), mean_time);
			message_builder.append_printf(_(",\tCycles: %i"), entry.value.stop_timer_count);

			if (entry.value.stop_timer_count < entry.value.start_timer_count)
				message_builder.append(_(" [RUNNING]"));
		}

		message_builder.append_printf(_("\nGrand total time: %f"), grand_total_time);

		message(message_builder.str);
	}

}
