#!/bin/bash -x

HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

# Cleaning
rm -rf ./jboss ./results ./download ./report
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

echo "Benching nuxeo ep ..."
ret1=$?

test_path=$NXDIR/nuxeo-distribution/nuxeo-distribution-dm/ftest/funkload/
(cd $test_path; make bench EXT="--no-color"; ret=$?; make stop; exit $ret)
ret1=$?
mv $NXDIR/nuxeo-distribution/nuxeo-distribution-dm/target/ftest/funkload/report .


# Stop nuxeo
stop_jboss

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
