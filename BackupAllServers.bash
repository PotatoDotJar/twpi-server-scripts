#!/usr/bin/env bash

AMP_INSTANCE_DIR="/home/amp/.ampdata/instances"
BACKUP_TMP_FOLDER="/tmp/TWPI_Server_Backup-$(date +'%F_%T')"
OUTPUT_DIR=/mnt/nfs_backups/servers

# How many days should we keep backups?
DAYS_TO_KEEP_BACKUPS="60"

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
	find $OUTPUT_DIR/TWPI_Server_Backup-* -mtime +$DAYS_TO_KEEP_BACKUPS -exec rm {} \;
	echo "Done"
}

backup() {
	local serverInstanceName=$1

	echo "Backing up $serverInstanceName"
	# mysqldump --defaults-extra-file=$MYSQL_CLIENT_CONFIG --routines $serverInstanceName > $BACKUP_TMP_FOLDER/$serverInstanceName.sql

	local instanceBackupFolder=$BACKUP_TMP_FOLDER/$serverInstanceName
	mkdir $instanceBackupFolder

	# Find world, config, and mods folder, otherwise backup whole dir
	local mcFoldersCount=$(find $AMP_INSTANCE_DIR/$serverInstanceName -maxdepth 2 \( -name "world" -o -name "config" -o -name "mods" \) | wc -l)

	if [ $mcFoldersCount -eq 0 ]; then
		echo "No Minecraft folders found, backing up as a directory"
		# Not an MC dir, backup whole dir
		cp -r $AMP_INSTANCE_DIR/$serverInstanceName/* $instanceBackupFolder
	else
		echo "Minecraft folders found, backing up as Minecraft server"
		# This is a MC folder, backup mc world, config, and mods folders
		find "$AMP_INSTANCE_DIR/$serverInstanceName" -maxdepth 2 \( -name "world" -o -name "config" -o -name "mods" \) -exec cp -r {} $instanceBackupFolder \;
	fi

	if [ $? -ne 0 ]; then
		echo "Error backing up $serverInstanceName. Skipping..."
	else
		echo "Backup of $serverInstanceName complete!"
	fi
}

package() {
	echo "Packaging backed up servers"
	zip -rq "$BACKUP_TMP_FOLDER.zip" $BACKUP_TMP_FOLDER
	echo "Files zipped in $BACKUP_TMP_FOLDER.zip"
}

copyToNfs() {
	cp "$BACKUP_TMP_FOLDER.zip" $OUTPUT_DIR
}

###########################
# Actual work is done here!
###########################
echo "TWPI Server Backup Starting"

checkNfsMount

# Setup folder
createBackupDirectory

# Run backups for instances, these are the folder names in $AMP_INSTANCE_DIR
backup "ATM6"
backup "GreedyCraft"
backup "Direwolf20"
backup "GTNewHorizons"
backup "MCEternal"
backup "Vanilla"
backup "FTBInteractions"
backup "Valheim01"
backup "Skyfactory4"

# Zip contents
package

# Save package to NFS backup drive
copyToNfs

# Clean up
cleanUpBackupDirectory
cleanUpOldBackups

echo "TWPI Server Backups Done!"

