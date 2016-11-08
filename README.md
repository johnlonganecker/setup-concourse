# Setup Concourse

## Setup

The Only required field is host
```
./setup.sh --concourse-basic-auth-username con --concourse-basic-auth-password conpass --postgres-user pguser --postgres-password pgpass --concourse-dir /var/lib/concourse --host <your-host>
```

## Hello World Pipeline
```
fly --target <my-target> login -c http://$HOST:8080
fly set-pipeline -t <my-target> -p <my-pipeline> -c hello-world.yml
```

