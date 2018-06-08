#!/bin/bash -x
#
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
#     mguillaume
#     atimic
#


docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-it
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-ondemand
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-check
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-multidb

docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave-7.10
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-it-7.10
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-ondemand-7.10
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-check-7.10
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv-7.10

docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave-8.10
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-it-8.10
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-ondemand-8.10
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-check-8.10
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv-8.10

docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave-9.10
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-it-9.10
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-ondemand-9.10
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-check-9.10
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv-9.10

# PREPROD Slave #
docker pull dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave-test-preprod

# Clean dangling images
docker images dockerpriv.nuxeo.com:443/nuxeo/* -f "dangling=true" -q | sort -u | xargs -r docker rmi -f
exit 0
