#!/bin/bash

# Vendanor CloudDump Wrapper Script
# This script runs the specified script, logs all output and sends the result on e-mail.
# Usage: wrapper.sh <script> <jobid> <debug>


RANDOM=$$
LOGFILE="/persistent-data/logs/vnclouddump-${RANDOM}.log"
MAIL="mutt"

CONFIGFILE="/config/config.json"
#CONFIGFILE="${HOME}/Projects/Vendanor/VnCloudDump/config/config.json"

VERSION=$(head -n 1 /VERSION)


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

json_array_to_strlist() {

  local i
  local output
  count=$(jq -r "${1} | length" "${CONFIGFILE}")
  for ((i = 0; i < count; i++)); do
    local value
    value=$(jq -r "${1}[${i}]" "${CONFIGFILE}" | sed 's/^null$//g')
    if [ $? -ne 0 ] || [ "$value" = "" ] ; then
      continue
    fi
    if [ "${output}" = "" ]; then
      output="${value}"
    else
      output="${output} ${value}"
    fi
  done

  echo "${output}"

}


# Init

mkdir -p /persistent-data/logs

log "Vendanor CloudDump v${VERSION} Wrapper ($0)"


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

HOST=$(jq -r '.settings.HOST' "${CONFIGFILE}" | sed 's/^null$//g')
MAILFROM=$(jq -r '.settings.MAILFROM' "${CONFIGFILE}" | sed 's/^null$//g')
MAILTO=$(jq -r '.settings.MAILTO' "${CONFIGFILE}" | sed 's/^null$//g')

if [ "${MAILFROM}" = "" ] || [ "${MAILTO}" = "" ]; then
  have_mail=0
fi


# Read configuration for e-mail report

if [ "${SCRIPT}" = "azdump.sh" ]; then

  # Find the job index for this job ID

  jobs=$(jq -r ".jobs | length" "${CONFIGFILE}")
  if [ "${jobs}" = "" ] || [ -z "${jobs}" ] || ! [ "${jobs}" -eq "${jobs}" ] 2>/dev/null; then
    error "Can't read jobs from Json configuration."
    exit 1
  fi

  job_idx=
  for ((i = 0; i < jobs; i++)); do
    jobid_current=$(jq -r ".jobs[${i}].id" "${CONFIGFILE}" | sed 's/^null$//g')
    if [ $? -ne 0 ] || [ "${jobid_current}" = "" ]; then
      continue
    fi
    if [ "${jobid_current}" = "${JOBID}" ]; then
      job_idx="${i}"
      break
    fi
  done

  if [ "${job_idx}" = "" ]; then
    error "No job ID ${JOBID} in Json configuration."
    exit 1
  fi

  crontab=$(jq -r ".jobs[${job_idx}].crontab" "${CONFIGFILE}")
  debug=$(jq -r ".jobs[${job_idx}].debug" "${CONFIGFILE}")

  bs_count=$(jq -r ".jobs[${job_idx}].blobstorages | length" "${CONFIGFILE}")
  if [ "${bs_count}" = "" ] || [ -z "${bs_count}" ] || ! [ "${bs_count}" -eq "${bs_count}" ] 2>/dev/null; then
    bs_count=0
    error "Can't read blobstorages from Json configuration."
  fi

  if [ "${bs_count}" -eq 0 ]; then
    error "No blobstorages for ${JOBID} in Json configuration."
  fi

  for ((bs_idx = 0; bs_idx < bs_count; bs_idx++)); do

    source=$(jq -r ".jobs[${job_idx}].blobstorages[${bs_idx}].source" "${CONFIGFILE}" | sed 's/^null$//g')
    if [ $? -ne 0 ] || [ "${source}" = "" ]; then
      error "Missing source for job index ${job_idx} ID ${JOBID}."
      result=1
      continue
    fi

    destination=$(jq -r ".jobs[${job_idx}].blobstorages[${bs_idx}].destination" "${CONFIGFILE}" | sed 's/^null$//g')
    if [ $? -ne 0 ] || [ "${destination}" = "" ]; then
      error "Missing destination for job index ${job_idx} ID ${JOBID}."
      result=1
      continue
    fi

    delete_destination=$(jq -r ".jobs[${job_idx}].blobstorages[${bs_idx}].delete_destination" "${CONFIGFILE}" | sed 's/^null$//g')

    if [ "${delete_destination}" = "" ]; then
      delete_destination="false"
    fi

    source_stripped=$(echo "${source}" | cut -d '?' -f 1)

    blobstorage="Source: ${source_stripped}
