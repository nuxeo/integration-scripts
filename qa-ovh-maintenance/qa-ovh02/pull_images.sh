#!/bin/bash -xe

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

# Clean dangling images
docker images dockerpriv.nuxeo.com:443/nuxeo/* -f "dangling=true" -q | sort -u | xargs -r docker rmi -f

exit 0
