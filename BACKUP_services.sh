#!/bin/bash

# Variablen setzen
BACKUP_DIR="/backup/backup_services"  # Verzeichnis für lokale Backups
# OLD, because changed to locally move it
#NEXTCLOUD_REMOTE="Nextcloud:/Backups/VPS"  # rclone remote Name für Nextcloud
NEXTCLOUD_OCC_PATH="/var/www/adrilaida.de/nextcloud/occ"
NEXTCLOUD_DATA_PATH="/backup/nextcloud_data/devsibwarra/files/Backups/VPS"
NEXTCLOUD_UPLOAD_PATH="/devsibwarra/files/Backups"
DATE=$(date +"%Y-%m-%d")  # Datum im Format YYYY-MM-DD
BACKUP_NAME="backup-$DATE.tar.gz"

# Verzeichnis erstellen
echo "[INFO] Erstelle Backup Verzeichnis: $BACKUP_DIR/$DATE"
mkdir -p "$BACKUP_DIR/$DATE"

# MariaDB Backup erstellen
echo "[INFO] Erstelle MariaDB Backup..."
mariabackup --backup --target-dir "$BACKUP_DIR/$DATE/mariadb" && \
echo "[SUCCESS] MariaDB Backup erstellt: $BACKUP_DIR/$DATE/mariadb.sql" || \
echo "[ERROR] Fehler beim Erstellen des MariaDB Backups."

# NGINX Konfiguration sichern
echo "[INFO] Sichere NGINX Konfiguration..."
cp -vr /etc/nginx "$BACKUP_DIR/$DATE/nginx" && \
echo "[SUCCESS] NGINX Konfiguration gesichert: $BACKUP_DIR/$DATE/nginx" || \
echo "[ERROR] Fehler beim Sichern der NGINX Konfiguration."

# Webserver-Verzeichnisse sichern: adrilaida.de
echo "[INFO] Sichere Webserver Verzeichnisse..."
mkdir -p "$BACKUP_DIR/$DATE/webscontent/adrilaida.de"
cp -vr /var/www/adrilaida.de "$BACKUP_DIR/$DATE/webscontent/adrilaida.de" && \
echo "[SUCCESS] Webserver Verzeichnisse gesichert: $BACKUP_DIR/$DATE/webserver" || \
echo "[ERROR] Fehler beim Sichern der Webserver Verzeichnisse."

# Webserver-Verzeichnisse sichern: picnotes.de
echo "[INFO] Sichere Webserver Verzeichnisse..."
mkdir -p "$BACKUP_DIR/$DATE/webcontent/picnotes.de"
cp -vr /var/www/picnotes.de "$BACKUP_DIR/$DATE/webcontent/picnotes.de" && \
echo "[SUCCESS] Webserver Verzeichnisse gesichert: $BACKUP_DIR/$DATE/webserver" || \
echo "[ERROR] Fehler beim Sichern der Webserver Verzeichnisse."

# Docker Container und Images auflisten
echo "[INFO] Erstelle Liste der Docker Container..."
docker ps -a > "$BACKUP_DIR/$DATE/docker-containers.txt" && \
echo "[SUCCESS] Docker Container Liste erstellt: $BACKUP_DIR/$DATE/docker-containers.txt" || \
echo "[ERROR] Fehler beim Erstellen der Docker Container Liste."

echo "[INFO] Erstelle Liste der Docker Images..."
docker images > "$BACKUP_DIR/$DATE/docker-images.txt" && \
echo "[SUCCESS] Docker Images Liste erstellt: $BACKUP_DIR/$DATE/docker-images.txt" || \
echo "[ERROR] Fehler beim Erstellen der Docker Images Liste."

# IPTables sichern
echo "[INFO] Sichere IPTables..."
iptables-save > "$BACKUP_DIR/$DATE/iptables.conf" && \
echo "[SUCCESS] IPTables gesichert: $BACKUP_DIR/$DATE/iptables.conf" || \
echo "[ERROR] Fehler beim Sichern der IPTables."

# PHP Konfiguration sichern
echo "[INFO] Sichere PHP Konfiguration..."
cp -vr /etc/php "$BACKUP_DIR/$DATE/php" && \
echo "[SUCCESS] PHP Konfiguration gesichert: $BACKUP_DIR/$DATE/php" || \
echo "[ERROR] Fehler beim Sichern der PHP Konfiguration."

# Liste der installierten PHP-Pakete sichern
echo "[INFO] Erstelle Liste der installierten PHP-Pakete..."
dpkg -l | grep php > "$BACKUP_DIR/$DATE/php-packages.txt" && \
echo "[SUCCESS] PHP Pakete Liste erstellt: $BACKUP_DIR/$DATE/php-packages.txt" || \
echo "[ERROR] Fehler beim Erstellen der PHP Pakete Liste."

# Cronjobs sichern
echo "[INFO] Sichere Cronjobs..."
crontab -l > "$BACKUP_DIR/$DATE/cronjobs.txt" && \
echo "[SUCCESS] Cronjobs gesichert: $BACKUP_DIR/$DATE/cronjobs.txt" || \
echo "[ERROR] Fehler beim Sichern der Cronjobs."

cp /etc/crontab "$BACKUP_DIR/$DATE/crontab" && \
echo "[SUCCESS] Systemweite Crontab gesichert: $BACKUP_DIR/$DATE/crontab" || \
echo "[ERROR] Fehler beim Sichern der systemweiten Crontab."

cp -vr /etc/cron.* "$BACKUP_DIR/$DATE/" && \
echo "[SUCCESS] Systemweite Cronjob-Verzeichnisse gesichert." || \
echo "[ERROR] Fehler beim Sichern der systemweiten Cronjob-Verzeichnisse."

# Backup verpacken und bestimmte Dateitypen ausschließen
echo "[INFO] Packe Backup, schließe bestimmte Dateitypen aus..."
tar -cvzf "$BACKUP_DIR/$BACKUP_NAME" \
    --exclude='*.jpg' --exclude='*.jpeg' \
    --exclude='*.mp3' --exclude='*.wav' --exclude='*.ogg' \
    --exclude='*.mp4' --exclude='*.mkv' --exclude='*.avi' \
    -C "$BACKUP_DIR" "$DATE" && \
echo "[SUCCESS] Backup verpackt: $BACKUP_NAME" || \
echo "[ERROR] Fehler beim Verpacken des Backups."

# Rclone: Backup zu Nextcloud hochladen
echo "[INFO] Lade Backup zu Nextcloud hoch..."
#rclone copy -v "$BACKUP_DIR/$BACKUP_NAME" "$NEXTCLOUD_REMOTE"
mv "$BACKUP_DIR/$BACKUP_NAME" "$NEXTCLOUD_DATA_PATH"
chown -R www-data "$NEXTCLOUD_DATA_PATH"
sudo -u www-data php "$NEXTCLOUD_OCC_PATH" files:scan --path="$NEXTCLOUD_UPLOAD_PATH"

# Überprüfen, ob der Upload erfolgreich war
if [ $? -eq 0 ]; then
    echo "[SUCCESS] Upload erfolgreich, lösche lokale Dateien..."
    rm -rf "$BACKUP_DIR/$DATE"
else
    echo "[ERROR] Upload fehlgeschlagen, lokale Dateien werden nicht gelöscht."
fi

# Optional: Alte lokale Backups löschen (z.B. älter als 7 Tage)
echo "[INFO] Lösche alte lokale Backups (älter als 7 Tage)..."
find "$BACKUP_DIR" -type f -mtime +7 -name "*.tar.gz" -exec rm -v {} \;

echo "[INFO] Backup abgeschlossen."
