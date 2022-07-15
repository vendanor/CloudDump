#!/bin/sh

cd /tmp || exit 1
curl -O -L 'https://aka.ms/downloadazcopy-v10-linux' || exit 1
tar -xf "downloadazcopy-v10-linux" || exit 1
rm "downloadazcopy-v10-linux" || exit 1
mv $(ls -1 azcopy_linux_*/azcopy | tail -1) /usr/bin || exit 1
rm -rf azcopy_linux_* || exit 1
