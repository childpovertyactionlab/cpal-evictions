#!/usr/bin/env bash
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

source images.shconf

tag_default='lastbuilt'

usage() {
	echo "Run images, performing tests to confirm build success."
	echo
	echo "Usage: $(basename $0) [subsystem] [tag]"
	echo
	echo "Arguments:"
	echo "  subsystem: [${image_subsystems// /|}] Or '-' to build all."
	echo "  tag:       [${tag_default}] The tag to expect and run."
	echo
	usage_images_conf
}

subsystem=''
tag=''
while [ $# -gt 0 ]; do
	case "$1" in
	-h|--help )
		usage
		exit
	;;
	*)
		if [ -z "${subsystem}" ]; then
			if image_subsystem_valid "$1"; then
				subsystem="$1"
			else
				echo "ERR: Invalid subsystem specified."
				exit 2
			fi
		else
			if [ -z "${tag}" ]; then
				tag="$1"
			fi
		fi
	;;
	esac
	shift
done

subsystem="${subsystem//-/}"
tag="${tag:-${tag_default}}"

test_failure() {
	echo "FAILURE: $1"
	echo "Output"
	echo "------"
	echo "$2"
	echo "------"
}

for subsys in ${subsystem:-${image_subsystems}}; do
	image_id=$(image_list_id "${subsys}" "${tag}" | tr -d '\n')

	echo "# Testing $(image_fq "${subsys}" "${tag}") [${image_id:-?}]"

	if [ -z "${image_id}" ]; then
		echo "Skipped, image not found."
		continue
	fi

	case "${subsys}" in
		acquisition|distribution)

			printf "=> Checking for existince of shell scripts..."
			out=$(${DOCKER_CMD} run --rm "${image_id}" -c ls 2>/dev/null)
			scripts=$(echo -e "${out}" | grep '.sh$' | wc -l)
			if [ ${scripts} -eq 0 ]; then
				test_failure "Failed to find any shell scripts!" "${out}"
				exit 11
			else
				echo "LGTM"
			fi

		;;
		analysis)

			printf "=> Checking for existince of R scripts..."
			out=$(${DOCKER_CMD} run --rm "${image_id}" 2>/dev/null)
			scripts=$(echo -e "${out}" | grep '.R$' | wc -l)
			if [ ${scripts} -eq 0 ]; then
				test_failure "Failed to find any R scripts!" "${out}"
				exit 11
			else
				echo "LGTM"
			fi

			printf "=> Checking R runtime..."
			out=$(${DOCKER_CMD} run --rm --entrypoint Rscript "${image_id}" -e 'version' 2>/dev/null)
			rver=$(echo "${out}" | awk '/version.string/{print substr($0,index($0,$2))}')
			if [ -z "${rver}" ]; then
				test_failure "R runtime might be corrupt!" "${out}"
				exit 11
			else
				echo "LGTM"
			fi

		;;
	esac
done
