#!/bin/sh -x

JBOSS_ARCHIVE=${JBOSS_ARCHIVE:-~/archive/jboss42.zip}
ADDONS=${ADDONS:-}
# dev workspace
DWS=$(pwd)/dev
# release workspace
RWS=$(pwd)/release
TAG="I"$(date +"%Y%m%d_%H%M")

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
cat > nx-builder.conf <<EOF
NX_HG=$DWS/nuxeo
NXA_HG=$DWS/addons
MVNOPTS=
MAVEN_PROFILES=local-deployment,timestamp-rev-in-mf
JBOSS_ARCH=$JBOSS_ARCHIVE
JBOSS_PATCH=patch

NXP_BRANCH=5.2
NXP_SNAPSHOT=5.2-SNAPSHOT
NXP_TAG=5.2-$TAG
NXP_NEXT_SNAPSHOT=5.2-SNAPSHOT

NXC_BRANCH=1.5
NXC_SNAPSHOT=1.5-SNAPSHOT
NXC_TAG=1.5-$TAG
NXC_NEXT_SNAPSHOT=1.5-SNAPSHOT

# Addons
NXA_BRANCH=5.2
NXA_SNAPSHOT=5.2-SNAPSHOT
NXA_TAG=5.2-$TAG
NXA_NEXT_SNAPSHOT=5.2-SNAPSHOT

NXP_BRANCH_NULL_MERGE=
NXC_BRANCH_NULL_MERGE=
NXA_BRANCH_NULL_MERGE=

NXA_MODULES="$ADDONS"

EOF

nx-builder prepare || exit 1

nx-builder package || exit 1

# build a tar file to bundle the release
cd archives
for f in `ls *.zip`; do md5sum $f > $f.md5 ; tar cvf build.tar $f $f.md5; done
