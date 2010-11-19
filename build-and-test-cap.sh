#!/bin/bash -x

PRODUCT=cap
SERVER=${SERVER:-jboss}
HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

# Cleaning
rm -rf ./jboss ./results ./download
mkdir ./results ./download || exit 1

# Build
update_distribution_source
build_cap

if [ "$SERVER" = "tomcat" ]; then
    NEW_TOMCAT=true
    setup_tomcat 127.0.0.1
else
    NEW_JBOSS=true
    setup_jboss 127.0.0.1
    deploy_ear
fi

# Setup PostgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_postgresql_database
fi

# Start Nuxeo
start_server 127.0.0.1

# Run selenium tests
SELENIUM_PATH=${SELENIUM_PATH:-"$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/selenium}
SUITES="suite1 suite2 suite-webengine" HIDE_FF=true URL=http://127.0.0.1:8080/nuxeo/ "$SELENIUM_PATH"/run.sh
ret1=$?

# Stop nuxeo
stop_server

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
