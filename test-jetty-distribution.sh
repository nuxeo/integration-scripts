#!/bin/bash -x
HERE=$(cd $(dirname $0); pwd -P)

. $HERE/integration-lib.sh

LASTBUILD_URL=${LASTBUILD_URL:-http://qa.nuxeo.org/hudson/job/IT-nuxeo-5.4-build/lastSuccessfulBuild/artifact/trunk/release/archives}
ZIP_FILE=${ZIP_FILE:-}
SKIP_FUNKLOAD=${SKIP_FUNKLOAD:-}

# Cleaning
rm -rf ./jetty ./results ./download
mkdir ./results ./download || exit 1

cd download
if [ -z $ZIP_FILE ]; then
    # extract list of links
    links=`lynx --dump $LASTBUILD_URL | grep -o "http:.*nuxeo\-dm\-.*jetty\.zip\(.md5\)*" | sort -u`

    # Download and unpack the latest builds
    for link in $links; do
        wget -nv $link || exit 1
    done

    unzip -q nuxeo-dm*jetty.zip
else
    unzip -q $ZIP_FILE || exit 1
fi
cd ..

# Jetty tests --------------------------------------------------------

build=$(find ./download -maxdepth 1 -name 'nuxeo-*'  -type d)
mv $build ./jetty || exit 1


# Update selenium tests
update_distribution_source


# Start jetty
echo "org.nuxeo.systemlog.token=dolog" > jetty/config/selenium.properties
(cd jetty/bin; chmod +x *.sh *ctl 2>/dev/null;  ./nuxeoctl start) || exit 1

# Run selenium tests first
# it requires an empty db
SELENIUM_PATH=${SELENIUM_PATH:-"$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/selenium}
HIDE_FF=true SUITES=suite1 "$SELENIUM_PATH"/run.sh
ret1=$?

if [ -z $SKIP_FUNKLOAD ]; then
    java -version  2>&1 | grep 1.6.0
    if [ $? == 0 ]; then
        # FunkLoad tests works only with java 1.6.0 (j_ids are changed by java6)
        (cd "$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/funkload; make EXT="--no-color")
        ret2=$?
    else
        ret2=0
    fi
else
    ret2=0
fi

# Stop jetty
(cd jetty/bin; ./nuxeoctl stop)

# Exit if some tests failed
[ $ret1 -eq 0 -a $ret2 -eq 0 ] || exit 9

# Upload successfully tested package on http://www.nuxeo.org/static/snapshots/
UPLOAD_URL=${UPLOAD_URL:-}
SRC_URL=${SRC_URL:-download}
if [ ! -z $UPLOAD_URL ]; then
    date
    scp -C $SRC_URL/*jetty*.zip* $UPLOAD_URL || exit 1
    date
fi
