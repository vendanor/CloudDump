#!/bin/bash

# Vendanor VnCloudDump Startup Script
# This script reads Json configuration and starts the cron daemon


CONFIGFILE="/config/config.json"
LOGFILE="/persistent-data/logs/vnclouddump.log"


if [ "$(jq -r '.settings.DEBUG' ${CONFIGFILE})" = "true" ]; then
  set -x
fi


# Functions

timestamp() {

  date '+%Y-%m-%d %H:%M:%S'

}

log() {

  echo "[$(timestamp)] $*"
  echo "[$(timestamp)] $*" >>${LOGFILE}

}

error() {

  error="$*"
  echo "[$(timestamp)] ERROR: ${error}" >&2
  echo "[$(timestamp)] ERROR: ${error}" >>${LOGFILE}

}


# Init

mkdir -p /persistent-data/logs

log "Vendanor VnCloudDump Start ($0)"


# Check commands

cmds="which grep sed cut cp chmod mkdir bc jq crontab mail mutt postconf postmap"
cmds_missing=
for cmd in ${cmds}
do
  which "${cmd}" >/dev/null 2>&1
  if [ $? -eq 0 ] ; then
    continue
  fi
  if [ "${cmds_missing}" = "" ]; then
    cmds_missing="${cmd}"
  else
    cmds_missing="${cmds_missing} ${cmd}"
  fi
done

if ! [ "${cmds_missing}" = "" ]; then
  error "Missing \"${cmds_missing}\" commands."
  exit 1
fi


# Locate cron daemon

which cron >/dev/null 2>&1
if [ $? -eq 0 ]; then
  CRON="cron"
else
  which crond >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    CRON="crond"
  else
    error "Missing cron daemon."
    exit 1
  fi
fi


# Read settings

if [ ! -f "${CONFIGFILE}" ]; then
  error "Missing Json configuration file ${CONFIGFILE}."
  exit 1
fi

if [ ! -r "${CONFIGFILE}" ]; then
  error "Can't read Json configuration file ${CONFIGFILE}."
  exit 1
fi

SMTPSERVER=$(jq -r '.settings.SMTPSERVER' "${CONFIGFILE}" | sed 's/^null$//g')
SMTPPORT=$(jq -r '.settings.SMTPPORT' "${CONFIGFILE}" | sed 's/^null$//g')
SMTPUSER=$(jq -r '.settings.SMTPUSER' "${CONFIGFILE}" | sed 's/^null$//g')
SMTPPASS=$(jq -r '.settings.SMTPPASS' "${CONFIGFILE}" | sed 's/^null$//g')
MAILFROM=$(jq -r '.settings.MAILFROM' "${CONFIGFILE}" | sed 's/^null$//g')
MAILTO=$(jq -r '.settings.MAILTO' "${CONFIGFILE}" | sed 's/^null$//g')
DEBUG=$(jq -r '.settings.DEBUG' "${CONFIGFILE}")

log "Configuration:"
log "SMTP Server: $SMTPSERVER"
log "SMTP Port: $SMTPPORT"
log "SMTP Username: $SMTPUSER"
log "Mail From: $MAILFROM"
log "Mail To: $MAILTO"


# Setup postfix and mutt

postconf maillog_file=/var/log/postfix.log || exit 1
postconf inet_interfaces=127.0.0.1 || exit 1
postconf relayhost="[${SMTPSERVER}]:${SMTPPORT}" || exit 1
postconf smtp_sasl_auth_enable=yes || exit 1
postconf smtp_sasl_password_maps=lmdb:/etc/postfix/sasl_passwd || exit 1
postconf smtp_tls_wrappermode=yes || exit 1
postconf smtp_tls_security_level=encrypt || exit 1
postconf smtp_sasl_security_options=noanonymous || exit 1

touch /etc/postfix/relay || exit 1
touch /etc/postfix/sasl_passwd || exit 1
touch /etc/Muttrc || exit 1

