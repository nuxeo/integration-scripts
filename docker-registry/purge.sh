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
#     ataillefer, jcarsique
#
# Purge tags from Docker repositories based on their name and labels
# - cache repos
# - check related PR status

: "${GITHUB_TOKEN:?}"
: "${KUBE_NS:?}"
PURGE_PATTERN=${PURGE_PATTERN:-'PR|feature|fix|task'}

dockerRegistryPod=$(kubectl -n "$KUBE_NS" get pod -l app=docker-registry -o jsonpath="{.items[0].metadata.name}")
if [ -n "$DOCKER_REGISTRY" ]; then
    dockerRegistryUrl=http://$DOCKER_REGISTRY
    dockerRegistryDomain=$DOCKER_REGISTRY
else
    dockerRegistryUrl=$(kubectl -n "$KUBE_NS" get svc jenkins-x-docker-registry -o jsonpath='{.metadata.annotations.fabric8\.io/exposeUrl}')
    dockerRegistryDomain=${dockerRegistryUrl#*://}
fi

function execDockerRegistry() {
    kubectl -n "$KUBE_NS" exec "$dockerRegistryPod" -- $1
}

function space() {
    execDockerRegistry "df -h /var/lib/registry"
}

# shellcheck disable=SC2120
function used() {
    execDockerRegistry "df" | grep /var/lib/registry | awk '{print $3}'
}

function getTags() {
    image=$1
    imagePattern=$2
    if $(command -v reg >/dev/null); then
        reg tags "${dockerRegistryDomain}/$image" 2>/dev/null | grep -E "$imagePattern" || true
    else
        curl -s "${dockerRegistryUrl}/v2/$image/tags/list" | jq -r '.tags | .[]?' | grep -E "$imagePattern" || true
    fi
}

function deleteTag() {
    image=$1
    tag=$2
    if $(command -v reg >/dev/null); then
        reg rm "${dockerRegistryDomain}/$image:$tag" >/dev/null 2>&1
    else
        rawDigest=$(curl -v -s -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' "${dockerRegistryUrl}/v2/$image/manifests/$tag" 2>&1 | grep Docker-Content-Digest | awk '{print $3}')
        digest=${rawDigest%$'\r'}
        [ "$digest" ] && curl -s -X DELETE "${dockerRegistryUrl}/v2/$image/manifests/$digest"
    fi
}

deleteCacheImages=$([ "$1" = "true" ] && echo -n "true" || echo -n "false")
doPurge=$([ "$2" = "true" ] && echo -n "true" || echo -n "false")

echo '==================================='
echo '- Purge Docker registry! -'
echo '==================================='
echo
echo '  Usage: ./purge.sh [deleteCacheImages=false] [doPurge=true]'
echo
echo '  Parameters:'
echo "    - DOCKER_REGISTRY: $DOCKER_REGISTRY"
echo "    - Host: ${dockerRegistryUrl}"
echo "    - PURGE_PATTERN: ${PURGE_PATTERN}"
echo "    - delete cache images: ${deleteCacheImages}"
echo "    - do purge: ${doPurge}"
echo

echo "Working on $dockerRegistryPod"
echo 'Space before cleanup:'
space
echo

usedBefore=$(used)

images=$(curl -s --connect-timeout 3 "${dockerRegistryUrl}/v2/_catalog" | jq -r '.repositories | .[]?')
echo 'Images:'
cat <<EOF
$images
EOF
echo

for image in $images; do
    echo "Image $image:"
    isCache=false && [[ ${image} =~ .*/cache.*$ ]] && isCache=true
    if $isCache; then
        if [ "${deleteCacheImages}" = "true" ]; then
            printf "* delete all digests\n"
        else
            printf "* ignore cache\n\n"
            continue
        fi
        tags=$(getTags "$image" '')
        for tag in $tags; do
            deleteTag "$image" "$tag"
        done
        echo
    else
        tags=$(getTags "$image" "$PURGE_PATTERN")
        if [ -z "$tags" ]; then
            printf "* no tags\n\n"
            continue
        fi
#        printf "- tags matching pattern '%s':\n%s\n\n" "$imagePattern" "$tags"
        for tag in $tags; do
            printf "* tag %s: " "$tag"
            # keep image if from open PR
            pr_regex='.*-PR-([0-9]+).*'
            if [[ $tag =~ $pr_regex ]]; then
                pr_num=${BASH_REMATCH[1]}
                CONFIG_DIGEST=$(curl -s -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "${dockerRegistryUrl}/v2/${image}/manifests/$tag" | jq -r .config.digest)
                LABELS=$(curl -sL "${dockerRegistryUrl}/v2/${image}/blobs/$CONFIG_DIGEST" | jq -r '.container_config.Labels')
                SCM=$(echo $LABELS | jq -r '."org.opencontainers.image.source"')
                if [ "${SCM}" = 'null' ]; then
                    SCM=$(echo $LABELS | jq -r '."org.nuxeo.scm-url"')
                fi
                if [ "${SCM}" = 'null' ]; then
                    SCM=$(echo $LABELS | jq -r '."scm-url"')
                fi
                repo=${SCM#*github.com?nuxeo/}
                repo=${repo%.git}
                if [ "${repo}" != 'null' ]; then
                    state=$(curl -sL -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/nuxeo/$repo/pulls/$pr_num" | jq -r .state)
                    if [[ $state == 'open' ]]; then
                        printf "keep (open PR)\n"
                        continue
                    fi
                else
                    printf "image %s:%s is missing SCM label\n" "$image" "$tag" >&2
                fi
            fi
            if [ "${doPurge}" = "true" ]; then
                printf "delete\n"
                deleteTag "$image" "$tag"
            else
                printf "(dry run) delete\n"
            fi
        done

    fi
    echo
done
echo

if [ "${doPurge}" = "true" -o "${deleteCacheImages}" = "true" ]; then
    echo 'Garbage collection:'
    execDockerRegistry "/bin/registry garbage-collect /etc/docker/registry/config.yml" | grep 'blobs eligible for deletion'
    echo

    echo 'Space after cleanup:'
    space
    echo

    usedAfter=$(used)
    cleanedUp=$(((usedBefore - usedAfter) / 1024))
    echo "Cleaned up $cleanedUp Mo"
    echo
fi
