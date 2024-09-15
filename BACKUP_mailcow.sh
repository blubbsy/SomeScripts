#!/bin/sh

# Backup mailcow data
# https://docs.mailcow.email/backup_restore/b_n_r-backup/

set -e

OUT="$(mktemp)"
export MAILCOW_BACKUP_LOCATION="/backup/mailcow"
SCRIPT="/opt/mailcow-dockerized/helper-scripts/backup_and_restore.sh"
PARAMETERS="backup all"
OPTIONS="--delete-days 30"
CURRENT_DATE=$(date +"%Y-%m-%d")

# Nextcloud credentials and rclone remote
NEXTCLOUD_REMOTE="Nextcloud:/Backups/mailcow"  # Replace with your rclone Nextcloud remote
RCLONE_LOG_FILE="/var/log/rclone_mailcow-$CURRENT_DATE.log"  # Log file with current date

# run backup command
set +e
"${SCRIPT}" ${PARAMETERS} ${OPTIONS} 2>&1 > "$OUT"
RESULT=$?

if [ $RESULT -ne 0 ]; then
    echo "${SCRIPT} ${PARAMETERS} ${OPTIONS} encounters an error:"
    echo "RESULT=$RESULT"
    echo "STDOUT / STDERR:"
    cat "$OUT"
    exit 1
fi

# Upload to Nextcloud using rclone
echo "Uploading backup to Nextcloud..."
rclone copy "$MAILCOW_BACKUP_LOCATION" "$NEXTCLOUD_REMOTE" --log-file="$RCLONE_LOG_FILE" --log-level INFO

RCLONE_RESULT=$?
if [ $RCLONE_RESULT -ne 0 ]; then
    echo "Failed to upload backup to Nextcloud. Check rclone log: $RCLONE_LOG_FILE"
    exit 1
fi

echo "Backup uploaded to Nextcloud successfully."

# Optional: Clean up old backups from Nextcloud (older than 30 days)
echo "Cleaning up old backups in Nextcloud..."
rclone delete "$NEXTCLOUD_REMOTE" --min-age 30d --log-file="$RCLONE_LOG_FILE" --log-level INFO

CLEANUP_RESULT=$?
if [ $CLEANUP_RESULT -ne 0 ]; then
    echo "Failed to clean up old backups in Nextcloud. Check rclone log: $RCLONE_LOG_FILE"
    exit 1
fi

echo "Old backups cleaned up successfully."

# Clean up temporary file
rm "$OUT"
