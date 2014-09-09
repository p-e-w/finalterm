#!/bin/bash

ls_output=$(ls "$@")
dir_begin_mark=$(text_menu_start '2')
dir_end_mark=$(text_menu_end '2')
file_begin_mark=$(text_menu_start '1')
file_end_mark=$(text_menu_end '1')

# Surround with additional newlines to facilitate matching (see below)
ls_output=$'\n'$ls_output$'\n'

# TODO: Search for files in directory passed to ls rather than the current directory
shopt -s nullglob dotglob
for filename in *; do
	if [[ -d $filename ]]; then
		file_substitution="$dir_begin_mark$filename$dir_end_mark"
	else
		file_substitution="$file_begin_mark$filename$file_end_mark"
	fi

	# Short format ("ls"; each filename on a single line)
	ls_output=${ls_output/$'\n'$filename$'\n'/$'\n'$file_substitution$'\n'}
	# Long format ("ls -l")
	ls_output=${ls_output/ $filename$'\n'/ $file_substitution$'\n'}
	# Long format; symlinks
	ls_output=${ls_output/ $filename ->/ $file_substitution ->}
done

# Strip leading newline
ls_output=${ls_output#$'\n'}
# Strip trailing newline
ls_output=${ls_output%$'\n'}

echo -e "$ls_output"
