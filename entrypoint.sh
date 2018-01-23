#!/bin/sh
set -e

: "${GPG_PRIVATE_KEY_FILE_PATH:?needs to be set}"
: "${WALE_GPG_KEY_ID:?needs to be set}"
: "${AWS_ACCESS_KEY_ID:?needs to be set}"
: "${AWS_SECRET_ACCESS_KEY:?needs to be set}"
: "${AWS_REGION:?needs to be set}"
: "${WALE_S3_PREFIX:?needs to be set}"
: "${PITR_RECOVERY_TARGET_TIME:?needs to be set}"

umask u=rwx,g=rx,o=
mkdir -p /etc/wal-e.d/env

echo "$WALE_GPG_KEY_ID" > /etc/wal-e.d/env/WALE_GPG_KEY_ID
echo "$AWS_SECRET_ACCESS_KEY" > /etc/wal-e.d/env/AWS_SECRET_ACCESS_KEY
echo "$AWS_ACCESS_KEY_ID" > /etc/wal-e.d/env/AWS_ACCESS_KEY_ID
echo "$WALE_S3_PREFIX" > /etc/wal-e.d/env/WALE_S3_PREFIX
echo "$AWS_REGION" > /etc/wal-e.d/env/AWS_REGION
chown -R root:postgres /etc/wal-e.d

# Ensure we have gpg private key imported for WAL fetching to work
if [ -f "${GPG_PRIVATE_KEY_FILE_PATH}" ]; then
  su-exec postgres gpg --batch --no-tty --yes --import "${GPG_PRIVATE_KEY_FILE_PATH}"
  su-exec postgres touch /tmp/dump.txt
  su-exec postgres gpg --batch --no-tty --yes -e -r ${WALE_GPG_KEY_ID} --trusted-key ${WALE_GPG_KEY_ID} /tmp/dump.txt
  su-exec postgres rm -f /tmp/dump.txt /tmp/dump.txt
else
  echo "GPG Private key not found at: ${GPG_PRIVATE_KEY_FILE_PATH}"
  exit 1
fi

# Write the recovery.conf file
rm -f ${PGDATA}/recovery.conf
su-exec postgres touch ${PGDATA}/recovery.conf
echo "standby_mode = 'on'" >> ${PGDATA}/recovery.conf
echo "restore_command = 'envdir /etc/wal-e.d/env wal-e wal-fetch %f %p'" >> ${PGDATA}/recovery.conf
echo "recovery_target_time = '${PITR_RECOVERY_TARGET_TIME}'" >> ${PGDATA}/recovery.conf
echo "recovery_target_action = 'pause'" >> ${PGDATA}/recovery.conf
echo "max_connections = ${PG_MAX_CONNECTIONS:-100}" >> ${PGDATA}/recovery.conf
echo "max_locks_per_transaction = ${PG_LOCKS_PER_TRANSACTION:-64}" >> ${PGDATA}/recovery.conf

# Copy over minimal configuration
cp /var/lib/postgres/postgresql.conf ${PGDATA}/postgresql.conf
cp /var/lib/postgres/pg_hba.conf ${PGDATA}/pg_hba.conf
chown postgres ${PGDATA}/postgresql.conf ${PGDATA}/pg_hba.conf

# Call the base entrypoint script
/usr/local/bin/docker-entrypoint-orig.sh "$@"
