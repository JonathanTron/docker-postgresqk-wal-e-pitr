USAGE:

This assumes you're encrypting your wal / base backup using GPG.

First, you need to fetch the last base backup *before* your target recovery time, you can use this image to do it as it contains wal-e, you just need to override the `entrypoint` to run a shell instead of the default:

```bash
mkdir secret
mkdir pgdata
cp gpg_private_key.txt secret/

docker run \
  --name pg-pitr \
  -v `pwd`/secret:/secret \
  -v `pwd`/pgdata:/pgdata
  -e GPG_PRIVATE_KEY_FILE_PATH=/secret/gpg_private_key.txt
  -e WALE_GPG_KEY_ID=XXXX
  -e AWS_ACCESS_KEY_ID=XXXX
  -e AWS_SECRET_ACCESS_KEY=XXXX
  -e AWS_REGION=eu-west-1
  -e WALE_S3_PREFIX=s3://xxxxx/wal-e
  --entrypoint /bin/sh \
  jonathantron/postgresql-wal-e-pitr

# In the container:

# Ensure your GPG private key is loaded
gpg \
  --batch \
  --no-tty \
  --yes \
  --import $GPG_PRIVATE_KEY_FILE_PATH
touch tmp.txt
gpg \
  --batch \
  --no-tty \
  --yes \
  -e \
  -r $WALE_GPG_KEY_ID \
  --trusted-key $WALE_GPG_KEY_ID \
  tmp.txt
rm -f tmp.txt tmp.txt.gpg

# List the available base backups
wal-e backup-list

# Grab the wanted base backup
wal-e \
  backup-fetch \
  --pool-size 16 \
  /pgdata \
  base_000000010000009300000045_00000040

# exit the container
exit
```

Then you can restore from this base backup up to the recovery time you want:

```bash
docker run \
  --name pg-pitr \
  -v `pwd`/secret:/secret \
  -v `pwd`/pgdata:/var/lib/postgresql/data
  -e GPG_PRIVATE_KEY_FILE_PATH=/secret/gpg_private_key.txt
  -e WALE_GPG_KEY_ID=XXXX
  -e AWS_ACCESS_KEY_ID=XXXX
  -e AWS_SECRET_ACCESS_KEY=XXXX
  -e AWS_REGION=eu-west-1
  -e WALE_S3_PREFIX=s3://xxxxx/wal-e
  -e PG_MAX_CONNECTIONS=200 \        # This should match the value of your database at the base backup time
  -e PG_LOCKS_PER_TRANSACTION=2000 \ # This should match the value of your database at the base backup time
  -e PITR_RECOVERY_TARGET_TIME='2018-01-22 20:30:00 UTC'
  jonathantron/postgresql-wal-e-pitr
```

When done you should see a log similar to:

```
LOG:  recovery stopping before commit of transaction 9006174, time 2018-01-22 19:30:07.365193+00
LOG:  recovery has paused
```

The database is now in `hot_standby` mode, you can query the data to see if the recovery time is fine or use pg_dump:

```bash
mkdir pgdumps
docker run \
  --rm \
  -it \
  -v `pwd`/pgdumps:/pgdumps \
  --link pg-pitr:postgres \
  --entrypoint /bin/sh \
  jonathantron/postgresql-wal-e-pitr

# You can connect to the database with:
psql -U postgres -h postgres DATABASE_NAME

# Same for pg_dump
pg_dump -U postgres -h postgres DATABASE_NAME > /pgdumps/DATABASE_NAME.sql
```
