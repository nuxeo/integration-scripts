#!/bin/bash -xe

dir=$(dirname $0)
${dir}/pull_images

static710up=$(docker ps -f "status=running" -f "name=static710" | grep -v CONTAINER)
if [ -z "$static710up" ]; then
    docker run --restart=always --privileged -d --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h static710 --name=static710 -p 2201:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave-7.10
fi

static810up=$(docker ps -f "status=running" -f "name=static810" | grep -v CONTAINER)
if [ -z "$static810up" ]; then
    docker run --restart=always --privileged -d --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h static810 --name=static810 -p 2202:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave-8.10
fi

static910up=$(docker ps -f "status=running" -f "name=static910" | grep -v CONTAINER)
if [ -z "$static910up" ]; then
    docker run --restart=always --privileged -d --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h static910 --name=static910 -p 2203:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave-9.10
fi

itstatic810up=$(docker ps -f "status=running" -f "name=itslave710" | grep -v CONTAINER)
if [ -z "$itstatic810up" ]; then
    docker run --restart=always --privileged -d --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h itslave710 --name=itslave710 -p 2301:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-it-7.10
fi

itslave810up=$(docker ps -f "status=running" -f "name=itslave810" | grep -v CONTAINER)
if [ -z "$itslave810up" ]; then
    docker run --restart=always --privileged -d  --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h itslave810 --name=itslave810 -p 2303:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-it-8.10
fi

itslave910up=$(docker ps -f "status=running" -f "name=itslave910" | grep -v CONTAINER)
if [ -z "$itslave910up" ]; then
    docker run --restart=always --privileged -d  --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw -h itslave910 --name=itslave910 -p 2304:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-it-9.10
fi

matrixup=$(docker ps -f "status=running" -f "name=matrix" | grep -v CONTAINER)
if [ -z "$matrixup" ]; then
    docker run --restart=always --privileged -d --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -h matrix --name=matrix -p 2302:22 -t dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave
fi
