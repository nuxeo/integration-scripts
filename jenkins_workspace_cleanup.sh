#!/bin/bash

docker image prune -f > /dev/null
docker volume prune -f > /dev/null
docker ps -a | grep Exited | grep "hours ago" | awk '{print $1}' | xargs --no-run-if-empty docker rm -v > /dev/null 2>&1
find /opt/jenkins/workspace/TestAndPush -maxdepth 1 -mindepth 1 -type d -mtime +3 -exec rm -rf {} \;
find /opt/jenkins/workspace*/ -name nuxeo-server-tomcat-*.zip -o -name nuxeo-cap-*.zip -mtime +3 -exec rm {} \;
find /opt/jenkins/workspace* -path \*/target/tomcat -type d -prune -mtime +3 -exec rm -r {} \;
