#!/bin/bash

# Vendanor PgDump Script
# This script runs pg_dump for each database on each server for the specified job
# Usage: pgdump.sh <jobid>


CONFIGFILE="/config/config.json"
#CONFIGFILE="${HOME}/Projects/Vendanor/VnCloudDump/config/config.json"

JOBID="${1}"


if [ "$(jq -r '.settings.DEBUG' ${CONFIGFILE})" = "true" ]; then
  set -x
fi


# Functions

timestamp() {

  date '+%Y-%m-%d %H:%M:%S'

}

print() {

  echo "[$(timestamp)] $*"

}

errorprint() {

  echo "[$(timestamp)] ERROR: $*" >&2

}

error() {

  errorprint "$@"

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

print "Vendanor PgDump ($0)"


# Check commands

cmds="which grep sed cut date touch mkdir cp rm jq psql pg_dump tar bzip2"
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


# Check parameters

if [ "${JOBID}" = "" ]; then
  error "Missing Job ID."
  exit 1
fi


# Check configfile

if [ ! -f "${CONFIGFILE}" ]; then
  error "Missing Json configuration file ${CONFIGFILE}."
  exit 1
fi

if [ ! -r "${CONFIGFILE}" ]; then
  error "Can't read Json configuration file ${CONFIGFILE}."
  exit 1
fi


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


# Iterate servers

server_count=$(jq -r ".jobs[${job_idx}].servers | length" "${CONFIGFILE}")
if [ "${server_count}" = "" ] || [ -z "${server_count}" ] || ! [ "${server_count}" -eq "${server_count}" ] 2>/dev/null; then
  error "Can't read servers for ${JOBID} from Json configuration."
  exit 1
fi

if [ "${server_count}" -eq 0 ]; then
  error "No servers for ${JOBID} in Json configuration."
  exit 1
fi


for ((server_idx = 0; server_idx < server_count; server_idx++)); do

  PGHOST=$(jq -r ".jobs[${job_idx}].servers[${server_idx}].host" "${CONFIGFILE}" | sed 's/^null$//g')
  if [ $? -ne 0 ] || [ "${PGHOST}" = "" ]; then
    error "Missing host for server at index ${server_idx} for job ID ${JOBID}."
    result=1
    continue
  fi

  print "Checking server ${PGHOST} (${server_idx}) for job ID ${job_idx}..."

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

  databases_included=$(json_array_to_strlist ".jobs[${job_idx}].servers[${server_idx}].databases_included")
  databases_excluded=$(json_array_to_strlist ".jobs[${job_idx}].servers[${server_idx}].databases_excluded")

  print "Listing databases for ${PGHOST}..."

  PGPASSWORD=${PGPASSWORD} psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSERNAME}" -l
  if [ $? -ne 0 ]; then
    error "Failed to list databases for ${PGHOST}."
    result=1
    continue
  fi

  databases_all=$(PGPASSWORD=${PGPASSWORD} psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSERNAME}" -l | grep '|' | sed 's/ //g' | grep -v '^Name|' | grep -v '^||' | cut -d '|' -f 1 | sed -z 's/\n/ /g;s/ $/\n/')
  if [ $? -ne 0 ]; then
    error "Failed to list databases for ${PGHOST}."
    result=1
    continue
  fi

  if [ "${databases_all}" = "" ]; then
    error "Missing databases for ${PGHOST}."
    result=1
    continue
  fi

  print "All databases: ${databases_all}"
  print "Included databases: ${databases_included}"
  print "Excluded databases: ${databases_excluded}"

  for database in ${databases_all}
  do

    database_lc=$(echo "${database}" | tr '[:upper:]' '[:lower:]')

    if ! [ "${databases_excluded}" = "" ]; then
      exclude=0
      for database_exclude in ${databases_excluded}
      do
        database_exclude_lc=$(echo "${database_exclude}" | tr '[:upper:]' '[:lower:]')
        if [ "${database_exclude_lc}" = "${database_lc}" ]; then
          exclude=1
        fi
      done
      if [ "${exclude}" = "1" ]; then
        continue
      fi
    fi

    include=0
    if [ "${databases_included}" = "" ]; then
      include=1
    else
      for database_include in ${databases_included}
      do
        database_include_lc=$(echo "${database_include}" | tr '[:upper:]' '[:lower:]')
        if [ "${database_include_lc}" = "${database_lc}" ]; then
          include=1
        fi
      done
    fi

    if ! [ "${include}" = "1" ]; then
      continue
    fi

    if [ "${databases_backup}" = "" ]; then
      databases_backup="${database}"
    else
      databases_backup="${databases_backup} ${database}"
    fi

  done

  if [ "${databases_backup}" = "" ]; then
    error "Missing databases to backup for ${PGHOST}."
    continue
  fi

  print "Databases to backup: ${databases_backup}"

  # Create backup path

  print "Creating backuppath ${backuppath}..."

  mkdir -p "${backuppath}"
  if [ $? -ne 0 ]; then
    error "Could not create backuppath ${backuppath}."
    result=1
    continue
  fi

  # Check permissions

  print "Checking permission for backuppath ${backuppath}..."

  touch "${backuppath}/TEST_FILE"
  if [ $? -ne 0 ]; then
    error "Could not access ${backuppath}."
    result=1
    continue
  fi

  rm -f "${backuppath}/TEST_FILE"

  # Run pg_dump for each database

  for database in ${databases_backup}; do

    # Read the configuration for this database

    tables_excluded=
    tables_included=
    tables_excluded_params=
    tables_included_params=

    db_count=$(jq -r ".jobs[${job_idx}].servers[${server_idx}].databases | length" "${CONFIGFILE}")
    if [ "${db_count}" = "" ] || [ -z "${db_count}" ] || ! [ "${db_count}" -eq "${db_count}" ] 2>/dev/null; then
      error "Can't read database configuration for ${PGHOST} from Json configuration."
      result=1
      continue
    fi

    for ((db_idx = 0; db_idx < db_count; db_idx++)); do

      # Check if this is the correct array index for this database.
      jq_output=$(jq -r ".jobs[${job_idx}].servers[${server_idx}].databases[${db_idx}][\"${database}\"] | length" "${CONFIGFILE}" | sed 's/^null$//g')
      if [ "${jq_output}" = "" ] || [ -z "${jq_output}" ] || ! [ "${jq_output}" -eq "${jq_output}" ] || [ "${jq_output}" -eq 0 ] 2>/dev/null; then
        continue
      fi

      # Read excluded tables
      tb_count=$(jq -r ".jobs[${job_idx}].servers[${server_idx}][\"databases\"][${db_idx}][\"${database}\"].tables_excluded | length" "${CONFIGFILE}")
      for ((tb_idx = 0; tb_idx < tb_count; tb_idx++)); do
        table_excluded=$(jq -r ".jobs[${job_idx}].servers[${server_idx}][\"databases\"][${db_idx}][\"${database}\"].tables_excluded[${tb_idx}]" "${CONFIGFILE}" | sed 's/^null$//g')
        if [ "${table_excluded}" = "" ]; then
          continue
        fi
        if [ "${tables_excluded}" = "" ]; then
          tables_excluded="$table_excluded"
          tables_excluded_params="--exclude-table=$table_excluded"
        else
          tables_excluded="${tables_excluded}, ${table_excluded}"
          tables_excluded_params="${tables_excluded_params} --exclude-table=${table_excluded}"
        fi
      done

      # Read included tables
      tb_count=$(jq -r ".jobs[${job_idx}].servers[${server_idx}][\"databases\"][${db_idx}][\"${database}\"].tables_included | length" "${CONFIGFILE}")
      for ((tb_idx = 0; tb_idx < tb_count; tb_idx++)); do
        table_included=$(jq -r ".jobs[${job_idx}].servers[${server_idx}][\"databases\"][${db_idx}][\"${database}\"].tables_included[${tb_idx}]" "${CONFIGFILE}" | sed 's/^null$//g')
        if [ "${table_included}" = "" ]; then
          continue
        fi
        if [ "${tables_included}" = "" ]; then
          tables_included="$table_included"
          tables_included_params="--table=$table_included"
        else
          tables_included="${tables_included}, ${table_included}"
          tables_included_params="${tables_included_params} --table=${table_included}"
        fi
      done

      break

    done

    BACKUPFILE="${backuppath}/${database}-$(date '+%Y%m%d%H%M%S').tar"

    print "Running pg_dump of ${database} for ${PGHOST} to backupfile ${BACKUPFILE}..."

    print "Tables included for ${database}: ${tables_included}"
    print "Tables excluded for ${database}: ${tables_excluded}"

    PGPASSWORD=${PGPASSWORD} pg_dump -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSERNAME}" -d "${database}" -F tar ${tables_included_params} ${tables_excluded_params} > "${BACKUPFILE}"
    if [ $? -ne 0 ]; then
      error "pg_dump for ${database} on ${PGHOST} to backupfile ${BACKUPFILE} failed."
      rm -f "${BACKUPFILE}"
      result=1
      continue
    fi

    if ! [ -f "${BACKUPFILE}" ]; then
      error "Backupfile ${BACKUPFILE} missing for ${database} on ${PGHOST}."
      rm -f "${BACKUPFILE}"
      result=1
      continue
    fi

    size=$(wc -c "${BACKUPFILE}" | cut -d ' ' -f 1)
    if [ $? -ne 0 ]; then
      error "Could not get filesize for backupfile ${BACKUPFILE} of ${database} on ${PGHOST}."
      rm -f "${BACKUPFILE}"
      result=1
      continue
    fi

    if [ -z "${size}" ] || ! [ "${size}" -eq "${size}" ] 2>/dev/null; then
      error "Invalid filesize for backupfile ${BACKUPFILE} of ${database} on ${PGHOST}"
      rm -f "${BACKUPFILE}"
      result=1
      continue
    fi

    if [ "${size}" -lt 10 ]; then
      error "Backupfile ${BACKUPFILE} of ${database} on ${PGHOST} too small (${size} bytes)."
      rm -f "${BACKUPFILE}"
      result=1
      continue
    fi

    print "Backup of ${database} on ${PGHOST} to file Backupfile ${BACKUPFILE} is successful."

    print "BZipping ${BACKUPFILE}..."

    bzip2 "${BACKUPFILE}"
    if [ $? -eq 0 ]; then
      BACKUPFILE="${BACKUPFILE}.bz2"
    else
      result=1
    fi

    print "Backup of ${database} on ${PGHOST} to file Backupfile ${BACKUPFILE} complete"

  done

done


if ! [ "${result}" = "" ]; then
  exit ${result}
fi
