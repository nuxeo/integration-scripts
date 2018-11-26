#!/bin/bash -x

SLAVE_NAME=${1}

SLAVE_ID=$(docker ps -f "status=running" -f "name=${SLAVE_NAME}" --format "{{.ID}}")
echo "${SLAVE_ID}"
if [ -n "$SLAVE_ID" ]; then
  CHILD_IMAGE_ID=$(docker inspect ${SLAVE_NAME} --format '{{.Image}}' | awk -F':' '{print substr($2,1,12)}')
  echo ${CHILD_IMAGE_ID}
  if docker images |grep ${CHILD_IMAGE_ID} |awk -F' ' '{print $2}'|grep '<none>'; then
    echo "${SLAVE_NAME} will be killed and updated"
    /usr/bin/docker kill "${SLAVE_NAME}" && /usr/bin/docker rm -v "${SLAVE_NAME}"
  fi
  else
    echo "${SLAVE_NAME} is up to date"
fi

