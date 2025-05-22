#!/usr/bin/env sh
# Synchronize data from the SFTP server and path designated by the SYNC_
#  environment variables to a local path. See sync-dotenv.sh for
#  translating the config.yml file contents into environment variables.
# Usage: env $(./sync-dotenv.sh | xargs) ./sync-dcad-evictions.sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export TZ='America/Chicago'

usage() {
	echo "Synchronize a remote directory to a local path using SFTP."
	echo "Usage: $(basename $0) [--pretend] [--list]"
	echo
	echo "Options:"
	echo "  --pretend: Make no changes, but test the connection and operation."
	echo "  --list   : Only list remove files that would be seen by the sync"
	echo "             operation."
	echo
	echo "Environment (required):"
	echo "  SYNC_DEST"
	echo "  SYNC_HOST"
	echo "  SYNC_DIR"
	echo "  SYNC_USER"
	echo "  SYNC_PASS"
	echo
	echo "Requires rclone v1.69.2+"
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	usage
	exit
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
	esac
	shift
done

# litmus test for expectee environment variables
if [ -z "${SYNC_HOST}" ] || [ -z "${SYNC_DEST}" ]; then
	echo "ERR: missing configuration environment; was sync-dotenv.sh used?"
	exit 1
fi

echo "Synchronizing DCAD eviction files @ $(date)"

rclone_spec=":sftp,set_modtime=false,shell_type=none,disable_hashcheck,use_fstat=true,host=${SYNC_HOST},user=${SYNC_USER}:${SYNC_DIR}"
filters=$(cat <<EOT
--include Eviction_Data_Daily_*.xls
--include Eviction_Data_Weekly_*.xls
EOT
)

if [ "${action}" == 'sync' ]; then

	RCLONE_SFTP_PASS="$(echo ${SYNC_PASS} | rclone obscure -)" \
		rclone --config '' ${dry_run} sync \
		"${rclone_spec}" \
		--combined - \
		${filters} \
		"${SYNC_DEST}" 
		# | grep -vE '^= '
	# grep removes all output denoting files which are equal, showing only changes

elif [ "${action}" == 'list' ]; then
	RCLONE_SFTP_PASS="$(echo ${SYNC_PASS} | rclone obscure -)" \
		rclone --config '' ${dry_run} lsf \
		"${rclone_spec}" \
		${filters}
fi

# rsync example (DCAD doesn't support as rsync requires SSH control channel)
# SSHPASS="${SYNC_PASS}" rsync -avrn --list-only \
# 	--rsh="sshpass -e ssh -l ${SYNC_USER}" \
# 	"${SYNC_HOST}:${SYNC_DIR}" \
# 	"${SYNC_DEST}"
