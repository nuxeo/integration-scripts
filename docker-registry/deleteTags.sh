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
# Bulk delete Docker repository tags by name

if [ "$DRY_RUN" = "true" ]; then
    echo "### DRY_RUN ###"
else
    unset DRY_RUN
fi

function usage() {
    echo "Usage: ./deleteTags.sh <image> <tags>"
    echo "       ./deleteTags.sh <input file with images and tags>"
    echo " Environment properties:"
    echo "   - DOCKER_REGISTRY: Docker Registry URL (optional)"
    echo "   - KUBE_NS: Kubernetes namespace hosting the registry (required if DOCKER_REGISTRY is not set)"
    echo "   - DRY_RUN: dry run mode if true"
}

function deleteTags() {
    if [[ $# -lt 2 ]]; then
        echo "Missing parameters. Expected: <image> <tag>.. Got: $*"
        exit 2
    fi
    local image=$1
    shift
    local tags=$*
    if [ -z "$DRY_RUN" ]; then
        echo "Image $image:"
        for tag in $tags; do
            printf "* tag: %s ..." "$tag"
            IFS=$'\n'
            if out=($(reg rm "$DOCKER_REGISTRY/$image:$tag" 2>&1)); then
                printf "deleted\n"
            else
                printf "ERROR %s\n" "${out[-1]}"
                error=1
            fi
        done
    else
        printf "reg rm $DOCKER_REGISTRY/$image:%s\n" $tags
    fi
}

if ! $(command -v reg >/dev/null); then
    echo "Missing reg tool."
fi

if [[ $# -eq 0 ]]; then
    echo "Missing parameters."
    usage
    exit 2
elif [[ $# -eq 1 ]]; then
    if [[ ! -f $1 ]]; then
        echo "File not found: $1"
        exit 2
    else
        inputFile=$1
    fi
fi

if [ -z "$DOCKER_REGISTRY" ]; then
    : "${KUBE_NS:?}"
    url=$(kubectl -n "$KUBE_NS" get svc jenkins-x-docker-registry -o jsonpath='{.metadata.annotations.fabric8\.io/exposeUrl}')
    DOCKER_REGISTRY=${url#*://}
fi

error=0
if [ -z "$inputFile" ]; then
    # shellcheck disable=SC2086
    deleteTags $*
else
    #    set -x
    while IFS= read -r line; do
        # shellcheck disable=SC2015
        [[ $line == \#* || -z "${line// /}" ]] && continue || true
        unset IFS
        deleteTags $line
    done <"$inputFile"
#    set +x
fi
echo
echo Issue the following command on the registry to trigger garbage collect:
echo "/bin/registry garbage-collect /etc/docker/registry/config.yml | grep 'blobs eligible for deletion'"
exit $error
