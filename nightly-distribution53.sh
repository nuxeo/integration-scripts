#!/bin/bash -x
# 5.3 nightly artifacts snapshot deploy
HERE=$(cd $(dirname $0); pwd -P)

. $HERE/integration-lib.sh

DWS="$HERE"/src
NXP=${NXP:-5.3}
NXC=${NXC:-1.6}
MAVEN_OPTS="-Xmx2048m -Xms512m -XX:MaxPermSize=256m"
export MAVEN_OPTS

if [ ! -e $DWS ]; then
    mkdir -p $DWS || exit 1
    cd $DWS
    nx-builder clone || exit 2
else
    cd $DWS
    nx-builder pull || exit 2
fi

cd $DWS/nuxeo/nuxeo-distribution || exit 1

hg up -C $NXP

mvn -Dmaven.test.skip=true clean deploy -Pall-distributions || exit 1

exit 0
