#!/usr/bin/env bash
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

source images.shconf

tag_default='lastbuilt'
format_default='human'

usage() {
	echo "Show images related to this project filtered by subsystem and/or tag."
	echo
	echo "Usage: $(basename $0) [format] [subsystem] [tag]"
	echo
	echo "Arguments:"
	echo "  format    [${format_default}] What to display."
	echo "  tag       [${tag_default}] Or '-' to list all."
	echo "  subsystem [${image_subsystems// /|}] Or '-' to list all."
	echo
	echo "<format>"
	echo "  human : Normal Docker image listing per project image."
	echo "  id    : Output only image ID."
	echo "  path  : Output image repo/path."
	echo "  tag   : Output fully qualified image repo/path:tag."
	echo
	usage_images_conf
}

subsystem=''
tag=''
out_format=''
while [ $# -gt 0 ]; do
	case "$1" in
	-h|--help )
		usage
		exit
	;;
	*)
		if [ -z "${out_format}" ]; then
			out_format="$1"
		elif [ -z "${tag}" ]; then
			tag="$1"
		elif [ -z "${subsystem}" ]; then
			if image_subsystem_valid "$1"; then
				subsystem="$1"
			else
				echo "ERR: Invalid subsystem specified."
				exit 2
			fi
		fi
	;;
	esac
	shift
done
out_format="${out_format:-${format_default}}"
subsystem="${subsystem//-/}"
tag="${tag:-${tag_default}}"
if [ "${tag}" == '-' ]; then
	tag=''
fi

for subsys in ${subsystem:-${image_subsystems}}; do

	case ${out_format} in
		path)
			$(image_list_cmd "${subsys}" "${tag}") --format "{{.Repository}}"
		;;
		tag)
			$(image_list_cmd "${subsys}" "${tag}") --format "{{.Repository}}:{{.Tag}}"
		;;
		id)
			$(image_list_cmd "${subsys}" "${tag}") -q | uniq
		;;
		*)
			echo "# $(image_fq ${subsys} ${tag})"
			image_list "${subsys}" "${tag}"
		;;
	esac

done
