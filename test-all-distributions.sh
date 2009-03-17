#!/bin/sh -x
HERE=$(cd $(dirname $0); pwd -P)

. $HERE/integration-lib.sh

LAST_BUILD_URL=http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Release/lastSuccessfulBuild/artifact/trunk/release/archives
LAST_BUILD=build.tar
DAILY_DOWNLOAD="zope@gironde.nuxeo.com:/home/zope/static/nuxeo.org/snapshots"


# Cleaning
rm -rf ./jboss ./results ./download
mkdir ./results ./download || exit 1

# Download and unpack the last build
cd download
wget -nv $LAST_BUILD_URL/$LAST_BUILD || exit 1
tar xvf $LAST_BUILD || exit 1
unzip -q *.zip
cd ..
build=$(find ./download -maxdepth 1 -name 'nuxeo-ep*'  -type d)
mv $build ./jboss || exit 1


# Update selenium tests
update_distribution_source

# Start jboss
echo "BINDHOST=0.0.0.0" > jboss/bin/bind.conf
./jboss/bin/jbossctl start || exit 1

# Run selenium tests
HIDE_FF=true ./nuxeo-distribution/nuxeo-platform-ear/ftest/selenium/run.sh
ret1=$?

# Stop nuxeo
./jboss/bin/jbossctl stop
gzip jboss/server/default/log/*.log

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9

# Upload succesfully tested package on http://www.nuxeo.org/static/snapshots/
date
scp ${build}.zip.md5 ${build}.zip $DAILY_DOWNLOAD || exit 1
date
