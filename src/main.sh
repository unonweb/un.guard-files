#!/bin/bash

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")

PATH_CONFIG="${SCRIPT_PARENT}/config.cfg"
PATH_DEFAULTS="${SCRIPT_PARENT}/defaults.cfg"

LOG_FILE="${SCRIPT_PARENT}/log.txt"
DEBUG=1

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
			echo "File does not exist: ${file}"
		else
			if ((DEBUG)); then echo "Watching file: ${file}"; fi
		fi
	done

	echo "Sentinel active. Watching files..."

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
		local active_users=$(who)
		
		# Construct the alert payload
		alert_msg=""
		alert_msg+="⚠️ HONEYPOT TRIGGERED ⚠️\n"
		alert_msg+="Time: ${timestamp}\n"
		alert_msg+="File Touched: ${triggered}\n"
		alert_msg+="Action Detected: ${events}\n"
		alert_msg+="----------------------------------------\n"
		alert_msg+="Current Active Terminal Sessions: ${active_users}\n"

		# 1. Log locally
		echo "[${timestamp}] TRIGGERED: ${triggered} | Event: ${events}" >> "${LOG_FILE}"

		# 2. Print to stdout (useful if running in foreground/debugging)
		if ((DEBUG)); then echo "Triggered file: ${triggered}"; fi

		# 3. Send Email Alert
		echo "${alert_msg}" | mail -s "${MAIL_SUBJECT}" "${MAIL_DST}"

	done
}

main ${@}