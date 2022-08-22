#!/bin/bash

# Vendanor AzDump Script
# This script runs azcopy sync
# Usage: azdump.sh <jobid>


CONFIGFILE="/config/config.json"
#CONFIGFILE="${HOME}/Projects/Vendanor/VnCloudDump/config/config.json"

JOBID="${1}"


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


# Init

print "Vendanor AzDump ($0)"


# Check commands

cmds="which sed date touch mkdir cp rm azcopy"
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


# Backup each blob storage

bs_count=$(jq -r ".jobs[${job_idx}].blobstorages | length" "${CONFIGFILE}")
if [ "${bs_count}" = "" ] || [ -z "${bs_count}" ] || ! [ "${bs_count}" -eq "${bs_count}" ] 2>/dev/null; then
  error "Can't read blobstorages from Json configuration."
  exit 1
fi

if [ "${bs_count}" -eq 0 ]; then
  error "No blobstorages for ${JOBID} in Json configuration."
  exit 1
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


  print "Source: ${source}"
  print "Destination: ${destination}"


  # Validate source and destination

  echo "${source}" | grep "^https:\/\/.*" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    error "Invalid source for job index ${job_idx} ID ${JOBID}."
    result=1
    continue
  fi


  # Create directory

  print "Creating directory for destination ${destination}"

  mkdir -p "${destination}"
  if [ $? -ne 0 ]; then
    error "Could not create directory ${destination}"
    result=1
    continue
  fi


  # Check permissions

  print "Checking permission for destination ${destination}"

  touch "${destination}/TEST_FILE"
  if [ $? -ne 0 ]; then
    error "Could not access ${destination} for job index ${job_idx} ID ${JOBID}."
    result=1
    continue
  fi

  rm -f "${destination}/TEST_FILE"


  # Run azcopy

  print "Syncing source ${source} to destination ${destination}..."

  azcopy sync --recursive "${source}" "${destination}"
  if [ ${?} -ne 0 ]; then
    error "Sync from source ${source} to destination ${destination} failed for job index ${job_idx} ID ${JOBID}."
    result=1
  fi

done


if ! [ "${result}" = "" ]; then
  exit ${result}
fi
