# /*
# (C) Copyright ${year} Nuxeo (http://nuxeo.com/) and others.
# *
# * Licensed under the Apache License, Version 2.0 (the "License");
# * you may not use this file except in compliance with the License.
# * You may obtain a copy of the License at
# *
# *     http://www.apache.org/licenses/LICENSE-2.0
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
# *
# * Contributors:
# *     ...
# */

###### Cron file for jenkins qa* ######

#!/bin/bash

docker image prune -f > /dev/null
docker volume prune -f > /dev/null
docker ps -a | grep Exited | grep "hours ago" | awk '{print $1}' | xargs --no-run-if-empty docker rm -v > /dev/null 2>&1
find /opt/jenkins/workspace/TestAndPush -maxdepth 1 -mindepth 1 -type d -mtime +3 -exec rm -rf {} \;
find /opt/jenkins/workspace*/ -name nuxeo-server-tomcat-*.zip -o -name nuxeo-cap-*.zip -mtime +3 -exec rm {} \;
find /opt/jenkins/workspace* -path \*/target/tomcat -type d -prune -mtime +3 -exec rm -r {} \;
