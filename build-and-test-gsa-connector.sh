#!/bin/bash -x

PRODUCT=${PRODUCT:-dm}
SERVER=${SERVER:-tomcat}
HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

LASTBUILD_URL=${LASTBUILD_URL:-http://qa.nuxeo.org/hudson/job/IT-nuxeo-5.4-build/lastSuccessfulBuild/artifact/trunk/release/archives}
ZIP_FILE=${ZIP_FILE:-}

# Cleaning
rm -rf ./jboss ./results ./download ./tomcat
mkdir ./results ./download || exit 1

cd download
if [ ! -z $ZIP_URL ]; then
    wget --no-clobber $ZIP_URL 
    ZIP_FILE=$ZIP_URL
fi
if [ -z $ZIP_FILE ]; then
    # extract list of links
    link=`lynx --dump $LASTBUILD_URL | grep -o "http:.*archives\/nuxeo\-.*.zip\(.md5\)*" | sort -u |grep $PRODUCT-[0-9]|grep $SERVER|grep -v md5|grep -v ear`
    wget -nv $link || exit 1
    ZIP_FILE=nuxeo-$PRODUCT*$SERVER.zip
fi
unzip -q $ZIP_FILE || exit 1
cd ..
build=$(find ./download -maxdepth 1 -name 'nuxeo-*' -name "*$PRODUCT*" -type d)
mv $build ./$SERVER || exit 1

# Update selenium tests
update_distribution_source
[ "$SERVER" = jboss ] && setup_jboss localhost
[ "$SERVER" = tomcat ] && setup_tomcat localhost

# Use postgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_postgresql_database
fi

NXGSA="$HERE/nuxeo-gsa-connector"
if [ ! -d "$NXGSA" ]; then
    hg clone http://hg.nuxeo.org/sandbox/nuxeo-gsa-connector "$NXGSA" 2>/dev/null || exit 1
else
    (cd "$NXGSA" && hg pull && hg up -C) || exit 1
fi

# Buid and deploy GSA connector on tomcat
cd  "$NXGSA"
mvn clean package || exit 1
cp target/nuxeo-gsa-connector-*-SNAPSHOT.jar $TOMCAT_HOME/nxserver/bundles/ || exit 1

mvn -o clean dependency:copy-dependencies -DexcludeTransitive=true \
    -DincludeGroupIds=com.google,org.springframework,net.jmatrix || exit 1
cp target/dependency/*.jar $TOMCAT_HOME/nxserver/lib/ || exit 1

cd $HERE
cat >> "$NUXEO_CONF" <<EOF || exit 1
nuxeo.templates=postgresql,$NXGSA/templates/gsa_tomcat
nuxeo.url=http://localhost:8080/nuxeo
gsa.host=127.0.0.1
gsa.feed.port=19900
EOF

# Setup an ad hoc log4j configuration
cp $HERE/gsa-tomcat-log4j.xml $TOMCAT_HOME/lib/log4j.xml

# Start Server
start_server localhost

if [ -z $SKIP_FUNKLOAD ]; then
    (cd "$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/funkload; make EXT="--no-color")
    ret1=$?
else
    ret1=0
fi

(cd "$NXGSA"/ftest/funkload; make EXT="--no-color -dv")
ret2=$?

# Stop nuxeo
stop_server

# Exit if some tests failed
[ $ret1 -eq 0 -a $ret2 -eq 0 ] || exit 9
