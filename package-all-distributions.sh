#!/bin/bash -x
# default on 5.4 integration build
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
DEFAULT_ADDONS=${DEFAULT_ADDONS:-"nuxeo-platform-lang-ext
nuxeo-chemistry
nuxeo-http-client
nuxeo-platform-classification
nuxeo-platform-document-routing
nuxeo-platform-error-web
nuxeo-platform-faceted-search
nuxeo-platform-forms-layout-demo
nuxeo-platform-high-availability
nuxeo-platform-importer
nuxeo-platform-login
nuxeo-correspondence-marianne
nuxeo-platform-smart-search
nuxeo-platform-sync
nuxeo-platform-video
nuxeo-platform-audio"}

# dev workspace
DWS="$HERE"/dev
# release workspace
RWS="$HERE"/release

if [ ! -e $DWS ]; then
    mkdir -p $DWS || exit 1
    cd $DWS
    nx-builder clone || exit 2
else
    cd $DWS
    nx-builder pull || exit 2
fi

[ -e $RWS ] && rm -rf $RWS
mkdir $RWS || exit 1
cd $RWS || exit 1

NX_BRANCH=${NX_BRANCH:-5.4}
NX_SNAPSHOT=${NX_SNAPSHOT:-5.4.1-SNAPSHOT}
NX_TAG_TMP=`echo $NX_SNAPSHOT|cut -f1 -d "-"`
NX_TAG=${NX_TAG:-$NX_TAG_TMP$TAG}
NX_NEXT_SNAPSHOT=${NX_NEXT_SNAPSHOT:-5.4.1-SNAPSHOT}

# Addons
NXA_BRANCH=${NXA_BRANCH:-5.4}
NXA_SNAPSHOT=${NXA_SNAPSHOT:-5.4.1-SNAPSHOT}
NXA_TAG_TMP=`echo $NXA_SNAPSHOT|cut -f1 -d "-"`
NXA_TAG=${NXA_TAG:-$NXA_TAG_TMP$TAG}
NXA_NEXT_SNAPSHOT=${NXA_NEXT_SNAPSHOT:-5.4.1-SNAPSHOT}

# setup nx configuration file
cat > nx-builder.conf <<EOF
NX_HG=$DWS/nuxeo
NXA_HG=$DWS/addons
MVNOPTS=
MAVEN_PROFILES=all-distributions
JBOSS_PATCH=patch

NX_BRANCH=$NX_BRANCH
NX_SNAPSHOT=$NX_SNAPSHOT
NX_TAG=$NX_TAG
NX_NEXT_SNAPSHOT=$NX_NEXT_SNAPSHOT

# Addons
NXA_BRANCH=$NXA_BRANCH
NXA_SNAPSHOT=$NXA_SNAPSHOT
NXA_TAG=$NXA_TAG
NXA_NEXT_SNAPSHOT=$NXA_NEXT_SNAPSHOT

NX_BRANCH_NULL_MERGE=${NX_BRANCH_NULL_MERGE}
NXA_BRANCH_NULL_MERGE=${NXA_BRANCH_NULL_MERGE}

NXA_MODULES="$DEFAULT_ADDONS $ADDONS"

NO_MERGE=$NO_MERGE
NO_BRANCH=$NO_BRANCH

EOF

# Remove existing artifacts
# TODO fix hard coded versions
find ~/.m2/repository/org/nuxeo/ -name "*${NX_TAG:-5.4.1$TAG}*" -exec rm -rf {} \; 2>/dev/null

nx-builder -d prepare || exit 1
nx-builder -d install || exit 1
nx-builder -d package || exit 1
nx-builder -d package-sources || exit 1

cp fallback* archives/

exit 0
