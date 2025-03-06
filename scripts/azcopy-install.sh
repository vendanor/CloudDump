#!/bin/sh

azcopy_url="https://azcopyvnext-awgzd8g7aagqhzhe.b02.azurefd.net/releases/release-10.28.0-20250127/azcopy_linux_amd64_10.28.0.tar.gz"

curl -f -O -L --output-dir "/tmp" "${azcopy_url}" || exit 1
tar -C /tmp -xf "/tmp/${azcopy_filename}" || exit 1
rm "/tmp/${azcopy_filename}" || exit 1
mv $(ls -1 /tmp/azcopy_linux_*/azcopy | tail -1) /usr/bin || exit 1
rm -rf /tmp/azcopy_linux_* || exit 1
