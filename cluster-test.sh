#!/bin/bash -x
HERE=$(cd $(dirname $0); pwd -P)

. $HERE/integration-lib.sh

BUILD_URL=${BUILD_URL:-http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Integration_build/lastSuccessfulBuild/artifact/trunk/release/archives}
UPLOAD_URL=${UPLOAD_URL:-}
ZIP_FILE=${ZIP_FILE:-}


# Cleaning
rm -rf ./jboss ./jboss2 ./results ./download ./report
mkdir ./results ./download || exit 1

cd download
if [ -z $ZIP_FILE ]; then
    # extract list of links
    links=`lynx --dump $BUILD_URL | grep -o "http:.*nuxeo\-dm.*.zip" | sort -u`

    # Download and unpack the lastest builds
    for link in $links; do
        wget -nv $link || exit 1
    done

    unzip -q nuxeo-*jboss*.zip
else
    unzip -q $ZIP_FILE || exit 1
fi
cd ..


build=$(find ./download -maxdepth 1 -name 'nuxeo-*'  -type d)
mv $build ./jboss || exit 1


# Update selenium tests
update_distribution_source

# Use postgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_database
fi

# remove ooo daemon
cp ./ooo-config.xml $JBOSS_HOME/server/default/deploy/nuxeo.ear/config/

# setup cluster mode
cp ./default-repository-config.xml $JBOSS_HOME/server/default/deploy/nuxeo.ear/config/default-repository-config.xml

# setup jboss2
cp -r ./jboss ./jboss2

# Start --------------------------------------------------
# start pound
pound -f ./pound.cfg -p ./pound.pid || exit 1

# Start jbosses
JBOSS_HOME="$HERE/jboss"
start_jboss 127.0.1.1

JBOSS_HOME="$HERE/jboss2"
start_jboss 127.0.1.2

# Test --------------------------------------------------
# Run selenium tests first
# it requires an empty db

URL=http://127.0.0.1:8000/nuxeo/ HIDE_FF=true "$NXDIR"/nuxeo-distribution/nuxeo-distribution-dm/ftest/selenium/run.sh
ret1=$?

# FunkLoad bench
#test_path=$NXDIR/nuxeo-distribution/nuxeo-distribution-dm/ftest/funkload/
#(cd $test_path; make bench EXT="--no-color" URL=http://127.0.0.1:8000/nuxeo; ret=$?; make stop; exit $ret)
#ret1=$?
#mv $NXDIR/nuxeo-distribution/nuxeo-distribution-dm/target/ftest/funkload/report .



# Stop --------------------------------------------------

kill `cat ./pound.pid`
JBOSS_HOME="$HERE/jboss"
stop_jboss
JBOSS_HOME="$HERE/jboss2"
stop_jboss

cd "$HERE/jboss2/server/default/log"
for log in *.log.gz; do
    cp  $log "$HERE/jboss/server/default/log/"${log%.log.gz}2.log.gz
done

exit $ret1
