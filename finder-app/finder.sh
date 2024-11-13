#!/bin/bash

if [ "$#" -ne 2 ]; then
	echo "You have to specify 2 parameters"
	exit 1
fi

filesDir=$1
searchStr=$2


if [ ! -d "$filesDir" ]; then
	echo "The directory doesn't exist"
	exit 1
fi

files_count=$(find "$filesDir" -type f | wc -l)

found_lines_count=$(grep -r "$searchStr" "$filesDir" | wc -l)

echo "The number of files are $files_count and the number of matching lines are $found_lines_count"
