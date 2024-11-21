#!/bin/bash

if [ "$#" -ne 2 ]; then
	echo "You have to specify 2 parameters"
	exit 1
fi

fileX=$1
stringX=$2

mkdir -p "$(dirname "$fileX")"

echo "$stringX" > "$fileX"

if [ $? -ne 0 ]; then
	echo "File $fileX is not created"
	exit 1
fi
