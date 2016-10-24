#!/bin/bash

wget https://github.com/concourse/concourse/releases/download/v2.3.1/concourse_linux_amd64

mv concourse_linux_amd64 concourse

chmod +x concourse

ssh-keygen -t rsa -f host_key -N ''
ssh-keygen -t rsa -f worker_key -N ''
ssh-keygen -t rsa -f session_signing_key -N ''

apt-get install -y postgresql

su postgres

runuser -l postgres -c 'psql -c "CREATE DATABASE atc;"'

mkdir -p /var/lib/concourse-dir

# start up concourse server - ATC/TSA
./concourse web \
    --basic-auth-username concourse \
    --basic-auth-password concourse \
    --session-signing-key session_signing_key \
    --tsa-host-key host_key \
    --tsa-authorized-keys authorized_worker_keys \
    --external-url http://$HOST \
    --postgres-data-source postgres://concourse:concourse@localhost:5432/concourse

# start up concourse worker
sudo concourse worker \
  --work-dir /var/lib/concourse/concourse-dir \
  --tsa-host 127.0.0.1 \
  --tsa-public-key host_key.pub \
  --tsa-worker-private-key worker_key
