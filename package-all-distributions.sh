#!/bin/sh -x
# 5.3 specific integration build
HERE=$(cd $(dirname $0); pwd -P)

. $HERE/integration-lib.sh

ADDONS=${ADDONS:-}
TAG=${TAG:-"-I"$(date +"%Y%m%d_%H%M")}
if [ $TAG = "final" ]; then
    # final release no more tag
    TAG=
fi
# label for the zip package
LABEL=${LABEL:-}
DISTRIBUTIONS=${DISTRIBUTIONS:-"ALL"}

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

# setup nx configuration file
cat > nx-builder.conf <<EOF
NX_HG=$DWS/nuxeo
NXA_HG=$DWS/addons
MVNOPTS=
MAVEN_PROFILES=local-deployment,timestamp-rev-in-mf
JBOSS_ARCH=$JBOSS_ARCHIVE
JBOSS_PATCH=patch

NXP_BRANCH=5.3
NXP_SNAPSHOT=5.3.0-SNAPSHOT
NXP_TAG=5.3.0$TAG
NXP_NEXT_SNAPSHOT=5.3.0-SNAPSHOT

NXC_BRANCH=1.6
NXC_SNAPSHOT=1.6.0-SNAPSHOT
NXC_TAG=1.6.0$TAG
NXC_NEXT_SNAPSHOT=1.6.0-SNAPSHOT

# Addons
NXA_BRANCH=5.3
NXA_SNAPSHOT=5.3.0-SNAPSHOT
NXA_TAG=5.3.0$TAG
NXA_NEXT_SNAPSHOT=5.3.0-SNAPSHOT

NXP_BRANCH_NULL_MERGE=
NXC_BRANCH_NULL_MERGE=
NXA_BRANCH_NULL_MERGE=

NXA_MODULES="$ADDONS"

EOF

# Remove existing artifacts
# TODO fix hard coded versions
find ~/.m2/repository/org/nuxeo/ -name "*5.[23].[01]$TAG*" -exec rm -rf {} \; 2>/dev/null
find ~/.m2/repository/org/nuxeo/ -name "*1.[56].[01]$TAG*" -exec rm -rf {} \; 2>/dev/null

nx-builder -d prepare || exit 1

nx-builder -d package || exit 1

if [ $DISTRIBUTIONS = "ALL" ]; then
    jboss_zip=`find $RWS/archives/ -name "nuxeo*jboss*.zip"`

    nx-builder -d package-we || exit 1

#    Get rid of the unused jar version
#    nx-builder -d zip2jar $jboss_zip || exit 1
fi

cp fallback* archives/

exit 0
