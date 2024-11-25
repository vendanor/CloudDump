#!/bin/sh

azcopy_version="10.27.1"
azcopy_date="20241113"

azcopy_filename="azcopy_linux_amd64_${azcopy_version}.tar.gz"
azcopy_url="https://azcopyvnext.azureedge.net/releases/release-${azcopy_version}-${azcopy_date}/${azcopy_filename}"

curl -f -O -L --output-dir "/tmp" "${azcopy_url}" || exit 1
tar -C /tmp -xf "/tmp/${azcopy_filename}" || exit 1
rm "/tmp/${azcopy_filename}" || exit 1
mv $(ls -1 /tmp/azcopy_linux_*/azcopy | tail -1) /usr/bin || exit 1
rm -rf /tmp/azcopy_linux_* || exit 1
