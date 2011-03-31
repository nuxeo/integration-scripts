#!/bin/bash -x

PRODUCT=${PRODUCT:-dm}
SERVER=${SERVER:-jboss}
BENCH_TARGET=${BENCH_TARGET:-bench-long}
HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

# Cleaning
rm -rf ./jboss ./report ./results ./download
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

# Run the bench
echo "Benching nuxeo ep ..."
test_path="$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/funkload/
(cd $test_path; make $BENCH_TARGET EXT="--no-color"; ret=$?; make stop; exit $ret)
ret1=$?

# Move the bench report
mv "$NXDISTRIBUTION"/nuxeo-distribution-dm/target/ftest/funkload/report .

# Stop nuxeo
stop_server

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
