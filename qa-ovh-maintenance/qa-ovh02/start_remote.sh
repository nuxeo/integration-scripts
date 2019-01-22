#!/bin/bash -xe

#
# (C) Copyright 2018-2019 Nuxeo (http://nuxeo.com/) and others.
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
#     jcarsique
#
# Start remote slaves on qa-ovh02
#

slaveup=$(docker ps -f "status=running" -f "name=static810" --format "{{.ID}}")
if [ -z "$slaveup" ]; then
    docker run --restart=always --privileged -d --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h static810 --name=static810 -p 2202:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave-8.10
fi

slaveup=$(docker ps -f "status=running" -f "name=static910" --format "{{.ID}}")
if [ -z "$slaveup" ]; then
    docker run --restart=always --privileged -d --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h static910 --name=static910 -p 2203:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave-9.10
fi

slaveup=$(docker ps -f "status=running" -f "name=static1010" --format "{{.ID}}")
if [ -z "$slaveup" ]; then
    docker run --restart=always --privileged -d --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h static1010 --name=static1010 -p 2204:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave-10.10
fi

slaveup=$(docker ps -f "status=running" -f "name=itslave810" --format "{{.ID}}")
if [ -z "$slaveup" ]; then
    docker run --restart=always --privileged -d  --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h itslave810 --name=itslave810 -p 2303:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-it-8.10
fi

slaveup=$(docker ps -f "status=running" -f "name=itslave910" --format "{{.ID}}")
if [ -z "$slaveup" ]; then
    docker run --restart=always --privileged -d  --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h itslave910 --name=itslave910 -p 2304:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-it-9.10
fi

slaveup=$(docker ps -f "status=running" -f "name=itslave1010" --format "{{.ID}}")
if [ -z "$slaveup" ]; then
    docker run --restart=always --privileged -d  --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h itslave1010 --name=itslave1010 -p 2305:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-it-10.10
fi

slaveup=$(docker ps -f "status=running" -f "name=matrix02" --format "{{.ID}}")
if [ -z "$slaveup" ]; then
    docker run --restart=always --privileged -d --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -h matrix02 --name=matrix02 -p 2302:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave
fi

exit 0