if ! [ "${SMTPSERVER}" = "" ] && ! [ "${SMTPPORT}" = "" ]; then
  if [ "$SMTPUSER" = "" ] && [ "$SMTPPASS" = "" ]; then
    SMTPURL="smtps://${SMTPSERVER}:${SMTPPORT}"
  else
    SMTPURL="smtps://${SMTPUSER}:${SMTPPASS}@${SMTPSERVER}:${SMTPPORT}"
    grep "^\[${SMTPSERVER}\]:${SMTPPORT} ${SMTPUSER}:${SMTPPASS}$" /etc/postfix/sasl_passwd >/dev/null
    if [ $? -ne 0 ]; then
      echo "[${SMTPSERVER}]:${SMTPPORT} ${SMTPUSER}:${SMTPPASS}" >> /etc/postfix/sasl_passwd || exit 1
    fi
  fi
  grep "^set smtp_url=\"${SMTPURL}\"$" /etc/Muttrc >/dev/null
  if [ $? -ne 0 ]; then
    echo "set smtp_url=\"${SMTPURL}\"" >> /etc/Muttrc || exit 1
  fi
fi

postmap /etc/postfix/relay || exit 1
postmap lmdb:/etc/postfix/sasl_passwd || exit 1

/usr/sbin/postfix start || exit 1


# Test mail

echo "VnCloudDump $0" | mail -r "${MAILFROM}" -s "VnCloudDump $0" "${MAILTO}" || exit 1

#tail -f /var/log/postfix.log


# Create crontab jobs

CRONFILE="/etc/cron.d/vnclouddump-cron"

rm -f "${CRONFILE}"
touch "${CRONFILE}" || exit 1

echo "MAILFROM=${MAILFROM}" >>"${CRONFILE}" || exit 1
echo "MAILTO=${MAILTO}" >>"${CRONFILE}" || exit 1

jobs=$(jq -r ".jobs | length" "${CONFIGFILE}")
if [ "${jobs}" = "" ] || [ -z "${jobs}" ] || ! [ "${jobs}" -eq "${jobs}" ] 2>/dev/null; then
  error "Can't read jobs from Json configuration."
  exit 1
fi

if [ "${jobs}" -eq 0 ]; then
  error "No jobs in Json configuration."
  exit 1
fi

for ((i = 0; i < jobs; i++)); do

  jobid=$(jq -r ".jobs[${i}].id" "${CONFIGFILE}" | sed 's/^null$//g')
  if [ $? -ne 0 ] || [ "${jobid}" = "" ]; then
    error "Missing job ID for job index ${i}."
    continue
  fi

  script=$(jq -r ".jobs[${i}].script" "${CONFIGFILE}" | sed 's/^null$//g')
  if [ $? -ne 0 ] || [ "${script}" = "" ]; then
    error "Missing script for job ID ${jobid}."
    continue
  fi

  crontab=$(jq -r ".jobs[${i}].crontab" "${CONFIGFILE}" | sed 's/^null$//g')
  if [ $? -ne 0 ] || [ "${crontab}" = "" ]; then
    error "Missing crontab for job ID ${jobid}."
    continue
  fi

  jobdebug=$(jq -r ".jobs[${i}].debug" "${CONFIGFILE}")

  echo "${script}" | grep '^\/' >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    scriptfile="${script}"
  else
    scriptfile=$(which "${script}" 2>/dev/null)
    if [ "${scriptfile}" = "" ]; then
      error "Missing scriptfile ${script}."
      exit 1
    fi
  fi

  if ! [ -f "${scriptfile}" ]; then
    error "Missing scriptfile ${scriptfile}."
    exit 1
  fi

  if ! [ -x "${scriptfile}" ]; then
    error "Scriptfile ${scriptfile} not executable."
    exit 1
  fi

  if [ "${DEBUG}" = "true" ]; then
    opt="-x"
  fi

  echo "${crontab} /bin/bash ${opt} /usr/local/bin/wrapper.sh ${script} ${jobid} ${jobdebug} >/dev/null" >>"${CRONFILE}" || exit 1

done


# Setup crontab

chmod a+x "${CRONFILE}" || exit 1
crontab -r >/dev/null 2>&1
crontab "${CRONFILE}" || exit 1

log "Cron jobs:"
crontab -l || exit 1
crontab -l >>"${LOGFILE}" || exit 1


# Start crontab

log "Starting cron daemon..."

"${CRON}" -V >/dev/null 2>&1
if [ $? -eq 0 ]; then
  "${CRON}" -n
else
  "${CRON}" -f
fi