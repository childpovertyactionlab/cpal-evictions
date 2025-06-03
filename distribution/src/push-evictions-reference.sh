#!/usr/bin/env bash
# Push eviction files to a location that can be shared externally.
# Most configuration is located in the project YAML configuration file, see usage.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ENV="${ENV:-development}"
export TZ='America/Chicago'

usage() {
	echo "Push eviction files to a S3 bucket that can be shared externally."
	echo "Uses the configuration provided within the 'shares.evictions-reference"
	echo "stanza."
	echo
	echo "Usage: $(basename $0) [path/to/config] [--pretend] [--list]"
	echo
	echo "Arguments:"
	echo "  config: [config.yml] file path to YAML configuration."
	echo
	echo "Options:"
	echo "  --pretend: Make no changes, but test the connection and operation."
	echo "  --list   : Only list remote files."
	echo
	echo "Environment (required):"
	echo "  AWS_PROFILE           : Use default location AWS credentials profile."
	echo "                          If used, KEY_ID and SECRET aren't used/required."
	echo "  AWS_ACCESS_KEY_ID"
	echo "  AWS_SECRET_ACCESS_KEY"
	echo
	echo "Requires rclone v1.69.2+"
}

if ! which rclone > /dev/null; then
	echo "ERR: rclone not in PATH"
	exit 2
fi

action='copy'
dry_run=''
while [ $# -gt 0 ]; do
	case "$1" in
	--pretend )
		dry_run='--dry-run'
		;;
	--list )
		action='list'
		;;
	-h|--help )
		usage
		exit
		;;
	*)
		if [ -z "${config}" ]; then
			config="$1"
		fi
		;;
	esac
	shift
done

if [ "${ENV}" == 'development' ]; then
	config="${config:-config.yml}"
fi

if [ -z "${config}" ] || [ ! -f "${config}" ]; then
	echo "ERR: configuration not specified or not found."
	exit 1
fi

# poor man's YAML configuration loader
eval $(awk -F ':' '
function filters_done() {
  if (filters != "") { print "export config_FILTERS=""\""filters"\"" }
  filters=""
}
$1=="  shares"{cap=1}
cap>=1{match($1,"^[ ]+"); indent=RLENGTH; gsub(/^[ \t]+|[ \t]+$/,"",$1); gsub(/^[ \t]+|[ \t]+$/,"", $2)}
cap>1 && eos==indent {exit}
$1=="evictions-reference" && cap==1{cap=2; eos=indent;}
cap==3 && $1!~"^--"{cap=2; filters_done()}
$1=="source" && cap==2{print "export config_SRC=\""substr($0,index($0,$2))"\""}
$1=="bucket_name" && cap==2{print "export config_DEST_BUCKET="$2}
$1=="bucket_path" && cap==2{print "export config_DEST_PATH="$2}
$1=="aws_region" && cap==2{print "export config_REGION="$2}
$1=="filters" && cap==2{cap=3; filters=""}
cap==3 && $1~"^--"{filters=filters" "substr($0,index($0,$1));}
END { if (cap==3) { filters_done(); } }
' ${config}
)

destination="${config_DEST_BUCKET}/${config_DEST_PATH##/}"

# litmus test for sane configuration
if [ "${destination}" == '/' ] || [ -z "${config_REGION}" ]; then
	echo "ERR: missing desintation and/or region, likely misconfiguration or ENV."
	exit 1
fi

if [ -z "${AWS_PROFILE}" ] && [ -z "${AWS_ACCESS_KEY_ID}" ]; then
	echo "ERR: missing AWS credentials."
	exit 1
fi

echo "Pushing DCAD eviction files @ $(date) to s3://[${config_REGION}]${destination}"

rclone_spec=":s3,provider=AWS,env_auth,region=${config_REGION}:${destination}"

if [ "${action}" == 'copy' ]; then

	rclone --config '' ${dry_run} copy \
		--update \
		--use-server-modtime \
		--no-traverse \
		-v \
		${config_FILTERS} \
		"${config_SRC}" \
		"${rclone_spec}"

elif [ "${action}" == 'list' ]; then
	rclone --config '' ${dry_run} lsf \
		"${rclone_spec}"
fi