Destination: ${destination}   
Delete destination: ${delete_destination}   "

    if [ "${blobstorages}" = "" ]; then
      blobstorages="${blobstorage}"
    else
      blobstorages="${blobstorages}
${blobstorage}"
    fi

  done

  configuration="Schedule: ${crontab}
Debug: ${debug}
${blobstorages}"

elif [ "${SCRIPT}" = "pgdump.sh" ]; then

  # Find the job index for this job ID

  jobs=$(jq -r ".jobs | length" "${CONFIGFILE}")
  if [ "${jobs}" = "" ] || [ -z "${jobs}" ] || ! [ "${jobs}" -eq "${jobs}" ] 2>/dev/null; then
    error "Can't read jobs from Json configuration."
    exit 1
  fi

  job_idx=
  for ((i = 0; i < jobs; i++)); do
    jobid_current=$(jq -r ".jobs[${i}].id" "${CONFIGFILE}" | sed 's/^null$//g')
    if [ $? -ne 0 ] || [ "${jobid_current}" = "" ]; then
      continue
    fi
    if [ "${jobid_current}" = "${JOBID}" ]; then
      job_idx="${i}"
      break
    fi
  done

  if [ "${job_idx}" = "" ]; then
    error "No job ID ${JOBID} in Json configuration."
    exit 1
  fi

  crontab=$(jq -r ".jobs[${job_idx}].crontab" "${CONFIGFILE}")
  debug=$(jq -r ".jobs[${job_idx}].debug" "${CONFIGFILE}")

  # Iterate servers

  server_count=$(jq -r ".jobs[${job_idx}].servers | length" "${CONFIGFILE}")
  if [ "${server_count}" = "" ] || [ -z "${server_count}" ] || ! [ "${server_count}" -eq "${server_count}" ] 2>/dev/null; then
    error "Can't read servers for ${JOBID} from Json configuration."
    server_count=0
  fi

  if [ "${server_count}" -eq 0 ]; then
    error "No servers for ${JOBID} in Json configuration."
  fi


  for ((server_idx = 0; server_idx < server_count; server_idx++)); do

    PGHOST=$(jq -r ".jobs[${job_idx}].servers[${server_idx}].host" "${CONFIGFILE}" | sed 's/^null$//g')
    if [ $? -ne 0 ] || [ "${PGHOST}" = "" ]; then
      error "Missing host for server at index ${server_idx} for job ID ${JOBID}."
      result=1
      continue
    fi

    PGPORT=$(jq -r ".jobs[${job_idx}].servers[${server_idx}].port" "${CONFIGFILE}" | sed 's/^null$//g')
    if [ $? -ne 0 ]; then
      PGPORT="5432"
    fi

    PGUSERNAME=$(jq -r ".jobs[${job_idx}].servers[${server_idx}].user" "${CONFIGFILE}" | sed 's/^null$//g')
    if [ $? -ne 0 ] || [ "${PGUSERNAME}" = "" ]; then
      error "Missing user for server ${PGHOST}."
      result=1
      continue
    fi

    PGPASSWORD=$(jq -r ".jobs[${job_idx}].servers[${server_idx}].pass" "${CONFIGFILE}" | sed 's/^null$//g')
    if [ $? -ne 0 ] || [ "${PGPASSWORD}" = "" ]; then
      error "Missing pass for ${PGHOST}."
      result=1
      continue
    fi

    backuppath=$(jq -r ".jobs[${job_idx}].servers[${server_idx}].backuppath" "${CONFIGFILE}" | sed 's/^null$//g')
    if [ $? -ne 0 ] || [ "${backuppath}" = "" ]; then
      error "Missing backuppath for ${PGHOST}."
      continue
    fi

    filenamedate=$(jq -r ".jobs[${job_idx}].servers[${server_idx}].filenamedate" "${CONFIGFILE}" | sed 's/^null$//g')
    compress=$(jq -r ".jobs[${job_idx}].servers[${server_idx}].compress" "${CONFIGFILE}" | sed 's/^null$//g')

    databases=$(jq -r ".jobs[${job_idx}].servers[${server_idx}].databases[] | keys[]" "${CONFIGFILE}" | tr '\n' ' ')
    databases_included=$(json_array_to_strlist ".jobs[${job_idx}].servers[${server_idx}].databases_included")
    databases_excluded=$(json_array_to_strlist ".jobs[${job_idx}].servers[${server_idx}].databases_excluded")

    database_configuration=""
    databases_configuration=""

    for database in ${databases}
    do
      tables_included=$(json_array_to_strlist ".jobs[${job_idx}].servers[${server_idx}].databases[0][\"${database}\"].tables_included")
      tables_excluded=$(json_array_to_strlist ".jobs[${job_idx}].servers[${server_idx}].databases[0][\"${database}\"].tables_excluded")
      database_configuration="Database: ${database}
