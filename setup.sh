#!/bin/bash

set -e -x

concourse_basic_auth_username=concourse
concourse_basic_auth_password=concourse

concourse_dir=/var/lib/concourse

postgres_username=concourse
postgres_password=concourse
postgres_database=concourse

concourse_version=2.5.0

letsencrypt=false

while test $# -gt 0; do
  case "$1" in
    --help|-h)
      shift
      help=$1
      shift
    ;;
    --host)
      shift
      host=$1
      shift
    ;;
    --concourse-basic-auth-username)
      shift
      concourse_basic_auth_username=$1
      shift
    ;;
    --concourse-basic-auth-password)
      shift
      concourse_basic_auth_password=$1
      shift
    ;;
    --postgres-user)
      shift
      postgres_username=$1
      shift
    ;;
    --postgres-password)
      shift
      postgres_password=$1
      shift
    ;;
    --concourse-dir)
      shift
      concourse_dir=$1
      shift
    ;;
    --concourse-version)
      shift
      concourse_version=$1
      shift
    ;;
    --letsencrypt)
      letsencrypt=true
      echo "yes lets encrypt!"
      shift
    ;;
    *)
      break
    ;;
  esac
done

# required fields
if [ -z "$host" ]; then
   echo "host is a required field"
   exit 1
fi

# install letsencrypt
#if [ $letsencrypt ]; then
  sudo apt-get -y install letsencrypt
  letsencrypt certonly -d $host
#fi

# incase $concourse_dir changes
concourse_key_dir=$concourse_dir/keys

wget https://github.com/concourse/concourse/releases/download/v$concourse_version/concourse_linux_amd64

chmod +x concourse_linux_amd64

mv concourse_linux_amd64 /usr/bin/concourse

mkdir -p $concourse_key_dir

ssh-keygen -t rsa -f $concourse_key_dir/host_key -N ''
ssh-keygen -t rsa -f $concourse_key_dir/worker_key -N ''
ssh-keygen -t rsa -f $concourse_key_dir/session_signing_key -N ''

cp $concourse_key_dir/worker_key.pub $concourse_key_dir/authorized_worker_keys

apt-get install -y postgresql

runuser -l postgres -c "psql -c \"CREATE USER $postgres_username WITH PASSWORD '$postgres_password';\""
runuser -l postgres -c "psql -c \"CREATE DATABASE $postgres_database;\""
runuser -l postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE $postgres_database to $postgres_username;\""

# start up concourse server - ATC/TSA
nohup concourse web \
    --basic-auth-username $concourse_basic_auth_username \
    --basic-auth-password $concourse_basic_auth_password \
    --session-signing-key $concourse_key_dir/session_signing_key \
    --tsa-host-key $concourse_key_dir/host_key \
    --tsa-authorized-keys $concourse_key_dir/authorized_worker_keys \
    --postgres-data-source postgres://$postgres_username:$postgres_password@localhost:5432/$postgres_database \
    --tls-cert /etc/letsencrypt/live/$host/fullchain.pem \
    --tls-key /etc/letsencrypt/live/$host/privkey.pem \
    --tls-bind-port 8081 \
    --external-url https://$host  &

# start up concourse worker
nohup concourse worker \
  --work-dir $concourse_dir \
  --tsa-host 127.0.0.1 \
  --tsa-public-key $concourse_key_dir/host_key.pub \
  --tsa-worker-private-key $concourse_key_dir/worker_key &


