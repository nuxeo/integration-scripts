#!/bin/bash -xe
#
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
# Start remote slaves on qa-ovh03
#

slaveup=$(docker ps -f "status=running" -f "name=static03" --format "{{.ID}}")
if [ -z "$slaveup" ]; then
    docker run --cpu-period=100000 --cpu-quota=200000 --restart=always --privileged -d --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h static03 --name=static03 -p 2201:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave
fi

slaveup=$(docker ps -f "status=running" -f "name=itslave03$" --format "{{.ID}}")
if [ -z "$slaveup" ]; then
    docker run --cpu-period=100000 --cpu-quota=200000 --restart=always --privileged -d --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h itslave03 --name=itslave03 -p 2301:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-it
fi

slaveup=$(docker ps -f "status=running" -f "name=matrix03" --format "{{.ID}}")
if [ -z "$slaveup" ]; then
    docker run --cpu-period=100000 --cpu-quota=200000 --restart=always --privileged -d --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h matrix03 --name=matrix03 -p 2302:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave
fi

exit 0
