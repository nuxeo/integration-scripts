#!/bin/bash -x

HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib-new.sh

# Cleaning
rm -rf ./jboss ./report ./results ./download
mkdir ./results ./download || exit 1

# Build
update_distribution_source
build_jboss
NEW_JBOSS=true
setup_jboss
deploy_ear

# Setup PostgreSQL
if [ ! -z $PGPASSWORD ]; then
    . $HERE/integration-lib.sh
    setup_database
fi

# Start Nuxeo
start_jboss

java -version  2>&1 | grep 1.6.0
if [ $? == 0 ]; then
    echo "Benching nuxeo ep ..."
    # FunkLoad tests works only with java 1.6.0 (j_ids are changed by java6)
    test_path="$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/funkload/
    (cd $test_path; make bench EXT="--no-color"; ret=$?; make stop; exit $ret)
    ret1=$?
    mv "$NXDISTRIBUTION"/nuxeo-distribution-dm/target/ftest/funkload/report .
else
    echo "### JAVA 6 required to run funkload tests."
    ret1=9
fi

# Stop nuxeo
stop_jboss

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
