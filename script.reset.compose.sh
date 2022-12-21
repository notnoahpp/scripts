#!/usr/bin/env bash

###########################
# resets a container & image
# for something less destructive, use refresh script
###########################

set -e

SERVICE_PREFIX=${SERVICE_PREFIX:-nirvai}
POSTGRES_VOL_NAME=$SERVICE_PREFIX-core-postgres

create_volumes() {
  docker volume create $POSTGRES_VOL_NAME
}

build() {
  docker compose build --progress=plain
}

up() {
  docker compose up -d --remove-orphans
}

echo -e "running reset"

docker compose config

case $1 in
logs)
  name=${2:-""}
  if [[ -z $name ]]; then
    echo -e "syntax: logs appname"
    exit 1
  fi
  cname="$SERVICE_PREFIX-$name"
  ## docker inspect --format="{{.Id}}" some_container_name
  id=$(docker inspect --format="{{.Id}}" $cname)
  echo -e "displaying log file for container $cname with id $id"
  sudo cat /var/lib/docker/containers/$id/$id-json.log | jq
  exit 0
  ;;
volumes)
  create_volumes
  docker volume ls
  ;;
core*)
  echo "resetting infrastructore for $1"
  if ! docker container kill $SERVICE_PREFIX-$1; then
    echo "container for service $1 already dead"
  else
    docker container rm $SERVICE_PREFIX-$1
    if [[ $1 == *"postgres" ]]; then
      echo "recreating $1 volumes"
      docker volume rm $POSTGRES_VOL_NAME
      create_volumes
    fi
  fi
  docker container prune -f
  echo "restarting server $1"
  docker compose build --no-cache $1
  docker compose up -d $1 --remove-orphans
  docker compose convert $1
  ;;
*)
  echo 'resetting infrastructure'
  docker compose down
  dk_rm_all || true
  create_volumes
  build
  up
  ;;
esac

dk_ps
