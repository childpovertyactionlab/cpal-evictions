#!/usr/bin/env bash
# Synchronize data from the DCAD SFTP server to a local directory.
# Most configuration is located in the project YAML configuration file, see usage.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ENV="${ENV:-development}"
export TZ='America/Chicago'

usage() {
	echo "Synchronize a remote directory to a local path using SFTP."
	echo "Usage: $(basename $0) [path/to/config] [--pretend] [--list]"
	echo
	echo "Arguments:"
	echo "  config: [config.yml] file path to YAML configuration."
	echo
	echo "Options:"
	echo "  --pretend: Make no changes, but test the connection and operation."
	echo "  --list   : Only list remove files that would be seen by the sync"
	echo "             operation."
	echo
	echo "Requires rclone v1.69.2+"
}

if ! which rclone > /dev/null; then
	echo "ERR: rclone not in PATH"
	exit 2
fi

action='sync'
dry_run=''
while [ $# -gt 0 ]; do
	case "$1" in
	--pretend )
		dry_run='-v --dry-run'
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
$1=="  dcad"{cap=1}
cap>=1{match($1,"^[ ]+"); indent=RLENGTH; gsub(/^[ \t]+|[ \t]+$/,"",$1); gsub(/^[ \t]+|[ \t]+$/,"", $2)}
cap>1 && eos==indent {exit}
$1=="dcad" && cap==1{eos=indent}
cap==3 && $1!~"^--"{cap=pcap; filters_done()}
$1=="dest" && cap==1{print "export config_DEST="$2}
$1=="sftp" && cap==1{pcap=cap; cap=2}
$1=="host" && cap==2{print "export config_HOST="$2}
$1=="hdir" && cap==2{print "export config_DIR="$2}
$1=="user" && cap==2{print "export config_USER="$2}
$1=="pass" && cap==2{print "export config_PASS="$2}
$1=="filters" && cap==1{pcap=cap; cap=3; filters="";}
cap==3 && $1~"^--"{filters=filters" "substr($0,index($0,$1));}
END { if (cap==3) { filters_done(); } }
' ${config}
)

# litmus test for expectee environment variables
if [ -z "${config_HOST}" ] || [ -z "${config_DEST}" ]; then
	echo "ERR: missing desintation and/or host, likely misconfiguration or ENV."
	exit 1
fi

echo "Synchronizing DCAD eviction files @ $(date)"

rclone_spec=":sftp,set_modtime=false,shell_type=none,disable_hashcheck,use_fstat=true,host=${config_HOST},user=${config_USER}:${config_DIR}"

if [ "${action}" == 'sync' ]; then

	RCLONE_SFTP_PASS="$(echo ${config_PASS} | rclone obscure -)" \
		rclone --config '' ${dry_run} sync \
		"${rclone_spec}" \
		--combined - \
		${config_FILTERS} \
		"${config_DEST}"

elif [ "${action}" == 'list' ]; then
	RCLONE_SFTP_PASS="$(echo ${config_PASS} | rclone obscure -)" \
		rclone --config '' ${dry_run} lsf \
		"${rclone_spec}" \
		${config_FILTERS}
fi

# rsync example (DCAD doesn't support as rsync requires SSH control channel)
# SSHPASS="${config_PASS}" rsync -avrn --list-only \
# 	--rsh="sshpass -e ssh -l ${config_USER}" \
# 	"${config_HOST}:${config_DIR}" \
# 	"${config_DEST}"
