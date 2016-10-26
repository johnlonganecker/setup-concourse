#!/bin/bash
wget https://github.com/concourse/concourse/releases/download/v2.3.1/concourse_linux_amd64

host=some.host.here
concourse_basic_auth_username=concourse
concourse_basic_auth_password=concourse

concourse_dir=/var/lib/concourse
concourse_key_dir=$concourse_dir/keys

postgres_user=concourse
postgres_password=concourse
postgres_database=concourse

chmod +x concourse_linux_amd64

mv concourse_linux_amd64 /usr/bin/concourse

mkdir -p $concourse_key_dir

ssh-keygen -t rsa -f $concourse_key_dir/host_key -N ''
ssh-keygen -t rsa -f $concourse_key_dir/worker_key -N ''
ssh-keygen -t rsa -f $concourse_key_dir/session_signing_key -N ''

cp $concourse_key_dir/worker_key.pub $concourse_key_dir/authorized_worker_keys

apt-get install -y postgresql

runuser -l postgres -c "psql -c \"CREATE USER $postgres_user WITH PASSWORD '$postgres_password';\""
runuser -l postgres -c "psql -c \"CREATE DATABASE $postgres_database;\""
runuser -l postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE $postgres_database to $postgres_user;\""

# start up concourse server - ATC/TSA
nohup concourse web \
    --basic-auth-username $concourse_basic_auth_username \
    --basic-auth-password $concourse_basic_auth_password \
    --session-signing-key $concourse_key_dir/session_signing_key \
    --tsa-host-key $concourse_key_dir/host_key \
    --tsa-authorized-keys $concourse_key_dir/authorized_worker_keys \
    --external-url http://$host  \
    --postgres-data-source postgres://$postgres_user:$postgres_password@localhost:5432/$postgres_database &

# start up concourse worker
nohup concourse worker \
  --work-dir $concourse_dir \
  --tsa-host 127.0.0.1 \
  --tsa-public-key $concourse_key_dir/host_key.pub \
  --tsa-worker-private-key $concourse_key_dir/worker_key &
