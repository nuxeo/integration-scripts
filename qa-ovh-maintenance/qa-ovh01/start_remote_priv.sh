#!/bin/bash -xe
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
# Start remote private slaves on qa-ovh01
#

# Reserved for QA
for i in 1 2; do
    slaveup=$(docker ps -f "status=running" -f "name=priv-01-$i" --format "{{.ID}}")
    if [ -z "$slaveup" ]; then
        docker run --privileged -d --restart=always --add-host mavenpriv.in.nuxeo.com:176.31.235.109
--add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace-priv:/opt/jenkins/workspace:rw -h priv-01-$i --name=priv-01-$i -p 33${i}0:22 -t -e NX_DB_HOST=127.0.0.1 -e NX_MONGODB_SERVER=127.0.0.1 dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
    fi
done

# Reserved for QA2
for i in 1; do
    slaveup=$(docker ps -f "status=running" -f "name=priv2-01-$i" --format "{{.ID}}")
    if [ -z "$slaveup" ]; then
        docker run --privileged -d --restart=always --add-host mavenpriv.in.nuxeo.com:176.31.235.109 --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace-priv:/opt/jenkins/workspace:rw -h priv2-01-$i --name=priv2-01-$i -p 440$i:22 -t -e NX_DB_HOST=127.0.0.1 -e NX_MONGODB_SERVER=127.0.0.1 dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
    fi
done

slaveup=$(docker ps -f "status=running" -f "name=itslavepriv01$" --format "{{.ID}}")
if [ -z "$slaveup" ]; then
    docker run --restart=always --privileged -d --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h itslavepriv01 --name=itslavepriv01 -p 3401:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-itpriv
fi
exit 0