Tables included: ${tables_included}
Tables excluded: ${tables_excluded}"
      if [ "${databases_configuration}" = "" ]; then
        databases_configuration="${database_configuration}"
      else
        databases_configuration="${databases_configuration}
${database_configuration}"
      fi

    done

    entry_server="Postgres server: ${PGHOST}
Postgres port: ${PGPORT}
Postgres username: ${PGUSERNAME}
Backup path: ${backuppath}
Filename date: ${filenamedate}
Compress: ${compress}
Included databases: ${databases_included}
Excluded databases: ${databases_excluded}"

    if [ ! "${databases_configuration}" = "" ]; then
    entry_server="${entry_server}
Database configuration:
${databases_configuration}"
    fi

    if [ "${entry_servers}" = "" ]; then
      entry_servers="${entry_server}"
    else
      entry_servers="${entry_servers}
${entry_server}"
    fi

  done

  configuration="Schedule: ${crontab}
Debug: ${debug}
${entry_servers}"

else
  error "Unknown script ${SCRIPT}."
  exit 1
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

time_start=$(date +%s)
time_start_timestamp=$(timestamp)

if [ "${DEBUG}" = "true" ]; then
  /bin/bash -x "${SCRIPTFILEPATH}" "${JOBID}" >>${LOGFILE} 2>&1
  result=$?
else
  /bin/bash "${SCRIPTFILEPATH}" "${JOBID}" >>${LOGFILE} 2>&1
  result=$?
fi

time_end=$(date +%s)


# Remove lockfile

rm -f "${LOCKFILE}"


# Send report on e-mail

if ! [ "${have_mail}" = "1" ]; then
  error "Missing MAIL."
  exit 1
fi

if [ ${result} -eq 0 ]; then
  result_text="Success"
else
  result_text="Failure"
fi

log "Sending e-mail to ${MAILTO} from ${MAILFROM}."

attachments="${mailattachopt} ${LOGFILE}"

azcopy_logfile=$(grep '^Log file is located at: .*\.log$' ${LOGFILE} | sed -e 's/Log file is located at: \(.*\)/\1/')

if [ ! "${azcopy_logfile}" = "" ]; then
  attachments="${attachments} ${mailattachopt} ${azcopy_logfile}"
fi

attachments="${attachments} --"

message="CloudDump ${HOST} JOB REPORT (${result_text})

Script: ${SCRIPTFILENAME}
ID: ${JOBID}
Started: ${time_start_timestamp}
Completed: $(timestamp)
Time elapsed: $(((time_end - time_start)/60)) minutes $(((time_end - time_start)%60)) seconds
${configuration}

For more information consult the attached logs.

Vendanor CloudDump v${VERSION}
"

if [ "${MAIL}" = "mutt" ]; then
  echo "${message}" | EMAIL="${MAILFROM} <${MAILFROM}>" ${MAIL} -s "[${result_text}] CloudDump ${HOST}: ${JOBID}" ${attachments} "${MAILTO}"
else
  echo "${message}" | ${MAIL} -r "${MAILFROM} <${MAILFROM}>" -s "[${result_text}] CloudDump ${HOST}: ${JOBID}" ${attachments} "${MAILTO}"
fi

if [ $? -eq 0 ]; then
  rm -f "${LOGFILE}"
else
  exit 1
fi


exit ${result}
