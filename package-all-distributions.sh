#!/bin/sh -x
# default on 5.3 integration build
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
DISTRIBUTIONS=${DISTRIBUTIONS:-"DEFAULT"}

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
JBOSS_PATCH=patch

NXP_BRANCH=${NXP_BRANCH:-5.3}
NXP_SNAPSHOT=${NXP_SNAPSHOT:-5.3.1-SNAPSHOT}
NXP_TAG=${NXP_TAG:-5.3.1}$TAG
NXP_NEXT_SNAPSHOT=${NXP_NEXT_SNAPSHOT:-5.3.1-SNAPSHOT}

NXC_BRANCH=${NXC_BRANCH:-1.6}
NXC_SNAPSHOT=${NXC_SNAPSHOT:-1.6.1-SNAPSHOT}
NXC_TAG=${NXC_TAG:-1.6.1}$TAG
NXC_NEXT_SNAPSHOT=${NXC_NEXT_SNAPSHOT:-1.6.1-SNAPSHOT}

# Addons
NXA_BRANCH=${NXA_BRANCH:-5.3}
NXA_SNAPSHOT=${NXA_SNAPSHOT:-5.3.1-SNAPSHOT}
NXA_TAG=${NXA_TAG:-5.3.1}$TAG
NXA_NEXT_SNAPSHOT=${NXA_NEXT_SNAPSHOT:-5.3.1-SNAPSHOT}

NXP_BRANCH_NULL_MERGE=${NXP_BRANCH_NULL_MERGE}
NXC_BRANCH_NULL_MERGE=${NXC_BRANCH_NULL_MERGE}
NXA_BRANCH_NULL_MERGE=${NXA_BRANCH_NULL_MERGE}

NXA_MODULES="nuxeo-chemistry $ADDONS"

EOF

# Remove existing artifacts
# TODO fix hard coded versions
find ~/.m2/repository/org/nuxeo/ -name "*5.[23].[0-9]$TAG*" -exec rm -rf {} \; 2>/dev/null
find ~/.m2/repository/org/nuxeo/ -name "*1.[56].[0-9]$TAG*" -exec rm -rf {} \; 2>/dev/null

nx-builder -d prepare || exit 1
nx-builder -d install || exit 1
nx-builder -d package || exit 1

if [ $DISTRIBUTIONS = "ALL" ]; then
    jboss_zip=`find $RWS/archives/ -name "nuxeo*jboss*.zip"`
# Comment until NXBT-132 is fixed
#    nx-builder -d package-other || exit 1
fi

cp fallback* archives/

exit 0
