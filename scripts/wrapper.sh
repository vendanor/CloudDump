#!/bin/bash

# Vendanor CloudDump Wrapper Script
# This script runs the specified script, logs all output and sends the result on e-mail.
# Usage: wrapper.sh <script> <jobid> <debug>


RANDOM=$$
LOGFILE="/persistent-data/logs/vnclouddump-${RANDOM}.log"
MAIL="mutt"

CONFIGFILE="/config/config.json"
#CONFIGFILE="${HOME}/Projects/Vendanor/VnCloudDump/config/config.json"


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

log "Vendanor CloudDump Wrapper ($0)"


# Check commands

cmds="which lockfile jq ${MAIL}"
cmds_missing=
have_mail=0
for cmd in ${cmds}
do

  which "${cmd}" >/dev/null 2>&1
  result="$?"

  if [ "${cmd}" = "${MAIL}" ]; then
    if [ "${result}" -eq 0 ] ; then
      have_mail=1
    fi
    continue
  fi

  if [ "${result}" -eq 0 ] ; then
    continue
  fi

  if [ "${cmds_missing}" = "" ]; then
    cmds_missing="${cmd}"
  else
    cmds_missing="${cmds_missing}, ${cmd}"
  fi

done

if ! [ "${cmds_missing}" = "" ]; then
  error "Missing ${cmds_missing} commands."
  exit 1
fi


# Check mail command type

if [ "${MAIL}" = "mail" ]; then
  "${MAIL}" -V >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    "${MAIL}" -V | grep "^mail (GNU Mailutils)" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      mailattachopt="-A"
    else
      mailattachopt="-a"
    fi
  else
    mailattachopt="-A"
  fi
elif [ "${MAIL}" = "mutt" ]; then
  mailattachopt="-a"
else
  error "Unknown mail command: ${MAIL}"
  exit 1
fi


# Setup

SCRIPT="${1}"
JOBID="${2}"
DEBUG="${3}"

if [ "${SCRIPT}" = "" ] || [ "${JOBID}" = "" ]; then
  error "Syntax: $0 <Script> <JobID>"
  exit 1
fi

echo "${SCRIPT}" | grep '\/' >/dev/null 2>&1
if [ $? -eq 0 ]; then
  SCRIPTFILEPATH="${SCRIPT}"
  SCRIPTFILENAME=$(echo "${SCRIPT}" | sed 's/.*\///g')
else
  SCRIPTFILEPATH=$(which "${SCRIPT}" 2>/dev/null)
  if [ "${SCRIPTFILEPATH}" = "" ]; then
    SCRIPTFILEPATH="/usr/local/bin/${SCRIPT}"
  fi
  SCRIPTFILENAME="${SCRIPT}"
fi

if ! [ -f "${SCRIPTFILEPATH}" ]; then
  error "Missing scriptfile ${SCRIPTFILEPATH}."
  exit 1
fi

if ! [ -r "${SCRIPTFILEPATH}" ]; then
  error "Scriptfile ${SCRIPTFILEPATH} not readable."
  exit 1
fi

if ! [ -x "${SCRIPTFILEPATH}" ]; then
  error "Scriptfile ${SCRIPTFILEPATH} not executable."
  exit 1
fi

if [ ! -f "${CONFIGFILE}" ]; then
  error "Missing Json configuration file ${CONFIGFILE}."
  exit 1
fi

MAILFROM=$(jq -r '.settings.MAILFROM' "${CONFIGFILE}" | sed 's/^null$//g')
MAILTO=$(jq -r '.settings.MAILTO' "${CONFIGFILE}" | sed 's/^null$//g')

if [ "${MAILFROM}" = "" ] || [ "${MAILTO}" = "" ]; then
  have_mail=0
fi


# Create lockfile and make sure that script is not already running

LOCKFILE="/tmp/LOCKFILE_${SCRIPTFILENAME}_${JOBID}"
LOCKFILE=$(echo "${LOCKFILE}" | sed 's/\.//g')
log "Using lockfile ${LOCKFILE}"
lockfile -r 0 "${LOCKFILE}" >/dev/null 2>&1
if [ $? -ne 0 ]; then
  log "${0} already running."
  rm -f "${LOGFILE}"
  exit 0
fi

log "${0} running."


# Run script

if [ "${DEBUG}" = "true" ]; then
  /bin/bash -x "${SCRIPTFILEPATH}" "${JOBID}" >>${LOGFILE} 2>&1
  result=$?
else
  /bin/bash "${SCRIPTFILEPATH}" "${JOBID}" >>${LOGFILE} 2>&1
  result=$?
fi


# Remove lockfile

rm -f "${LOCKFILE}"


# Send report on e-mail

if ! [ "${have_mail}" = "1" ]; then
  error "Missing MAIL."
  exit 1
fi

if [ ${result} = 0 ]; then
  result_text="success"
else
  result_text="failure"
fi

log "Sending e-mail to ${MAILTO} from ${MAILFROM}."

attachments="${mailattachopt} ${LOGFILE}"

azcopy_logfile=$(grep '^Log file is located at: .*\.log$' ${LOGFILE} | sed -e 's/Log file is located at: \(.*\)/\1/')

if [ ! "${azcopy_logfile}" = "" ]; then
  attachments="${attachments} ${mailattachopt} ${azcopy_logfile}"
fi

attachments="${attachments} --"

message="
Vendanor CloudDump report

Script: ${SCRIPTFILENAME}
Job ID: ${JOBID}
Result: ${result_text}
Date: $(timestamp)

See attached logs.
"

if [ "${MAIL}" = "mutt" ]; then
  echo "${message}" | EMAIL="Vendanor CloudDump <${MAILFROM}>" ${MAIL} -s "${JOBID}: Vendanor CloudDump ${result_text} report" ${attachments} "${MAILTO}"
else
  echo "${message}" | ${MAIL} -r "Vendanor CloudDump <${MAILFROM}>" -s "${JOBID}: Vendanor CloudDump ${result_text} report" ${attachments} "${MAILTO}"
fi

if [ $? -eq 0 ]; then
  rm -f "${LOGFILE}"
else
  exit 1
fi


exit ${result}
