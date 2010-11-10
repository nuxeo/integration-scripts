#!/bin/bash -x
HERE=$(cd $(dirname $0); pwd -P)
SERVER=tomcat
. $HERE/integration-lib.sh

LASTBUILD_URL=${LASTBUILD_URL:-http://qa.nuxeo.org/hudson/job/IT-nuxeo-5.4-build/lastSuccessfulBuild/artifact/trunk/release/archives}
ZIP_FILE=${ZIP_FILE:-}
SKIP_FUNKLOAD=${SKIP_FUNKLOAD:-}

# Cleaning
rm -rf ./tomcat ./results ./download
mkdir ./results ./download || exit 1

cd download
if [ -z $ZIP_FILE ]; then
    # extract list of links
    links=`lynx --dump $LASTBUILD_URL | grep -o "http:.*nuxeo\-dm\-.*tomcat\.zip\(.md5\)*" | sort -u`

    # Download and unpack the latest builds
    for link in $links; do
        wget -nv $link || exit 1
    done

    unzip -q nuxeo-dm*tomcat.zip
else
    unzip -q $ZIP_FILE || exit 1
fi
cd ..

# Tomcat tests --------------------------------------------------------

build=$(find ./download -maxdepth 1 -name 'nuxeo-*'  -type d)
mv $build ./tomcat || exit 1

# Update selenium tests
update_distribution_source
setup_tomcat_conf

# Use postgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_postgresql_database
fi

# No MySQL template available for Tomcat
#if [ ! -z $MYSQL_HOST ]; then
#    setup_mysql_database
#fi

# Use oracle
if [ ! -z $ORACLE_SID ]; then
    setup_oracle_database
fi

# Start tomcat
start_tomcat

# Run selenium tests first
# it requires an empty db
SELENIUM_PATH=${SELENIUM_PATH:-"$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/selenium}
HIDE_FF=true "$SELENIUM_PATH"/run.sh
ret1=$?

if [ -z $SKIP_FUNKLOAD ]; then
    (cd "$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/funkload; make EXT="--no-color")
    ret2=$?
else
    ret2=0
fi

# Stop tomcat
stop_tomcat

# Exit if some tests failed
[ $ret1 -eq 0 -a $ret2 -eq 0 ] || exit 9

# Upload successfully tested package on http://www.nuxeo.org/static/snapshots/
UPLOAD_URL=${UPLOAD_URL:-}
SRC_URL=${SRC_URL:-download}
if [ ! -z $UPLOAD_URL ]; then
    date
    scp -C $SRC_URL/*tomcat*.zip* $UPLOAD_URL || exit 1
    date
fi
