#!/bin/bash -xe

dir=$(dirname $0)
${dir}/pull_images

# priv slave for QA
for i in 1 2; do
    slaveup=$(docker ps -f "status=running" -f "name=privovh02-$i" | grep -v CONTAINER)
    if [ -z "$slaveup" ]; then
        docker run --privileged -d --restart=always --add-host mavenpriv.in.nuxeo.com:176.31.235.109 --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace-priv:/opt/jenkins/workspace:rw -h privovh02-$i --name=privovh02-$i -p 330$i:22 -t -e NX_DB_HOST=127.0.0.1 -e NX_MONGODB_SERVER=127.0.0.1 dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
    fi
done

# priv slave for QA2
for i in 1; do
    slaveup=$(docker ps -f "status=running" -f "name=priv2-02-$i" | grep -v CONTAINER)
    if [ -z "$slaveup" ]; then
        docker run --privileged -d --restart=always --add-host mavenpriv.in.nuxeo.com:176.31.235.109 --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace-priv:/opt/jenkins/workspace:rw -h priv2-02-$i --name=priv2-02-$i -p 440$i:22 -t -e NX_DB_HOST=127.0.0.1 -e NX_MONGODB_SERVER=127.0.0.1 dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
    fi
done

# static priv slave 7.10 for QA2
for i in 1; do
    slaveup=$(docker ps -f "status=running" -f "name=slavepriv2-710-$i" | grep -v CONTAINER)
    if [ -z "$slaveup" ]; then
        docker run --privileged -d --restart=always --add-host mavenpriv.in.nuxeo.com:176.31.235.109 --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace-priv:/opt/jenkins/workspace:rw -h slavepriv2-710-$i --name=slavepriv2-710-$i -p 550$i:22 -t -e NX_DB_HOST=127.0.0.1 -e NX_MONGODB_SERVER=127.0.0.1 dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv-7.10
    fi
done

# static priv slave 8.10 for QA2
for i in 1; do
    slaveup=$(docker ps -f "status=running" -f "name=slavepriv2-810-$i" | grep -v CONTAINER)
    if [ -z "$slaveup" ]; then
        docker run --privileged -d --restart=always --add-host mavenpriv.in.nuxeo.com:176.31.235.109 --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace-priv:/opt/jenkins/workspace:rw -h slavepriv2-810-$i --name=slavepriv2-810-$i -p 560$i:22 -t -e NX_DB_HOST=127.0.0.1 -e NX_MONGODB_SERVER=127.0.0.1 dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv-8.10
    fi
done

# static priv slave 9.10 for QA2
for i in 1; do
    slaveup=$(docker ps -f "status=running" -f "name=slavepriv2-910-$i" | grep -v CONTAINER)
    if [ -z "$slaveup" ]; then
        docker run --privileged -d --restart=always --add-host mavenpriv.in.nuxeo.com:176.31.235.109 --add-host mavenin.nuxeo.com:176.31.239.50 -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace-priv:/opt/jenkins/workspace:rw -h slavepriv2-910-$i --name=slavepriv2-910-$i -p 570$i:22 -t -e NX_DB_HOST=127.0.0.1 -e NX_MONGODB_SERVER=127.0.0.1 dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv-9.10
    fi
done
