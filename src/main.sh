#!/bin/bash

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")

APP_NAME="${SCRIPT_PARENT##*/}"

PATH_CONFIG="${SCRIPT_PARENT}/config.cfg"
PATH_DEFAULTS="${SCRIPT_PARENT}/defaults.cfg"

DEBUG=0

function main {
	
	# CHECK if root
	if [ "${UID}" -ne 0 ]; then
  		echo "This script must be run as root."
  		exit 1
	fi
	# CHECK if inotifywait is installed
	if ! which inotifywait > /dev/null; then
		echo "Error - This script needs inotifywait to run."
		exit 1
	fi

	# CONFIG & DEFAULTS
	if [[ -r ${PATH_CONFIG} ]]; then
		source "${PATH_CONFIG}"
	else
		echo "<4>WARN: No config file found at ${PATH_CONFIG}. Using defaults ..."
		source "${PATH_DEFAULTS}"
	fi

	# Ensure files exist
	for file in "${WATCH_FILES[@]}"; do
		if [ ! -f "${file}" ]; then
			echo "<4>File does not exist: ${file}"
		else
			if ((DEBUG)); then echo "Watching file: ${file}"; fi
		fi
	done

	# Monitor the files using inotifywait
	# -m: Monitor continuously
	# -e: Listen for specific events (access = read, modify = write, attrib = metadata changes)
	inotifywait -m -e access -e modify -e attrib "${WATCH_FILES[@]}" | while read -r directory events filename; do
		
		# Resolve the full path of the triggered file
		# Note: If watching exact files, inotifywait outputs 'path STATUS' or 'path STATUS filename'
		local triggered="${directory}${filename}"
		
		if [ ! -f "${triggered}" ]; then
			triggered="${directory}"
		fi

		local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
		
		# Gather forensics context
		# Construct the alert payload
		alert_msg=""
		alert_msg+="⚠️ HONEYPOT TRIGGERED ⚠️\n\n"
		alert_msg+="Time: ${timestamp}\n"
		alert_msg+="File: ${triggered}\n"
		alert_msg+="Action: ${events}\n"
		alert_msg+="----------------------------------------\n"
		alert_msg+="Active Sessions:\n"
		alert_msg+="$(who)\n"

		# 1. Log locally
		if ((LOG)); then echo "[${timestamp}] TRIGGERED: ${triggered} | Event: ${events}" >> "${LOG_FILE}"; fi

		# 2. Print to stdout (useful if running in foreground/debugging)
		if ((DEBUG)); then echo "Triggered file: ${triggered}"; fi

		# 3. Send Email Alert
		echo -e "${alert_msg}" | mail -s "${MAIL_SUBJECT}" "${MAIL_DST}"

	done
}

main ${@}