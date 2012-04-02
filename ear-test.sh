#!/bin/bash

CURRENT_DEV_VERSION="5.6-SNAPSHOT"

# JBoss location:
JBOSS_ZIP_FILE=${JBOSS_ZIP_FILE:-}
JBOSS_REPO_URL=${JBOSS_REPO_URL:-"http://maven.in.nuxeo.com/nexus/"}
JBOSS_GROUPID=${JBOSS_GROUPID:-"org.jboss"}
JBOSS_ARTIFACTID=${JBOSS_ARTIFACTID:-"jboss-as"}
JBOSS_VERSION=${JBOSS_VERSION:-"5.1.0.GA"}
JBOSS_CLASSIFIER=${JBOSS_CLASSIFIER:-"light"}
JBOSS_PACKAGING="zip"

# EAR location:
EAR_ZIP_FILE=${EAR_ZIP_FILE:-}
EAR_REPO_URL=${EAR_REPO_URL:-"http://maven.in.nuxeo.com/nexus/"}
EAR_GROUPID=${EAR_GROUPID:-"org.nuxeo.ecm.distribution"}
EAR_ARTIFACTID=${EAR_ARTIFACTID:-"nuxeo-distribution-jboss"}
EAR_VERSION=${EAR_VERSION:-$CURRENT_DEV_VERSION}
EAR_CLASSIFIER=${EAR_CLASSIFIER:-"nuxeo-cap-ear"}
EAR_PACKAGING="zip"

# Try to guess NXVERSION and NXTAG from EAR_VERSION
# This is tricky, so it's better to set them explicitly
if [ -z "$NXVERSION" ]; then
    if [ "$EAR_VERSION" = "$CURRENT_DEV_VERSION" ]; then
        NXVERSION="master"
    else
        NXVERSION=${EAR_VERSION//-SNAPSHOT/}
        if [[ "$NXVERSION" =~ -HF[0-9][0-9] ]]; then
            NXTAG="release-$NXVERSION"
            NXVERSION=${NXVERSION//-HF[0-9][0-9]/}
        fi
        echo "********************************************************************"
        echo "*"
        echo "* Using NXVERSION=$NXVERSION and NXTAG=$NXTAG"
        echo "* Please set them explicitely if this is wrong"
        echo "*"
        echo "********************************************************************"
    fi
fi

# Misc
SERVER="jboss"
HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

# Comment out to enable monitoring
SKIP_MONITORING=true

# Cleaning
rm -rf "${SERVER_HOME}" download
mkdir download || exit 1

pushd download

# Download and extract base JBoss

if [ -z "${JBOSS_ZIP_FILE}" ]; then
    mvn org.apache.maven.plugins:maven-dependency-plugin:2.4:get -DremoteRepositories=${JBOSS_REPO_URL} -DgroupId=${JBOSS_GROUPID} -DartifactId=${JBOSS_ARTIFACTID} -Dversion=${JBOSS_VERSION} -Dpackaging=${JBOSS_PACKAGING} -Dclassifier=${JBOSS_CLASSIFIER} -Dtransitive=false -Ddest=jboss.zip
    unzip -q jboss.zip
    rm jboss.zip
else
    unzip -q "${JBOSS_ZIP_FILE}"
fi
build=$(find . -mindepth 1 -maxdepth 1 -type d)
mv $build "${SERVER_HOME}" || exit 1

# Overlay Nuxeo's EAR+
if [ -z "${EAR_ZIP_FILE}" ]; then
    mvn org.apache.maven.plugins:maven-dependency-plugin:2.4:get -DremoteRepositories=${EAR_REPO_URL} -DgroupId=${EAR_GROUPID} -DartifactId=${EAR_ARTIFACTID} -Dversion=${EAR_VERSION} -Dpackaging=${EAR_PACKAGING} -Dclassifier=${EAR_CLASSIFIER} -Dtransitive=false -Ddest=ear.zip
    unzip -q ear.zip
    rm ear.zip
else
    unzip -q "${EAR_ZIP_FILE}"
fi

# Temporary fix
find . -type f -name 'hibernate-core.jar' -exec rm {} \;

rsync -Wax */* "${SERVER_HOME}/"

popd

# Update selenium tests
if [ ! -d "$NXDISTRIBUTION" ]; then
    mkdir -p `dirname "$NXDISTRIBUTION"`
    git clone https://github.com/nuxeo/nuxeo-distribution.git "$NXDISTRIBUTION" || exit 1
fi
(cd "$NXDISTRIBUTION" && git checkout master && git fetch --tags && git pull --all&& git checkout $NXVERSION) || exit 1
if [ ! -z $NXTAG ]; then
    (cd "$NXDISTRIBUTION" && git checkout $NXTAG) || exit 1
fi

# TODO : DB setup
#if [ ! -z $PGPASSWORD ]; then
#    setup_database "$HERE/jboss"
#fi

#Setup and start JBoss
setup_jboss "$SERVER_HOME" 127.0.0.1
start_server "$SERVER_HOME" 127.0.0.1

# Test --------------------------------------------------
# Run selenium tests
SELENIUM_PATH=${SELENIUM_PATH:-"$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/selenium}
pushd $SELENIUM_PATH
rm -f result-*.html
rm -rf target
if [ -f "run.sh" ]; then
    ./run.sh
else
    mvn org.nuxeo.build:nuxeo-distribution-tools:integration-test -Dtarget=run-selenium -Dsuites=suite1,suite2,suite-dm,suite-webengine,suite-webengine-website,suite-webengine-tags -DnuxeoURL=http://127.0.0.1:8080/nuxeo/
fi
ret1=$?
popd

stop_server "$SERVER_HOME"

exit $ret1
