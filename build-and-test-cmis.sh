#!/bin/bash

echo DEPRECATED

HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

# Cleaning
rm -rf ./jboss ./results ./download
mkdir ./results ./download || exit 1

# Build
update_distribution_source
build_jboss
NEW_JBOSS=true
setup_jboss 127.0.0.1
deploy_ear

# Setup PostgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_postgresql_database
fi

# Start Nuxeo
start_server 127.0.0.1

# Temporary workaround CMIS-55
stop_server
start_server 127.0.0.1

# FunkLoad tests
(cd "$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/cmis; make EXT="--no-color")
ret1=$?

# Stop nuxeo
stop_server

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
