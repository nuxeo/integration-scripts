#!/bin/bash -x

HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib-new.sh

JBOSS_HOME_SF="$JBOSS_HOME"-sf
JBOSS_HOME_SL="$JBOSS_HOME"-sl

# Cleaning
rm -rf ./jboss ./results ./download
mkdir ./results ./download || exit 1

# Build
update_distribution_source

build_jboss

setup_jboss "$JBOSS_HOME_SF"
setup_jboss "$JBOSS_HOME_SL"

(cd "$NXDISTRIBUTION"/nuxeo-distribution-dm/ && ./package.sh nuxeo-2parts) || exit 1
deploySRCtoDST "$NXDISTRIBUTION"/nuxeo-distribution-dm/target/nuxeo-platform-stateful.ear "$JBOSS_HOME_SF"/server/default/deploy/nuxeo.ear
deploySRCtoDST "$NXDISTRIBUTION"/nuxeo-distribution-dm/target/nuxeo-web-stateless.ear "$JBOSS_HOME_SL"/server/default/deploy/nuxeo.ear

# Setup PostgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_database
fi

# Start Nuxeo
start_jboss "$JBOSS_HOME_SF" 127.0.1.1
start_jboss "$JBOSS_HOME_SL" 127.0.1.2

# Run selenium tests (not the webengine suite)
SELENIUM_PATH=${SELENIUM_PATH:-nuxeo-distribution-dm/ftest/selenium}
HIDE_FF=true URL=http://127.0.1.2:8080/nuxeo/ SUITES="suite1 suite2 suite-dm" "$NXDISTRIBUTION"/"$SELENIUM_PATH"/run.sh
ret1=$?

# Stop Nuxeo
stop_jboss "$JBOSS_HOME_SL"
stop_jboss "$JBOSS_HOME_SF"

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
