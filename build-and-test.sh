#!/bin/sh -x

HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

# Cleaning
rm -rf ./jboss ./results ./download
mkdir ./results ./download || exit 1

# Build
update_distribution_source

setup_jboss

build_and_deploy

# Start
start_jboss

# Run selenium tests
HIDE_FF=true "$NXDIR"/nuxeo-distribution/nuxeo-platform-ear/ftest/selenium/run.sh
ret1=$?



# Stop nuxeo
stop_jboss

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
