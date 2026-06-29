# REQUIRES
# ========
# - ALERT_MAIL
# - ALERT_MAIL_TO
# - ALERT_MAIL_SUBJECT

function alert {

	local alert_msg="${1}"

	if (( ! ALERT_MAIL )); then
		return 0
	fi

	if (( ALERT_MAIL )) && [[ -z "${ALERT_MAIL_TO}" ]]; then
		log "<3> Required var not set: ALERT_MAIL_TO"
		return 1
	fi

	if [[ -n "${alert_msg}" ]]; then

		# ALERT
		alert_msg_header+="DATE: $(date "+%Y-%m-%d %H:%M:%S")\n"
		alert_msg_header+="HOSTNAME: ${HOSTNAME}\n"
		alert_msg_header+="---\n\n"
		
		log "<6> Sending Mail-Alert to ${ALERT_MAIL_TO}"
		
		echo -e "${alert_msg_header}${alert_msg}" | \
		mail -s "${ALERT_MAIL_SUBJECT}" "${ALERT_MAIL_TO}" \
		&& log "<5> Mail-Alert sent to ${ALERT_MAIL_TO}" \
		&& return 0
	fi
}