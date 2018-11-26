#!/bin/bash -x

children_image_id=$(docker inspect ${1} --format '{{.Image}}' | awk -F':' '{print substr($2,1,12)}')
echo ${children_image_id}
if docker images |grep ${children_image_id} |awk -F' ' '{print $2}'|grep '<none>'; then
        echo "success"
fi
