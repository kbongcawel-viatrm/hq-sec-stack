#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: restore-volume.sh <volume-name> <archive.tar.gz>" >&2
  echo "example: docker run --rm -v hq-sec-stack_graylog-data:/restore -v ./backups:/backups alpine sh /The Hands/backup/scripts/restore-volume.sh graylog-data /The Hands/backups/20260502T000000Z/graylog-data.tar.gz" >&2
  exit 2
fi

volume_name="$1"
archive="$2"

echo "Restoring ${archive} into ${volume_name} mounted at /restore"
find /restore -mindepth 1 -maxdepth 1 -exec rm -rf {} +
tar -xzf "${archive}" -C /restore
echo "Restore complete"

