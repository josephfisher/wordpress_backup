#!/bin/bash
#
# title           :Wordpress Backup Script
# description     :This script will make a backup of a wordpress site, upload
#                 :via FTPS, and email a contact if any part of this fails.
# author          :Joseph Fisher, jpf@josephfisher.us
# date            :2013-08-08
# version         :1.0.1
# usage           :bash wordpress_backup.sh
# notes           :Modify the environment variables listed below to suit your
#                 :enviornment, requirements, etc.
# dependencies    :MySQL, Wordpress, lftp (lftp.yar.ru), mailx, mkdir, mv, echo
#                 :tar, rm, mysqldump
# License         :Copyright (C) 2013 Joseph Fisher
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
#==============================================================================
# ADJUST THESE VARIABLES BEFORE RUNNING THIS SCRIPT
#==============================================================================
#
# Default values are listed as commented out lines
# and based on a Red Hat / CentOS environment
#
# MySQL Database Account Info:
DB_USER="username"
DB_PASS="password"
#
# Provide your MySQL Database Name:
DB_NAME="database_name"
#
# Leave this as "localhost" unless you're running this script
# from a remote system
# DB_HOST="localhost"
DB_HOST="localhost"
#
# This is the path to your wordpress website's directory
# WWW_DIR="/var/www/html"
WWW_DIR="/var/www/html"
#
# This is the info of the person who will be contacted if the backup fails
EMAIL_ALERT_ADDR="email@domain"
EMAIL_FROM_ADDR="backups@myserver"
#
#
# FTPS Server and login details
FTPS_SERVER="ftp.somehost.somewhere"
#FTPS_PORT="990"
FTPS_PORT="990"
FTPS_USER="username"
FTPS_PASSWORD="password"
FTPS_REMOTE_DIR="remote_dir"
#
# This will be part of the subject line of alert emails.
# Avoid special characters and keep it short for your comfort.
SERVER_NAME="servername"
#
# This is the directory where backups will be stored locally temporarily.
# BACKUP_DIRECTORY="/var/backups"
BACKUP_DIRECTORY="/var/backups"
#
# How many days should we archive the backups locally?
# (Note that this is not on the remote FTPS server)
LOCAL_BKUP_DAYS="5"
# Note that if we fail any step prior to the FTPS upload, this script will NOT
# clean up old files in your backup directory.
#
#==============================================================================
# These settings may only need to be changed if you have an oddball environment
#==============================================================================
# This is the location of lftp
LFTP="/usr/bin/lftp"
#
# This is the location of tar
TAR="/bin/tar"
#
# This is the location of MySQLDump
MYSQLDUMP="/usr/bin/mysqldump"
#
# This is the location of the mailx application
MAIL="/bin/mail"
#
# This is the location of mkdir
MKDIR="/bin/mkdir"
#
# This is the location of echo
ECHO="/bin/echo"
#
# This is the lcoation of RM
RM="/bin/rm"
#
#==============================================================================
# DO NOT MODIFY BELOW THIS LINE
#==============================================================================
NOW=$(date +"%Y-%m-%d-%H%M")
TREE_FILE="${NOW}.tar.gz"
DB_FILE="${DB_NAME}.${NOW}.sql.tar.gz"
BACKUP_SUBDIR="${NOW}"
#==============================================================================
# And now, onto the script itself
#==============================================================================
# First, let's make a short and sweet file that will be the contents of the email that is generated upon failure.
${ECHO} "Sorry to report that your backup has failed." > /tmp/message.txt
#
#
# Let's make a directory to hold on to the backups.
${MKDIR} -p ${BACKUP_DIRECTORY}/${BACKUP_SUBDIR}
#
# Now, let's tar up your web site and put it in your backups directory
${TAR} -czvf ${BACKUP_DIRECTORY}/${BACKUP_SUBDIR}/${TREE_FILE} ${WWW_DIR}
#
# If the tar failed, email your contact
if [ $? -ne 0 ];
then
${MAIL} -r ${EMAIL_FROM_ADDR} -s "${SERVER_NAME} Failed to TAR your Web Directory for your Backup Job" ${EMAIL_ALERT_ADDR} < /tmp/message.txt
exit 1
fi
#
#
# Now, we'll do a MySQL Dump of your Database and temporarily put it in tmp
${MYSQLDUMP} -h${DB_HOST} -u${DB_USER} -p${DB_PASS} ${DB_NAME} > /tmp/$DB_NAME
#
# If the MySQL Dump failed, email your contact
if [ $? -ne 0 ];
then
${MAIL} -r ${EMAIL_FROM_ADDR} -s "${SERVER_NAME} Failed to create a MySQL Dump for your Backup Job" ${EMAIL_ALERT_ADDR} < /tmp/message.txt
exit 2
fi
#
#
# Now, we'll crunch down the SQL dump and put it in your backup folder
${TAR} -czvf ${BACKUP_DIRECTORY}/${BACKUP_SUBDIR}/${DB_FILE} /tmp/$DB_NAME
#
# If the tar failed, email your contact
if [ $? -ne 0 ];
then
${MAIL} -r ${EMAIL_FROM_ADDR} -s "${SERVER_NAME} Failed to TAR your MySQL Backup" ${EMAIL_ALERT_ADDR} < /tmp/message.txt
exit 3
fi
#
#
# Using LFTP, we'll upload the backup that we just created to your FTPS server
${LFTP} -e "mirror -R ${BACKUP_DIRECTORY} /${FTPS_REMOTE_DIR}" -u ${FTPS_USER},${FTPS_PASSWORD} ${FTPS_SERVER}:${FTPS_PORT} << EOF
quit
EOF
#
# If the upload failed, email your contact
if [ $? -ne 0 ];
then
${MAIL} -r ${EMAIL_FROM_ADDR} -s "${SERVER_NAME} Failed to Upload your Backup to ${FTPS_SERVER}" ${EMAIL_ALERT_ADDR} < /tmp/message.txt
fi
#
#
find ${BACKUP_DIRECTORY} -mtime +"${LOCAL_BKUP_DAYS}" -exec ${RM} -rf {} \;
#
#
${RM} /tmp/$DB_NAME
${RM} /tmp/message.txt
exit 0
