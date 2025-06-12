#!/bin/bash
# Linux File Utilities

# show largest directories
sudo du -a / 2>/dev/null | sort -n -r | head -n 20

# split a file every 15,000 lines
split -l 15000 --additional-suffix=.extension input_filename output_filename

# split a file using a regex pattern
csplit --digits=2 --quiet --prefix=prefix input_filename "regex" "{*}"
