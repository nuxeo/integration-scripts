#!/bin/bash

if [ "$NXVERSION" != "5.4.1" ]; then
    echo DEPRECATED since Nuxeo 5.4.2
    exit 1
fi

PRODUCT=${PRODUCT:-dm}
SERVER=tomcat
HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

# Cleaning
rm -rf ./tomcat ./results ./download
mkdir ./results ./download || exit 1

# Build
update_distribution_source
build_tomcat
# create new Tomcat distribution each time as we don't have a build for nuxeo Tomcat webapp only
NEW_TOMCAT=true
setup_tomcat 127.0.0.1

# Setup PostgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_postgresql_database
fi

# Start Nuxeo
start_server

# Run selenium tests (not the webengine suite)
SELENIUM_PATH=${SELENIUM_PATH:-"$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/selenium}
HIDE_FF=true URL=http://127.0.0.1:8080/nuxeo/ "$SELENIUM_PATH"/run.sh
ret1=$?

# Stop Nuxeo
stop_server

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
