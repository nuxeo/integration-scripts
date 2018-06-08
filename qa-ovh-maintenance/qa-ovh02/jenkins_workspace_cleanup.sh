#!/bin/bash
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
#     jcarsique
#
# Cleanup Jenkins hosts: Docker and workspaces

# Prune stopped images
docker image prune -f > /dev/null
# Prune stopped volumes
docker volume prune -f > /dev/null
# Delete "exited" containers
docker ps -a | awk '/Exited.*(hours|days|weeks) ago/ {print $1}' | xargs --no-run-if-empty docker rm -v > /dev/null 2>&1

# Delete T&P jobs older than 3 days
find /opt/jenkins/workspace/TestAndPush -maxdepth 1 -mindepth 1 -type d -mtime +3 -exec rm -r -- {} +

# Delete Nuxeo server ZIP files and unzipped folders older than 3 days
find /opt/jenkins/workspace*/ -name 'nuxeo-server-tomcat-*.zip' -o -name 'nuxeo-cap-*.zip' -mtime +3 -exec rm -- {} +
find /opt/jenkins/workspace*/ -path '*/target/tomcat' -type d -prune -mtime +3 -exec rm -r -- {} +

# Remove Git repositories parent folders older than 5 days
find /opt/jenkins/workspace*/ -maxdepth 2 -type d -execdir test -d {}/.git \; -mtime +5 -prune -print -exec rm -r -- {} +

# Remove Git repositories parent folders older than 2 days and bigger than 100M
find /opt/jenkins/workspace*/ -maxdepth 2 -type d -execdir test -d {}/.git \; -mtime +2 -prune -print |xargs du -sh |sort -hr|grep -P "^(.*G|\d{3}M)\t" |cut -d$'\t' -f 2-|xargs rm -r --

# Remove files that the Workspace Cleanup plugin has no permission to delete (NXBT-2205, JENKINS-24824)
find /opt/jenkins/workspace*/ -path '*/*ws-cleanup*' ! -perm -u+w -prune -exec chmod u+w {} + -exec rm -r -- {} +
