#/
# (C) Copyright 2018 Nuxeo (http://nuxeo.com/) and others.
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
# - atimic
#
# Check if container is running and if the image it used is up to date (tag != none)
# QA OVH
#/

#!/bin/bash -x

SLAVE_NAME=${1}

SLAVE_ID=$(docker ps -f "status=running" -f "name=${SLAVE_NAME}" --format "{{.ID}}")
echo "${SLAVE_ID}"
if [ -n "$SLAVE_ID" ]; then
  CHILD_IMAGE_ID=$(docker inspect ${SLAVE_NAME} --format '{{.Image}}' | awk -F':' '{print substr($2,1,12)}')
  echo ${CHILD_IMAGE_ID}
  if docker images |grep ${CHILD_IMAGE_ID} |awk -F' ' '{print $2}'|grep '<none>'; then
    echo "${SLAVE_NAME} is outdated"
    exit 0
  fi
  else
    echo "${SLAVE_NAME} is up to date"
    bash -c 'exit 1'
fi

