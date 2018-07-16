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
#


# priv slave for QA
for i in 1 2; do
    slaveup=$(docker ps -f "status=running" -f "name=privovh01-$i" | grep -v CONTAINER)
    if [ -n "$slaveup" ]; then
        docker kill privovh01-$i && docker rm -v privovh01-$i
    fi
done

# priv slave for QA2
for i in 1; do
    slaveup=$(docker ps -f "status=running" -f "name=priv2-01-$i" | grep -v CONTAINER)
    if [ -n "$slaveup" ]; then
        docker kill priv2-01-$i && docker rm -v priv2-01-$i
    fi
done

itslaveprivup=$(docker ps -f "status=running" -f "name=itslavepriv$" | grep -v CONTAINER)
if [ -n "$itslaveprivup" ]; then
    docker kill itslavepriv && docker rm -v itslavepriv
fi
