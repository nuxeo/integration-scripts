#!/bin/bash -x


slave=$(docker ps -f "status=running" -f "name=$1" --format "{{.ID}}")
echo "$slave"
if [ -n "$slave" ]; then
  children_image_id=$(docker inspect ${1} --format '{{.Image}}' | awk -F':' '{print substr($2,1,12)}')
  echo ${children_image_id}
  if docker images |grep ${children_image_id} |awk -F' ' '{print $2}'|grep '<none>'; then
    echo "$1 must be put offline to be update"
    /usr/bin/docker kill "$slave" && /usr/bin/docker rm -v "$slave"
  fi
  else
    echo "$1 is up to date"
fi

