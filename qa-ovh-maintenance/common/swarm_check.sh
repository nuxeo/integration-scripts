#!/bin/bash -x

SLAVE_NAME=${1}
SLAVE_ID=$(docker -H tcp://swarm-qa.nuxeo.org:4000 ps -f "status=running" -f "name=${SLAVE_NAME}" --format "{{.ID}}")

if [ -n "$SLAVE_ID" ]; then

    SLAVE_HOST=$(docker -H tcp://swarm-qa.nuxeo.org:4000 ps -f "status=running" -f "name=${SLAVE_NAME}" --format "{{.Names}}" | cut -d '/' -f 1)
    SLAVE_IMAGE_ID=$(docker -H ${SLAVE_HOST}.nuxeo.com:4243 inspect ${SLAVE_NAME} --format '{{.Image}}' | awk -F':' '{print substr($2,1,12)}')
    if docker -H $SLAVE_HOST.nuxeo.com:4243 images |grep ${SLAVE_IMAGE_ID} |awk -F' ' '{print $2}'|grep '<none>'; then
        echo "${SLAVE_NAME} is outdated"
        exit 1
    else
        echo "${SLAVE_NAME} is up to date"
        exit 0
    fi
fi
