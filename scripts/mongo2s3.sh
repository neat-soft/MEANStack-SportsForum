#!/bin/sh

# Minimal script for backing up a MongoDB database to Amazon S3
# Uses
# - mongodump
# - sendEmail
# - s3cmd

# Configuration
EMAIL_SERVER=
EMAIL_USER=
EMAIL_PASS=
EMAIL_TO=
EMAIL_FROM=
MONGO_HOST=
MONGO_USER=
MONGO_PASS=
MONGO_DB_NAME=
AWS_BUCKET=

DATE=`date +%Y_%m_%d_%H_%M_%S`

mongodump --host ${MONGO_HOST} --db ${MONGO_DB_NAME} -u ${MONGO_USER} -p${MONGO_PASS} -o ./${MONGO_DB_NAME}_${DATE} >>./log_$DATE 2>&1 && \
tar -zcvf ${MONGO_DB_NAME}_${DATE}.tar.gz ${MONGO_DB_NAME}_${DATE} >>./log_$DATE 2>&1 && \
s3cmd put ${MONGO_DB_NAME}_${DATE}.tar.gz s3://${AWS_BUCKET}/${MONGO_DB_NAME}_${DATE}.tar.gz >>./log_$DATE 2>&1 && \
# s3cmd does not return a non-zero code when it fails to upload, therefore we check if the file exists on s3
s3cmd info s3://${AWS_BUCKET}/${MONGO_DB_NAME}_${DATE}.tar.gz >>./log_$DATE 2>&1
EXITVALUE=$?
NOW=`date +%Y_%m_%d_%H_%M_%S`
if [ $EXITVALUE != 0 ]; then
  sendEmail -f ${EMAIL_FROM} \
          -t ${EMAIL_TO} \
          -u "ERROR backing up production db to S3 on ${NOW}" \
          -m "ERROR!\nStarted: ${DATE}\nFinished: ${NOW}" \
          -s ${EMAIL_SERVER} \
          -o username=${EMAIL_USER} \
          -o password=${EMAIL_PASS} \
          -o tls=yes
  /usr/bin/logger -t mongo2s3 "ERROR backing up production db to S3 [$EXITVALUE]"
else
  sendEmail -f ${EMAIL_FROM} \
          -t ${EMAIL_TO} \
          -u "SUCCESSFULLY backed up production db to S3 on ${NOW}" \
          -m "SUCCESS!\nStarted: ${DATE}\nFinished: ${NOW}" \
          -s ${EMAIL_SERVER} \
          -o username=${EMAIL_USER} \
          -o password=${EMAIL_PASS} \
          -o tls=yes
  # rm ${MONGO_DB_NAME}_${DATE}.tar.gz
  rm -rf ${MONGO_DB_NAME}_${DATE}
fi
