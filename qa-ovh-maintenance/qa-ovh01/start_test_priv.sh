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
#     alexis timic
#
#

#for i in 1; do
#    slaveup=$(docker ps -f "status=running" -f "name=priv-nomaven-$i" | grep -v CONTAINER)
#    if [[ -z "$slaveup" ]]; then
#        docker run --restart=always --privileged -d -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace-priv:/opt/jenkins/workspace:rw -h priv-nomaven-$i --name=priv-nomaven-$i -p 320$i:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
#    fi
#done

# priv slave for QA
slave=$1

for i in 1 2; do
    slaveup=$(docker ps -f "status=running" -f "name=privovh01-$i" --format "{{.ID}}")
    if [ -z "$slaveup" ]; then
        docker run --privileged -d --restart=always --add-host mavenpriv.in.nuxeo.com:176.31.235.109 --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace-priv:/opt/jenkins/workspace:rw -h privovh01-$i --name=privovh01-$i -p 330$i:22 -t -e NX_DB_HOST=127.0.0.1 -e NX_MONGODB_SERVER=127.0.0.1 dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
    fi
done

#staticprivup=$(docker ps -f "status=running" -f "name=staticpriv" | grep -v CONTAINER)
#if [[ -z "$staticprivup" ]]; then
#    docker run --restart=always --privileged -d --add-host mavenpriv.in.nuxeo.com:176.31.235.109 --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace-priv:/opt/jenkins/workspace:rw -h staticpriv --name=staticpriv -p 3301:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave
#fi

# priv slave for QA2
for i in 1; do
    slaveup=$(docker ps -f "status=running" -f "name=priv2-01-$i" --format "{{.ID}}")
    if [ -z "$slaveup" ]; then
        docker run --privileged -d --restart=always --add-host mavenpriv.in.nuxeo.com:176.31.235.109 --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace-priv:/opt/jenkins/workspace:rw -h priv2-01-$i --name=priv2-01-$i -p 440$i:22 -t -e NX_DB_HOST=127.0.0.1 -e NX_MONGODB_SERVER=127.0.0.1 dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
    fi
done

itslaveprivup=$(docker ps -f "status=running" -f "name=itslavepriv$" --format "{{.ID}}")
if [ -z "$itslaveprivup" ]; then
    docker run --restart=always --privileged -d --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h itslavepriv --name=itslavepriv -p 3401:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-itpriv
fi
exit 0
