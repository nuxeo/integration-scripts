#!/bin/bash -x
#
# (C) Copyright ${year} Nuxeo (http://nuxeo.com/) and others.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Contributors:
#     - atimic
#
#   Check if slaves containers are using newer built docker images
#   Match Slaves container parent image to the image registry of host in search of a latest or none tag



function check_update()
{
     if docker -H $SLAVE_HOST.nuxeo.com:4243 images |grep ${SLAVE_IMAGE_NAME} |grep ${SLAVE_IMAGE_ID} |awk -F' ' '{print $2}'|grep '<none>'; then
        echo "${SLAVE_NAME} is outdated"
        retval=1
    else
        echo "${SLAVE_NAME} is up to date"
        retval=0
    fi

}


SLAVE_NAME=${1}
SLAVE_ID=$(docker -H tcp://swarm-qa.nuxeo.org:4000 ps -f "status=running" -f "name=${SLAVE_NAME}" --format "{{.ID}}")
if [ -n "$SLAVE_ID" ]; then

    SLAVE_HOST=$(docker -H tcp://swarm-qa.nuxeo.org:4000 ps -f "status=running" -f "name=${SLAVE_NAME}" --format "{{.Names}}" | cut -d '/' -f 1 | cut -d '.' -f 1)
    SLAVE_IMAGE_ID=$(docker -H ${SLAVE_HOST}.nuxeo.com:4243 inspect ${SLAVE_NAME} --format '{{.Image}}' | awk -F':' '{print substr($2,1,12)}')
    SLAVE_IMAGE_NAME=$(docker -H ${SLAVE_HOST}.nuxeo.com:4243 inspect ${SLAVE_NAME} --format '{{.Config.Image}}')
    retval=0
    check_update
fi
