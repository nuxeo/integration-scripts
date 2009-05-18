#!/bin/bash -x
HERE=$(cd $(dirname $0); pwd -P)

. $HERE/integration-lib.sh

BUILD_URL=${BUILD_URL:-http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Integration_build/lastSuccessfulBuild/artifact/trunk/release/archives}
UPLOAD_URL=${UPLOAD_URL:-}
ZIP_FILE=${ZIP_FILE:-}

# Cleaning
rm -rf ./jboss ./results ./download
mkdir ./results ./download || exit 1

cd download
if [ -z $ZIP_FILE ]; then
    # extract list of links
    links=`lynx --dump $BUILD_URL | grep -o "http:.*nuxeo\-.*.zip\(.md5\)*" | sort -u`

    # Download and unpack the lastest builds
    for link in $links; do
        wget -nv $link || exit 1
    done

    unzip -q nuxeo-*jboss*.zip
else
    unzip -q $ZIP_FILE || exit 1
fi
cd ..

# JBOSS tests --------------------------------------------------------

build=$(find ./download -maxdepth 1 -name 'nuxeo-*'  -type d)
mv $build ./jboss || exit 1


# Update selenium tests
update_distribution_source

# Use postgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_database
fi

# Start jboss
start_jboss

# Run selenium tests first
# it requires an empty db
HIDE_FF=true "$NXDIR"/nuxeo-distribution/nuxeo-distribution-dm/ftest/selenium/run.sh
ret1=$?

# Run simple rest, web and webengine tests
(cd "$NXDIR"/nuxeo-distribution/nuxeo-distribution-dm/ftest/funkload; make)
ret2=$?

# TODO: test nuxeo shell
#(cd "$NXDIR"/nuxeo-distribution/nuxeo-distribution-shell/ftest/; make)
ret3=$?


# Stop nuxeo
stop_jboss

# Exit if some tests failed
[ $ret1 -eq 0 -a $ret2 -eq 0 ] || exit 9
[ $ret3 -eq 0 ] || exit 9

# JBOSS tests --------------------------------------------------------

# TODO process jetty and glassfish


# Upload succesfully tested package on http://www.nuxeo.org/static/snapshots/
if [ ! -z $UPLOAD_URL ]; then
    date
    scp download/*jboss* $UPLOAD_URL || exit 1
    date
fi
