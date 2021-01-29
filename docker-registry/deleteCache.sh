#!/bin/bash -e

#
# (C) Copyright 2020 Nuxeo (http://nuxeo.com/) and others.
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
#     jcarsique
#
# Delete Docker repositories which name ends with "/cache*", tag by tag
# Usage: ./deleteCache.sh
# Environment properties:
#   - DOCKER_REGISTRY: Docker Registry URL (optional)
#   - KUBE_NS: Kubernetes namespace hosting the registry (required if DOCKER_REGISTRY is not set)

: "${KUBE_NS:?}"
url=$(kubectl -n "$KUBE_NS" get svc jenkins-x-docker-registry -o jsonpath='{.metadata.annotations.fabric8\.io/exposeUrl}')
dockerRegistryUrl=$(kubectl -n "$KUBE_NS" get svc jenkins-x-docker-registry -o jsonpath='{.metadata.annotations.fabric8\.io/exposeUrl}')
dockerRegistryDomain=${dockerRegistryUrl#*://}

CACHE_LIST=$(reg ls "${dockerRegistryDomain}" 2>/dev/null|grep -E '^.*/cache[^/]* '|cut -f 1 -d ' ')
printf "Cache repository list:\n%s\n" "$CACHE_LIST"
for cacheRepo in $CACHE_LIST; do
    printf "Delete %s\n\t" "$cacheRepo"
    for tag in $(reg tags "${dockerRegistryDomain}/$cacheRepo" 2>/dev/null); do
        stdbuf -oL printf "%.5s..." "$tag"
        reg rm "${dockerRegistryDomain}/$cacheRepo:$tag" >/dev/null 2>&1 || stdbuf -oL printf "x"
    done
    printf "\n"
done
echo Done
