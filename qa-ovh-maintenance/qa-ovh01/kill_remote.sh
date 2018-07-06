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
#     atimic
#

args=$1

slave=$(docker ps -f "status=running" -f "name=$1" --format "{{.ID}}")
echo "$slave"
if [ -n "$slave" ];
then
	/usr/bin/docker kill "$slave" && /usr/bin/docker rm -v "$slave"
	else echo "$slave appears to be already offline"
	fi
exit 0
