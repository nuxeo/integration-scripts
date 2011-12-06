#!/bin/bash
# default on 5.5 integration build
HERE=$(cd $(dirname $0); pwd -P)

. $HERE/integration-lib.sh

ADDONS=${ADDONS:-}
if [ -z "$TAG" ]; then unset TAG; fi
if [ -z "$NO_MERGE" ]; then unset NO_MERGE; fi
TAG=${TAG:-"-I"$(date +"%Y%m%d_%H%M")}
if [ $TAG = "final" ]; then
    # final release no more tag
    TAG=
    if [ "$NO_MERGE" = "false" ]; then
        unset NO_MERGE
    else
        NO_MERGE=true
    fi
fi
# label for the zip package
LABEL=${LABEL:-}
DISTRIBUTIONS=${DISTRIBUTIONS:-"DEFAULT"}

# dev workspace
DWS="$HERE"/dev
# release workspace
RWS="$HERE"/release

mkdir -p $DWS || exit 1
cd $DWS
nx-builder clone || exit 2

[ -e $RWS ] && rm -rf $RWS
mkdir $RWS || exit 1
cd $RWS || exit 1

NX_BRANCH=${NX_BRANCH:-5.5}
NX_SNAPSHOT=${NX_SNAPSHOT:-5.5-SNAPSHOT}
NX_TAG_TMP=`echo $NX_SNAPSHOT|cut -f1 -d "-"`
NX_TAG=${NX_TAG:-$NX_TAG_TMP$TAG}
NX_NEXT_SNAPSHOT=${NX_NEXT_SNAPSHOT:-5.5-SNAPSHOT}

# setup nx configuration file
cat > nx-builder.conf <<EOF
NX_HG=$DWS/nuxeo
MVNOPTS=
MAVEN_PROFILES=all-distributions
JBOSS_PATCH=patch

NX_BRANCH=$NX_BRANCH
NX_SNAPSHOT=$NX_SNAPSHOT
NX_TAG=$NX_TAG
NX_NEXT_SNAPSHOT=$NX_NEXT_SNAPSHOT

NXADD_MODULES="$ADDONS"

NO_MERGE=$NO_MERGE
NO_BRANCH=$NO_BRANCH

EOF

# Remove existing artifacts
# TODO fix hard coded versions
find ~/.m2/repository/org/nuxeo/ -name "*${NX_TAG:-5.5$TAG}*" -exec rm -rf {} \; 2>/dev/null

nx-builder prepare || exit 1
nx-builder install || exit 1
nx-builder package || exit 1
nx-builder package-sources || exit 1

cp fallback* archives/

## Synchronize repositories between slaves
for i in 1 2; do
    NODE=`lynx --dump "http://qa.nuxeo.org/jenkins/label/IT/api/xml?xpath=/*/node[$i]/nodeName/text()"`
    if [ ! "$HOSTNAME" = "$NODE" ]; then
        find ~/.m2/repository/org/nuxeo/ -name "*${NX_TAG:-5.5$TAG}*" >/tmp/filestosync
        rsync -z --files-from=/tmp/filestosync / $NODE:/
        scp -Cr $HERE/release/archives/*.zip* $HERE/release/archives/mp $NODE:$HERE/release/archives/ || true
    fi
done

exit 0
