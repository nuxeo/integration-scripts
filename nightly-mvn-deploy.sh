#!/bin/bash
# 5.4 nightly artifacts snapshot deploy
HERE=$(cd $(dirname $0); pwd -P)

. $HERE/integration-lib.sh

DWS="$HERE"/src
NX=${NX:-5.4}
MAVEN_OPTS=${MAVEN_OPTS:-"-Xmx2048m -Xms512m -XX:MaxPermSize=384m"}
export MAVEN_OPTS

if [ ! -e $DWS ]; then
    mkdir -p $DWS || exit 1
    cd $DWS
    nx-builder clone || exit 2
else
    cd $DWS
    nx-builder pull || exit 2
fi

# Remove existing artifacts
find ~/.m2/repository/org/nuxeo/ -name "*$NX*SNAPSHOT*" -delete 2>/dev/null

cd $DWS/nuxeo || exit 1
. scripts/hgfunctions.sh
hgf up -C $NX
hgf purge --all
mvn -Dmaven.test.skip=true clean deploy -Pnightly,all-distributions || exit 1

exit 0
