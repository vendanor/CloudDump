#!/bin/sh

current_dir=$(dirname $0)

azcopy_latest_version="$(wget -q -O- 'https://github.com/Azure/azure-storage-azcopy/releases' | sed -n 's,.*releases/tag/\([^"&;]*\)".*,\1,p' | grep -v '^preview' | sed 's/^v//g' | sort -V | tail -1)"
if [ ${azcopy_latest_version} = "" ]; then
  echo "Failed to get latest azcopy version."
  exit 1
fi

azcopy_latest_date="$(wget -q -O- 'https://github.com/Azure/azure-storage-azcopy/releases' | sed -n 's,.*datetime=\"\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z\">.*,\1,p' | sed 's/\-//g' | sort | tail -1)"
if [ ${azcopy_latest_date} = "" ]; then
  echo "Failed to get latest azcopy date."
  exit 1
fi

azcopy_filename="azcopy_linux_amd64_${azcopy_latest_version}.tar.gz"
azcopy_url="https://azcopyvnext.azureedge.net/release${azcopy_latest_date}/${azcopy_filename}"
azcopy_install="${current_dir}/../scripts/azcopy-install.sh"

azcopy_current_version=$(cat "${azcopy_install}" | sed -n "s,^azcopy_version=\"\(.*\)\"\$,\1,p")
azcopy_current_date=$(cat "${azcopy_install}" | sed -n "s,^azcopy_date=\"\(.*\)\"\$,\1,p")

if [ "${azcopy_latest_version}" = "${azcopy_current_version}" ] && [ "${azcopy_latest_date}" = "${azcopy_current_date}" ]; then
  echo "Have latest version ${azcopy_current_version} (${azcopy_current_date})"
else
  echo "Updating from version ${azcopy_current_version} (${azcopy_current_date}) to ${azcopy_latest_version} (${azcopy_latest_date})"
  sed -i "s/azcopy_version=\".*\"/azcopy_version=\"${azcopy_latest_version}\"/g" "${azcopy_install}"
  sed -i "s/azcopy_date=\".*\"/azcopy_date=\"${azcopy_latest_date}\"/g" "${azcopy_install}"
fi
