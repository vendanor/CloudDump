#!/bin/sh

azcopy_version="10.17.0"
azcopy_date="20230123"

azcopy_filename="azcopy_linux_amd64_${azcopy_version}.tar.gz"
azcopy_url="https://azcopyvnext.azureedge.net/release${azcopy_date}/${azcopy_filename}"

cd /tmp || exit 1
curl -O -L "${azcopy_url}" || exit 1
tar -xf "${azcopy_filename}" || exit 1
rm "${azcopy_filename}" || exit 1
mv $(ls -1 azcopy_linux_*/azcopy | tail -1) /usr/bin || exit 1
rm -rf azcopy_linux_* || exit 1
