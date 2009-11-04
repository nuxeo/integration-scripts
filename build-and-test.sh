#!/bin/bash -x

HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib-new.sh

# Cleaning
rm -rf ./jboss ./results ./download
mkdir ./results ./download || exit 1

# Build
update_distribution_source
build_jboss
NEW_JBOSS=true
setup_jboss
deploy_ear

# Start Nuxeo
start_jboss

# Run selenium tests
SELENIUM_PATH=${SELENIUM_PATH:-nuxeo-distribution/nuxeo-distribution-dm/ftest/selenium}
HIDE_FF=true "$NXDISTRIBUTION"/"$SELENIUM_PATH"/run.sh
ret1=$?

# Stop nuxeo
stop_jboss

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
