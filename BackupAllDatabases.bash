#!/usr/bin/env bash

MYSQL_CLIENT_CONFIG=/var/scripts/credentials/mysqlBackup.cnf
BACKUP_TMP_FOLDER="/tmp/SQL_Backup-$(date +'%F_%T')"
OUTPUT_DIR=/mnt/nfs_backups/mysql

# How many days should we keep backups?
DAYS_TO_KEEP_BACKUPS="365"

createBackupDirectory() {
	# Create and Add backups to new folder
	echo "Creating temp directory $BACKUP_TMP_FOLDER"
	mkdir $BACKUP_TMP_FOLDER
    chmod 700 $BACKUP_TMP_FOLDER
}

checkNfsMount() {
	local isNfsMounted=$(mount -l | grep "/mnt/nfs_backups" | wc -l)
	if [ $isNfsMounted -eq 0 ]; then
		echo "NFS is not mounted, trying to mount now..."
		mount /mnt/nfs_backups

		if [ $? -ne 0 ]; then
			echo "Failed to mount NFS mount. Exiting..."
			exit 1
		fi
	else
		echo "NFS is mounted"
	fi
}

cleanUpBackupDirectory() {
	echo "Removing temp directory"
	rm -rf $BACKUP_TMP_FOLDER "$BACKUP_TMP_FOLDER.zip"
}

cleanUpOldBackups() {
	echo "Removing any backups older than $DAYS_TO_KEEP_BACKUPS days"
	find $OUTPUT_DIR/SQL_Backup-* -mtime +$DAYS_TO_KEEP_BACKUPS -exec rm {} \;
	echo "Done"
}

backup() {
	local databaseName=$1

	echo "Backing up $databaseName"
	mysqldump --defaults-extra-file=$MYSQL_CLIENT_CONFIG --routines $databaseName > $BACKUP_TMP_FOLDER/$databaseName.sql

	if [ $? -ne 0 ]; then
		echo "Error backing up $databaseName"
		cleanUpBackupDirectory
		exit 1
	fi

	echo "Backup of $databaseName complete!"
}

package() {
	echo "Packaging backed up databases"
	zip -rq "$BACKUP_TMP_FOLDER.zip" $BACKUP_TMP_FOLDER
	echo "Files zipped in $BACKUP_TMP_FOLDER.zip"
}

copyToNfs() {
	cp "$BACKUP_TMP_FOLDER.zip" $OUTPUT_DIR
}

###########################
# Actual work is done here!
###########################
echo "MySQL Backup Starting"

checkNfsMount

# Setup folder
createBackupDirectory

# Run backups
backup "TWPI_Modpack_Servers"
backup "TWPI_Website"
backup "Window_Controller_Website"

# Zip contents
package

# Save package to NFS backup drive
copyToNfs

# Clean up
cleanUpBackupDirectory
cleanUpOldBackups

echo "MySQL Backup Done!"

