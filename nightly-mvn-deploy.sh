#!/bin/sh -x
# 5.3 nightly artifacts snapshot deploy
HERE=$(cd $(dirname $0); pwd -P)

. $HERE/integration-lib.sh

DWS="$HERE"/src
NXP=${NXP:-5.3}
NXC=${NXC:-1.6}

if [ ! -e $DWS ]; then
    mkdir -p $DWS || exit 1
    cd $DWS
    nx-builder clone || exit 2
else
    cd $DWS
    nx-builder pull || exit 2
fi

# Remove existing artifacts
find ~/.m2/repository/org/nuxeo/ -name "*$NXP*SNAPSHOT*" -delete 2>/dev/null
find ~/.m2/repository/org/nuxeo/ -name "*$NXC*SNAPSHOT*" -delete 2>/dev/null

cd $DWS/nuxeo || exit 1

hgx $NXP $NXC up -C

mvn -Dmaven.test.skip=true -DupdateReleaseInfo=true install deploy -Pall-distributions || exit 1

exit 0
