#!/usr/bin/env sh
# Translate some elements of the YML application configuration into dotenv
#  format to be used by the file sync process.
awk '
/dcad:/{cap=1}
/dest:/ && cap==1{print "SYNC_DEST="$2}
/sftp:/ && cap==1{cap=2}
/host:/ && cap==2{print "SYNC_HOST="$2}
/hdir:/ && cap==2{print "SYNC_DIR="$2}
/user:/ && cap==2{print "SYNC_USER="$2}
/pass:/ && cap==2{print "SYNC_PASS="$2}
' ${1:-config.yml}
