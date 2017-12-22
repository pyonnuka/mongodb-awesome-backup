#!/bin/bash -e

# settings
BACKUPFILE_PREFIX=${BACKUPFILE_PREFIX:-backup}
MONGODB_HOST=${MONGODB_HOST:-mongo}
#MONGODB_DBNAME=
#MONGODB_USERNAME=
#MONGODB_PASSWORD=
#MONGODB_AUTHDB=
#MONGODUMP_OPTS=
#S3_TARGET_BUCKET_URL=s3://...

DELETE_DEVIDE=${DELETE_DEVIDE:-3}
DELETE_TARGET_DAYS_LEFT=${DELETE_TARGET_DAYS_LEFT:-4}

# start script
CWD=`/usr/bin/dirname $0`
cd $CWD

. ./s3-functions.sh
TODAY=`create_today_yyyymmdd`
PAST=`create_past_yyyymmdd ${DELETE_TARGET_DAYS_LEFT}`

echo "=== $0 started at `/bin/date "+%Y/%m/%d %H:%M:%S"` ==="

TMPDIR="/tmp"
TARGET_DIRNAME="mongodump"
TARGET="${TMPDIR}/${TARGET_DIRNAME}"
TAR_CMD="/bin/tar"
TAR_OPTS="jcvf"

DIRNAME=`/usr/bin/dirname ${TARGET}`
BASENAME=`/usr/bin/basename ${TARGET}`
TARBALL="${BACKUPFILE_PREFIX}-${TODAY}.tar.bz2"
TARBALL_FULLPATH="${TMPDIR}/${TARBALL}"


# check parameters
if [ "x${S3_TARGET_BUCKET_URL}" == "x" ]; then
  echo "ERROR: The environment variable S3_TARGET_BUCKET_URL must be specified." 1>&2
  exit 1
fi

# dump database
if [ "x${MONGODB_DBNAME}" != "x" ]; then
  MONGODUMP_OPTS="${MONGODUMP_OPTS} -d ${MONGODB_DBNAME}"
fi
if [ "x${MONGODB_USERNAME}" != "x" ]; then
  MONGODUMP_OPTS="${MONGODUMP_OPTS} -u ${MONGODB_USERNAME} -p ${MONGODB_PASSWORD}"
fi
if [ "x${MONGODB_AUTHDB}" != "x" ]; then
  MONGODUMP_OPTS="${MONGODUMP_OPTS} --authenticationDatabase ${MONGODB_AUTHDB}"
fi
echo "dump MongoDB..."
mongodump -h ${MONGODB_HOST} -o ${TARGET} ${MONGODUMP_OPTS}

# run tar command
echo "backup ${TARGET}..."
time ${TAR_CMD} ${TAR_OPTS} ${TARBALL_FULLPATH} -C ${DIRNAME} ${BASENAME}
# transfer tarball to Amazon S3
s3_put_file ${TARBALL_FULLPATH} ${S3_TARGET_BUCKET_URL}

# delete tarball if upload was successfully over
delete_localfile_if_exists_on_s3 ${TARBALL} ${TMPDIR} ${S3_TARGET_BUCKET_URL}

# check the existence of past file 
# if it exists, delete it
TARBALL_PAST="${BASENAME}-${PAST}.tar.bz2"
s3_delete_file_if_delete_backup_day ${S3_TARGET_BUCKET_URL}/${TARBALL_PAST} ${DELETE_TARGET_DAYS_LEFT} ${DELETE_DEVIDE}