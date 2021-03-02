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

PURGE_PATTERN=${PURGE_PATTERN:-'PR|feat|fix|task|master|sprint|SNAPSHOT|bump-regex-version'}
PURGE_FILE="purge.list"

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
    local image="$1"
    local tags
    if $(command -v reg >/dev/null); then
        tags=$(reg tags "${dockerRegistryDomain}/$image" 2>/dev/null)
    else
        tags=$(curl -s "${dockerRegistryUrl}/v2/$image/tags/list" | jq -r '.tags | .[]?')
    fi
    echo "$tags"
}

function deleteTag() {
    if [[ $# != 2 ]]; then
        echo "Wrong number of parameters. Expected: <image> <tag> Got: $*"
        exit 2
    fi
    local image="$1"
    local tag="$2"
    if $(command -v reg >/dev/null); then
        reg rm "${dockerRegistryDomain}/$image:$tag" >/dev/null
    else
        rawDigest=$(curl -v -s -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' "${dockerRegistryUrl}/v2/$image/manifests/$tag" 2>&1 | grep Docker-Content-Digest | awk '{print $3}')
        digest=${rawDigest%$'\r'}
        [ "$digest" ] && curl -s -X DELETE "${dockerRegistryUrl}/v2/$image/manifests/$digest"
    fi
}

# Delete tag or write to PURGE_FILE: image name must be already wrote in the file
function deleteTagWithDryRun() {
    local image="$1"
    local tag="$2"
    if [ -z "$DRY_RUN" ]; then
        deleteTag "$image" "$tag"
    else
        printf "%s " $tag >>"${PURGE_FILE}"
    fi
}

# Delete tags or write to PURGE_FILE: image name must be already wrote in the file
function deleteTagsWithDryRun() {
    if [[ $# -lt 2 ]]; then
        echo "Missing parameters. Expected: <image> <tag>.. Got: $*"
        exit 2
    fi
    local image="$1"
    shift
    if [ -z "$DRY_RUN" ]; then
        for tag in $*; do
            deleteTag "$image" "$tag"
        done
        echo
    else
        echo "$image $*" >>$PURGE_FILE
    fi
}

function getLabels() {
    local image="$1"
    local tag="$2"
    local configDigest=$(curl -s -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "${dockerRegistryUrl}/v2/${image}/manifests/$tag" | jq -r .config.digest)
    curl -sL "${dockerRegistryUrl}/v2/${image}/blobs/$configDigest" | jq -r '.config.Labels'
}

function getRepoFromLabels() {
    local labels="$*"
    local scm=$(echo $labels | jq -r '."org.opencontainers.image.source"')
    if [ "${scm}" = 'null' ]; then
        scm=$(echo $labels | jq -r '."org.nuxeo.scm-url"')
    fi
    if [ "${scm}" = 'null' ]; then
        scm=$(echo $labels | jq -r '."scm-url"')
    fi
    local repo=${scm#*github.com?}
    echo ${repo%.git}
}

#"org.opencontainers.image.revision": "5845f78cfd482b24cafb1898967390f815ef79ee (HEAD, origin/internal-audit-propagation)",
function getBranchFromLabels() {
    local labels="$*"
    local ref=$(echo $labels | jq -r '."org.opencontainers.image.revision"')
    if [ "${ref}" = 'null' ]; then
        ref=$(echo $labels | jq -r '."org.nuxeo.scm-ref"')
    fi
    if [ "${ref}" = 'null' ]; then
        ref=$(echo $labels | jq -r '."scm-ref"')
    fi
    local branchPattern="^[0-9a-f]+.*origin\/([-_.0-9A-Za-z]*).*$"
    if [[ $ref =~ $branchPattern ]]; then
        local branch="${BASH_REMATCH[1]}"
    fi
    echo "$branch"
}

echo '=========================='
echo '- Purge Docker registry! -'
echo '=========================='
if [[ $1 = "-h" || $1 = "--help" || $# -gt 1 ]]; then
    echo
    echo "  Usage: $(basename "$0") [-h|--help] [<deleteCacheImages>=false]"
    echo
    echo " Environment properties:"
    echo "   - GITHUB_TOKEN: (required)"
    echo "   - KUBE_NS: (required) Kubernetes namespace hosting the Docker registry"
    echo "   - DRY_RUN: If true, no tag is deleted but wrote in $PURGE_FILE for optional use with deleteTags.sh"
    echo "   - IMAGES: Fixed list of images. If unset, all the images are analyzed."
    exit 0
fi

: "${GITHUB_TOKEN:?}"
: "${KUBE_NS:?}"
dockerRegistryPod=$(kubectl -n "$KUBE_NS" get pod -l app=docker-registry -o jsonpath="{.items[0].metadata.name}")
dockerRegistryUrl=$(kubectl -n "$KUBE_NS" get svc jenkins-x-docker-registry -o jsonpath='{.metadata.annotations.fabric8\.io/exposeUrl}')
dockerRegistryDomain=${dockerRegistryUrl#*://}
deleteCacheImages=$([ "$1" = "true" ] && echo -n "true" || echo -n "false")
echo
echo '  Parameters:'
echo "    - Host: ${dockerRegistryUrl}"
echo "    - PURGE_PATTERN: ${PURGE_PATTERN}"
echo "    - delete cache images: ${deleteCacheImages}"
echo

if [ "$DRY_RUN" = "true" ]; then
    echo "### DRY_RUN ###"
else
    unset DRY_RUN
fi

echo "Working on $dockerRegistryPod"
echo 'Space before cleanup:'
space
echo
usedBefore=$(used)

images=${IMAGES:-$(curl -s --connect-timeout 3 "${dockerRegistryUrl}/v2/_catalog" | jq -r '.repositories | .[]?')}
printf 'Images: %s\n' "${images//$'\n'/ }"

rm -f "${PURGE_FILE}" "${PURGE_FILE}.ignored"
for image in $images; do
    printf "\nImage %s:\n" "$image"
    allTags=$(getTags "$image")

    # cache image
    if [[ ${image} =~ .*/cache.*$ ]]; then
        if [ "${deleteCacheImages}" = "true" ]; then
            printf "* delete all digests\n"
            deleteTagsWithDryRun "$image" $allTags
        else
            printf "* ignore cache\n"
        fi
        continue
    fi

    # ignored tags are listed in "${PURGE_FILE}.ignored"
    tags=$(echo "$allTags" | grep -i -E "$PURGE_PATTERN" || true)
    tagsIgnored=$(comm -3 <(echo "$allTags" | sort) <(echo "$tags" | sort))
    printf "* tags ignored: %s\n" "$tagsIgnored"
    printf "%s\n" "$image" >>"${PURGE_FILE}.ignored"
    printf "\t%s\n" $tagsIgnored >>"${PURGE_FILE}.ignored"
    if [ -z "$tags" ]; then
        printf "* no tags matching '%s'\n" "$PURGE_PATTERN"
        continue
    fi
    if [ -n "$DRY_RUN" ]; then
        printf "%s " $image >>"${PURGE_FILE}"
    fi
    printf "* matching tags: %s\n" "${tags//$'\n'/ }"
    for tag in $tags; do
        printf "* tag %s ..." "$tag"
        labels=$(getLabels "$image" "$tag")
        printf "%s" "$labels" >"/tmp/debug-${image##*/}-$tag.labels"
        repo=$(getRepoFromLabels "$labels")
        if [ "${repo}" = 'null' ] || [ -z "$repo" ]; then
            printf "%$((50 - ${#tag}))s image '%s:%s' is missing scm label\n" '' "$image" "$tag"
            continue
        fi

        # delete image if from closed PR
        printf "."
        prPattern='.*-PR-([0-9]+).*'
        if [[ $tag =~ $prPattern ]]; then
            prNum=${BASH_REMATCH[1]}
            state="$(curl -sL -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$repo/pulls/$prNum" | jq -r '.state')"
            if [[ $state == 'open' ]]; then
                printf "%$((49 - ${#tag}))s keep (PR '%s/%s' status: %s)\n" '' "$repo" "$prNum" "$state"
                continue
            fi
            printf "%$((49 - ${#tag}))s delete (PR '%s/%s' status: %s)\n" '' "$repo" "$prNum" "$state"
            deleteTagWithDryRun "$image" "$tag"
            continue
        fi

        # delete image if from closed branch
        printf "."
        branch="$(getBranchFromLabels "$labels")"
        if [ "${branch}" = 'null' ] || [ -z "$branch" ]; then
            printf "%$((48 - ${#tag}))s image '%s:%s' is missing branch label\n" '' "$image" "$tag"
            continue
        fi
        printf "."
        gitRef="$(curl -sL -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$repo/branches/$branch" | jq -r '.name')"
        if [ "${gitRef}" = 'null' ]; then
            printf "%$((47 - ${#tag}))s delete (no branch '%s')\n" '' "$branch"
            deleteTagWithDryRun "$image" "$tag"
            continue
        fi

        # delete image if from PR'd branch
        printf "."
        prNum="$(curl -sL -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$repo/pulls?head=nuxeo:$branch" | jq -r ".[].number")"
        if [ -n "$prNum" ]; then
            printf "%$((46 - ${#tag}))s delete (PR '%s/%s' status: %s)\n" '' "$repo" "$prNum" "$state"
            deleteTagWithDryRun "$image" "$tag"
            continue
        fi

        # delete obsolete SNAPSHOT, master or sprint versions which have been released
        printf "."
        versionPattern="^([-.0-9]+)-($PURGE_PATTERN).*$"
        if [[ $tag =~ $versionPattern ]]; then
            release="${BASH_REMATCH[1]}"
            if (echo "$allTags"|grep -qx "$release"); then
                printf "%$((45 - ${#tag}))s delete (release exists '%s')\n" '' "$release"
                deleteTagWithDryRun "$image" "$tag"
                continue
            fi
        fi

        printf "%$((45 - ${#tag}))s keep (branch %s)\n" '' "$branch"
    done
    if [ -n "$DRY_RUN" ]; then
        printf "\n" >>"${PURGE_FILE}"
    fi
done
echo

if [ -z "$DRY_RUN" ]; then
    echo 'Garbage collection:'
    execDockerRegistry "/bin/registry garbage-collect -n /etc/docker/registry/config.yml" | grep 'blobs eligible for deletion'
    echo

    echo 'Space after cleanup:'
    space
    echo

    usedAfter=$(used)
    cleanedUp=$(((usedBefore - usedAfter) / 1024))
    echo "Cleaned up $cleanedUp Mo"
    echo
else
    echo "DRY_RUN mode was activated, you can review the file '$PURGE_FILE' then run './deleteTags.sh $PURGE_FILE'"
fi
