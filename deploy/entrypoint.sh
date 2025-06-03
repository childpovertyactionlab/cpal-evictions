#!/usr/bin/env bash
scriptdir="/app/scripts"

if [ -z "$1" ]; then
	echo "Available scripts"
	echo "-----------------"
	find "${scriptdir}" -maxdepth 1 -type f -name "*.R" \
		-not -name "init.R" \
		-printf "%P\n"
	exit
elif [ ! -f "${scriptdir}/$1" ]; then
	>&2 echo "ERR: Unknown script: $1"
	exit 1
fi
script="$1"
shift

Rscript "${scriptdir}/${script}" "$@"
