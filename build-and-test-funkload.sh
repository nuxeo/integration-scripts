#!/bin/bash -x

HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

# Cleaning
rm -rf ./jboss ./results ./download
mkdir ./results ./download || exit 1

# Build
update_distribution_source

setup_jboss

build_and_deploy

# Setup PostgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_database
fi

# Start
start_jboss

java -version  2>&1 | grep 1.6.0
if [ $? == 0 ]; then
    # FunkLoad tests works only with java 1.6.0 (j_ids are changed by java6)
    (cd "$NXDIR"/nuxeo-distribution/nuxeo-distribution-dm/ftest/funkload; make EXT="--no-color")
    ret1=$?
else
    echo "### JAVA 6 required to run funkload tests."
    ret1=9
fi


# Stop nuxeo
stop_jboss

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
