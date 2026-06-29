#!/usr/bin/bash

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")

APP_NAME="${SCRIPT_PARENT##*/}"

PATH_CONFIG="${SCRIPT_PARENT}/config.cfg"
PATH_DEFAULTS="${SCRIPT_PARENT}/defaults.cfg"

# IMPORTS
source "${SCRIPT_DIR}/lib/log.sh"
source "${SCRIPT_DIR}/lib/alert.sh"

function main {
	
	# Associative array to track the last alert time for each file
	declare -A LAST_ALERT_TIME

	# CHECK if root
	if [ "${UID}" -ne 0 ]; then
  		echo "This script must be run as root."
  		exit 1
	fi

	# CHECK if inotifywait is installed
	if ! which inotifywait > /dev/null; then
		log "<3> This script needs inotifywait to run."
		exit 1
	fi

	# CONFIG & DEFAULTS
	if [[ -r ${PATH_CONFIG} ]]; then
		source "${PATH_CONFIG}"
	else
		log "<4> No config file found at ${PATH_CONFIG}. Using defaults ..."
		source "${PATH_DEFAULTS}"
	fi

	if [ ${#WATCH_FILES[@]} -eq 0 ]; then
    	log "<3> ERROR: WATCH_FILES array is empty."
    	exit 1
	fi

	# MKDIR state
	if [[ ! -d "${LOG_DIR}" ]]; then
		log "<5> Creating state dir at: ${LOG_DIR}"
		mkdir -p "${LOG_DIR}"
	fi

	# Ensure files exist
	for file in "${WATCH_FILES[@]}"; do
		if [ ! -f "${file}" ]; then
			log "<4> File does not exist: ${file}"
		else
			log "<6> Watching file: ${file}"
		fi
	done

	while read -r directory events filename; do
		
		# Reset alert message for this specific event iteration
    	local alert_msg="" 
    	local triggered=""
		local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
		
		# Handle file vs directory path resolution safely
		# Resolve the full path of the triggered file
		# Note: If watching exact files, inotifywait outputs 'path STATUS' or 'path STATUS filename'
		if [ -z "${filename}" ]; then
			triggered="${directory}"
		else
			triggered="${directory}${filename}"
		fi

		# COOLDOWN
    	local current_time=${SECONDS}
    	local last_time=${LAST_ALERT_TIME["${triggered}"]:-0}
		# number of seconds since shell invocation
		# Check if the file was alerted on recently
		if (( current_time - last_time < COOLDOWN_SECONDS )); then
			# Optional: Log the suppression locally, but skip the noisy alert
			log "<5> THROTTLED: Skipping alert for ${triggered} (Cooldown active)"
			continue
		fi

		# Update the last alert time for this specific file
    	LAST_ALERT_TIME["${triggered}"]=${current_time}
		
		# Gather forensics context
		# Construct the alert payload
		alert_msg+="Time: ${timestamp}\n"
		alert_msg+="File: ${triggered}\n"
		alert_msg+="Action: ${events}\n\n"
		alert_msg+="Active Sessions:\n"
		alert_msg+="$(who)\n"

		# Log locally
		log "<4> TRIGGERED: ${triggered} | Event: ${events}"

		# ALERT
		alert "${alert_msg}"

	done < <(inotifywait -m --format '%w %e %f' -e access -e modify -e attrib "${WATCH_FILES[@]}")
	# -m: Monitor continuously
	# -e: Listen for specific events (access = read, modify = write, attrib = metadata changes)
}

main