# Dockerized Pact Broker [![Build Status](https://travis-ci.org/elgalu/pact_broker-docker.svg)](https://travis-ci.org/elgalu/pact_broker-docker)

## Requirements

* A [running postgres](#postgres) database and the ability to connect to it or bump a docker postgres by following this guide.

### Start
Example, from scratch, of how to build and run this image alongside the official postgres docker image.

    git clone -b oauth2 git@github.com:elgalu/pact_broker-docker.git
    cd pact_broker-docker/
    docker build -t elgalu/oauth2-pact-broker .

### Env
Set all necessary environment variables we will need.
More info at http://www.postgresql.org/docs/9.4/static/libpq-envars.html

    export PGUSER=postgres
    export PACT_BROKER_DATABASE_USERNAME=${PGUSER}
    export PACT_BROKER_DATABASE_NAME=pact
    export PGPASSWORD=xeipa2E_secret
    export PACT_BROKER_DATABASE_PASSWORD=${PGPASSWORD}
    export SKIP_HTTPS_ENFORCER=true
    export PSQL_IMG="postgres:9.4.5"

Make sure your oauth2 token info service url is correct, e.g.

    export OAUTH_TOKEN_INFO="https://auth.example.com/oauth2/tokeninfo?access_token="

### Postgres
Pull official postgres docker image

    docker pull ${PSQL_IMG}

Run it

    docker run -d --name=postgres -p 5432 \
      -e POSTGRES_PASSWORD=${PGPASSWORD} \
      -e PGPASSWORD \
      -e PGUSER \
      -e PGPORT=5432 \
      ${PSQL_IMG}

Wait for postgres to start

    script/wait_psql.sh postgres

Grab postgres IP

    export PACT_BROKER_DATABASE_HOST=`docker inspect -f '{{ .NetworkSettings.IPAddress }}' postgres`
    echo "Postgres container IP is: ${PACT_BROKER_DATABASE_HOST}"

Ensure psql is running, following command should return success (0) exit code

    docker exec -ti postgres pg_isready --host=localhost --port=5432
    #=> localhost:5432 - accepting connections

Create pacts the database

    docker exec -ti postgres psql -c 'CREATE DATABASE pact;'

Validate the database exists

    docker exec -ti postgres psql -c '\connect pact'
    #=> You are now connected to database "pact" as user "postgres"

Run the pact broker

    docker run -d --name=pact -p 443:443 \
      -e PACT_BROKER_DATABASE_USERNAME \
      -e PACT_BROKER_DATABASE_PASSWORD \
      -e PACT_BROKER_DATABASE_HOST \
      -e PACT_BROKER_DATABASE_NAME \
      -e PACT_BROKER_PORT=443 \
      -e SKIP_HTTPS_ENFORCER \
      -e OAUTH_TOKEN_INFO \
      elgalu/oauth2-pact-broker

Wait for the pact broker to finish starting

    docker exec pact wait_ready 10s

Heartbeat should always 200 OK, without the need of security

    curl http://localhost:443/diagnostic/status/heartbeat
    #=> {"ok":true,"_links":{"self":{"href":"http://localhost:443/diagno...

Trigger access denied

    curl localhost:443; curl localhost:443; curl localhost:443; curl localhost:443
    #=> {"code":429,"message":"AccessDenied","reason":"blocked","error":"request_blocked","error_description":"RequestBlocked"}

Bad token

    curl -H "Authorization: Bearer ASDFASDF" localhost:443
    #=> {"code":401,"message":"InvalidTokenError","reason":"unauthorized","error":"invalid_token","error_description":"InvalidTokenError"}

Get valid token. Note you need python3 and `pip3 install httpie-zign`. You may also need to replace `$USER` with your token service user id, most likely is the same as your machine user.

    GETOK="https://token.auth.example.com/access_token"
    token=$(zign token --user $USER --url $GETOK -n pact)

Use valid token

    curl -H "Authorization: Bearer $token" localhost:443
    #=> {"_links":{"self":{"href":"http://localhost:443",".....

Trigger the first assets compile

    curl -H "Authorization: Bearer $token" \
         -H "Accept:text/html" \
         "http://localhost:443/ui/relationships"

To see it on the browser you will need a chrome extension that injects oauth2 bearer tokens into every header like https://github.com/zalando/chrome-oauth-bearer-plugin but you can still take a look and check the MissingTokenError at:

    open http://localhost:443

Stop without loosing data

    docker stop postgres pact
    docker rm pact

Restart, first by starting `postgres` again then run a new `pact` container, no need to reuse the old one as the persistance is only in postgres

    docker start postgres
    docker exec -ti postgres pg_isready --host=localhost --port=5432
    #docker run -d --name=pact ..... (see above)

Destory and erase all

    docker stop postgres pact
    docker rm pact
    docker rm postgres #DANGER: will the detroy DB!

## Outside of docker (on your Ubuntu host machine)
If you want to expermient on your host machine, instead of docker, additional steps are needed.
For Ubuntu:

    sudo apt-get install libpq-dev

### Run

    bundle exec foreman start

Or

    bundle exec rackup

How to change port and bind to all interfaces

    bundle exec rackup -p 3000 -o 0.0.0.0
