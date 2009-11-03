#!/bin/bash -x

. $HERE/integration-lib-new.sh

# Cleaning
rm -rf ./jboss ./results ./download
mkdir ./results ./download || exit 1

# Build
update_distribution_source

setup_jboss

# Start Nuxeo
start_jboss

# Run selenium tests
SELENIUM_PATH=${SELENIUM_PATH:-nuxeo-distribution/nuxeo-distribution-dm/ftest/selenium}
HIDE_FF=true "$NXDIR"/"$SELENIUM_PATH"/run.sh
ret1=$?

# Stop nuxeo
stop_jboss

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
