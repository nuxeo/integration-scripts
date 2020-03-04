#!/bin/bash

PRODUCT=${PRODUCT:-cap}
SERVER=${SERVER:-tomcat}
HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

LASTBUILD_URL=${LASTBUILD_URL:-http://qa.nuxeo.org/hudson/job/IT-nuxeo-master-build/lastSuccessfulBuild/artifact/trunk/release/archives}
ZIP_FILE=${ZIP_FILE:-}

# Cleaning
rm -rf ./jboss ./results ./download ./tomcat
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


# Use postgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_postgresql_database
fi

NXGSA="$HERE/nuxeo-gsa-connector"
if [ ! -d "$NXGSA" ]; then
    hg clone http://hg.nuxeo.org/addons/nuxeo-gsa-connector "$NXGSA" 2>/dev/null || exit 1
else
    (cd "$NXGSA" && hg pull && hg up -C) || exit 1
fi

if [ "$SERVER" = "tomcat" ]; then
    SERVER_BUNDLES=$TOMCAT_HOME/nxserver/bundles/
    SERVER_LIB=$TOMCAT_HOME/nxserver/lib/
    GSA_TPL=gsa_tomcat
elif [ "$SERVER" = "jboss" ]; then
    SERVER_BUNDLES=$JBOSS_HOME/server/default/deploy/nuxeo.ear/bundles/
    SERVER_LIB=$JBOSS_HOME/server/default/deploy/nuxeo.ear/lib/
    GSA_TPL=gsa_jboss
    # disable HDScanner
    rm -f $JBOSS_HOME/server/default/deploy/hdscanner-jboss-beans.xml
    # tmp fix/test for missing h2 jar on JBoss
    cp  "$JBOSS_HOME"/templates/default/lib/h2*.jar "$JBOSS_HOME"/server/default/lib/
fi

# Buid and deploy GSA connector
cd  "$NXGSA"
mvn clean package || exit 1
cp target/nuxeo-gsa-connector-*-SNAPSHOT.jar $SERVER_BUNDLES || exit 1

mvn -o clean dependency:copy-dependencies -DexcludeTransitive=true \
    -DincludeGroupIds=com.google,org.springframework,net.jmatrix || exit 1
cp target/dependency/*.jar $SERVER_LIB || exit 1


cd $HERE
cat >> "$NUXEO_CONF" <<EOF || exit 1
nuxeo.templates=postgresql,$NXGSA/templates/$GSA_TPL
nuxeo.url=http://localhost:8080/nuxeo
gsa.authorized.host=127.0.0.1
gsa.host=127.0.0.1
gsa.feed.port=19900
EOF

# Setup an ad hoc log4j configuration
if [ "$SERVER" = "tomcat" ]; then
    cp $HERE/gsa-tomcat-log4j.xml $TOMCAT_HOME/lib/log4j.xml
fi

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
