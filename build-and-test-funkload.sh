#!/bin/bash -x

PRODUCT=${PRODUCT:-dm}
SERVER=${SERVER:-jboss}
HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

# Cleaning
rm -rf ./jboss ./results ./download
mkdir ./results ./download || exit 1

# Build
update_distribution_source
if [ "$SERVER" = "tomcat" ]; then
    build_tomcat
    NEW_TOMCAT=true
    setup_tomcat 127.0.0.1
else
    build_jboss
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

# FunkLoad tests
(cd "$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/funkload; make EXT="--no-color")
ret1=$?

# Stop nuxeo
stop_server

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
