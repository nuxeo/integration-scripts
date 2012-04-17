#!/bin/bash -x

CURRENT_DEV_VERSION="5.6-SNAPSHOT"

# JBoss location:
JBOSS_ZIP_FILE=${JBOSS_ZIP_FILE:-}
JBOSS_REPO_URL=${JBOSS_REPO_URL:-"http://maven.in.nuxeo.com/nexus/"}
JBOSS_GROUPID=${JBOSS_GROUPID:-"org.jboss"}
JBOSS_ARTIFACTID=${JBOSS_ARTIFACTID:-"jboss-as"}
JBOSS_VERSION=${JBOSS_VERSION:-"5.1.0.GA"}
JBOSS_CLASSIFIER=${JBOSS_CLASSIFIER:-"light"}
JBOSS_PACKAGING="zip"

# EAR location:
EAR_ZIP_FILE=${EAR_ZIP_FILE:-}
EAR_REPO_URL=${EAR_REPO_URL:-"http://maven.in.nuxeo.com/nexus/,http://maven.in.nuxeo.com/nexus/content/repositories/daily-snapshots/"}
EAR_GROUPID=${EAR_GROUPID:-"org.nuxeo.ecm.distribution"}
EAR_ARTIFACTID=${EAR_ARTIFACTID:-"nuxeo-distribution-jboss"}
EAR_VERSION=${EAR_VERSION:-$CURRENT_DEV_VERSION}
EAR_CLASSIFIER=${EAR_CLASSIFIER:-"nuxeo-cap-ear"}
EAR_PACKAGING="zip"

# Try to guess NXVERSION and NXTAG from EAR_VERSION
# This is tricky, so it's better to set them explicitly
if [ -z "$NXVERSION" ]; then
    if [ "$EAR_VERSION" = "$CURRENT_DEV_VERSION" ]; then
        NXVERSION="master"
    else
        NXVERSION=${EAR_VERSION//-SNAPSHOT/}
        if [[ "$NXVERSION" =~ -HF[0-9][0-9] ]]; then
            if [ -z "$NXTAG" ]; then
                NXTAG="release-$NXVERSION"
            fi
            NXVERSION=${NXVERSION//-HF[0-9][0-9]/}
        fi
    fi
fi

# Display versions in the logs
echo "********************************************************************"
echo "* JBoss version: $JBOSS_ARTIFACTID $JBOSS_VERSION"
echo "* EAR version: $EAR_CLASSIFIER $EAR_VERSION"
if [ -z "$NXTAG" ]; then
    echo "* Test scripts branch: $NXVERSION"
else
    echo "* Test scripts branch: $NXVERSION (tag ${NXTAG})"
fi
echo "********************************************************************"

# Misc
SERVER="jboss"
HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

# Comment out to enable monitoring
SKIP_MONITORING=true

# Cleaning
rm -rf "${SERVER_HOME}" download
mkdir download || exit 1

pushd download

# Download and extract base JBoss

if [ -z "${JBOSS_ZIP_FILE}" ]; then
    mvn org.apache.maven.plugins:maven-dependency-plugin:2.4:get -DremoteRepositories=${JBOSS_REPO_URL} -DgroupId=${JBOSS_GROUPID} -DartifactId=${JBOSS_ARTIFACTID} -Dversion=${JBOSS_VERSION} -Dpackaging=${JBOSS_PACKAGING} -Dclassifier=${JBOSS_CLASSIFIER} -Dtransitive=false -Ddest=jboss.zip
    unzip -q jboss.zip
    rm jboss.zip
else
    unzip -q "${JBOSS_ZIP_FILE}"
fi
build=$(find . -mindepth 1 -maxdepth 1 -type d)
mv $build "${SERVER_HOME}" || exit 1

# Overlay Nuxeo's EAR+
if [ -z "${EAR_ZIP_FILE}" ]; then
    mvn org.apache.maven.plugins:maven-dependency-plugin:2.4:get -DremoteRepositories=${EAR_REPO_URL} -DgroupId=${EAR_GROUPID} -DartifactId=${EAR_ARTIFACTID} -Dversion=${EAR_VERSION} -Dpackaging=${EAR_PACKAGING} -Dclassifier=${EAR_CLASSIFIER} -Dtransitive=false -Ddest=ear.zip
    unzip -q ear.zip
    rm ear.zip
else
    unzip -q "${EAR_ZIP_FILE}"
fi

# enable remote debug
patch -p0 <<EOF
*** bin/nuxeo.conf~	2012-04-17 10:34:14.055004000 +0200
--- bin/nuxeo.conf	2012-04-17 10:34:48.023004001 +0200
***************
*** 113,119 ****
  
  # DEBUGGING ----------------------------------------------
  # Sample JPDA settings for remote socket debugging
! #JAVA_OPTS=\$JAVA_OPTS -Xdebug -Xrunjdwp:transport=dt_socket,address=8787,server=y,suspend=n
  
  # Sample JPDA settings for shared memory debugging
  #JAVA_OPTS=\$JAVA_OPTS -Xdebug -Xnoagent -Djava.compiler=NONE -Xrunjdwp:transport=dt_shmem,server=y,suspend=n,address=jboss
--- 113,119 ----
  
  # DEBUGGING ----------------------------------------------
  # Sample JPDA settings for remote socket debugging
! JAVA_OPTS=\$JAVA_OPTS -Xdebug -Xrunjdwp:transport=dt_socket,address=8799,server=y,suspend=n
  
  # Sample JPDA settings for shared memory debugging
  #JAVA_OPTS=\$JAVA_OPTS -Xdebug -Xnoagent -Djava.compiler=NONE -Xrunjdwp:transport=dt_shmem,server=y,suspend=n,address=jboss
EOF
# fix1
find . -type f -name 'hibernate-core.jar' -exec rm {} \;

rsync -Wax */* "${SERVER_HOME}/"

popd

# fix2
mv "${SERVER_HOME}"/server/default/deploy/nuxeo.ear/lib/jboss-seam-[0-9]*.jar "${SERVER_HOME}"/server/default/deploy/nuxeo.ear/bundles/

# fix3
patch -p0 --reverse < "$HERE"/resources/ear-template-patch.diff

# fix4
if [ -f "$HERE"/resources/nuxeo-opensocial-container-5.4.2-HF20-patch.jar ]; then
    rm -f "${SERVER_HOME}"/server/default/deploy/nuxeo.ear/bundles/nuxeo-opensocial-container-*.jar
    cp "$HERE"/resources/nuxeo-opensocial-container-5.4.2-HF20-patch.jar "${SERVER_HOME}"/server/default/deploy/nuxeo.ear/bundles/
fi

# Update selenium tests
NXSRC="$HERE/nuxeo-src/nuxeo-distribution"
if [ ! -d "$NXSRC" ]; then
    mkdir -p `dirname "$NXSRC"`
    git clone https://github.com/nuxeo/nuxeo-distribution.git "$NXSRC" || exit 1
fi
(cd "$NXSRC" && git checkout master && git fetch --tags && git pull --all&& git checkout $NXVERSION) || exit 1
if [ ! -z $NXTAG ]; then
    (cd "$NXSRC" && git checkout $NXTAG) || exit 1
fi

# Update parent pom (master branch) for DB init
NXMASTER="$HERE/nuxeo-src/nuxeo"
if [ ! -d "$NXMASTER" ]; then
    mkdir -p `dirname "$NXMASTER"`
    git clone https://github.com/nuxeo/nuxeo.git "$NXMASTER" || exit 1
fi
(cd "$NXMASTER" && git pull) || exit 1

# Setup DB
USEDB=${USEDB:-default}
if [ "$USEDB" = "postgresql" ]; then
    mvn -f "$NXMASTER/pom.xml" initialize -Pcustomdb,pgsql -N
    DBHOST=${NX_DB_HOST:-$NX_PGSQL_DB_HOST}
    DBPORT=${NX_DB_PORT:-$NX_PGSQL_DB_PORT}
    DBNAME=${NX_DB_NAME:-$NX_PGSQL_DB_NAME}
    DBUSER=${NX_DB_USER:-$NX_PGSQL_DB_USER}
    DBPASS=${NX_DB_PASS:-$NX_PGSQL_DB_PASS}
    NUXEO_CONF="$SERVER_HOME/bin/nuxeo.conf"
    activate_db_template postgresql
    set_key_value nuxeo.db.host $DBHOST
    set_key_value nuxeo.db.port $DBPORT
    set_key_value nuxeo.db.name $DBNAME
    set_key_value nuxeo.db.user $DBUSER
    set_key_value nuxeo.db.password $DBPASS
elif [ "$USEDB" = "oracle" ]; then
    mvn -f "$NXMASTER/pom.xml" initialize -Pcustomdb,oracle11g -N
    DBHOST=${NX_DB_HOST:-$NX_ORACLE11G_DB_HOST}
    DBPORT=${NX_DB_PORT:-$NX_ORACLE11G_DB_PORT}
    DBNAME=${NX_DB_NAME:-$NX_ORACLE11G_DB_NAME}
    DBUSER=${NX_DB_USER:-$NX_ORACLE11G_DB_USER}
    DBPASS=${NX_DB_PASS:-$NX_ORACLE11G_DB_PASS}
    NUXEO_CONF="$SERVER_HOME/bin/nuxeo.conf"
    activate_db_template oracle
    set_key_value nuxeo.db.host $DBHOST
    set_key_value nuxeo.db.port $DBPORT
    set_key_value nuxeo.db.name $DBNAME
    set_key_value nuxeo.db.user $DBUSER
    set_key_value nuxeo.db.password $DBPASS
    set_key_value launcher.start.max.wait 1200
    mvn org.apache.maven.plugins:maven-dependency-plugin:2.4:get -DremoteRepositories=${EAR_REPO_URL} -DgroupId=com.oracle -DartifactId=ojdbc6 -Dversion=11.2.0.2 -Dpackaging=jar -Dtransitive=false -Ddest="$SERVER_HOME/common/lib/ojdbc6-11.2.0.2.jar"
fi


# Setup and start JBoss
setup_jboss "$SERVER_HOME" 127.0.0.1
start_server "$SERVER_HOME" 127.0.0.1

# Test --------------------------------------------------
# Run selenium tests
SELENIUM_PATH=${SELENIUM_PATH:-"$NXSRC"/nuxeo-distribution-dm/ftest/selenium}
pushd $SELENIUM_PATH
rm -f result-*.html
rm -rf target
if [ -f "run.sh" ]; then
    ./run.sh
    # Move results to target/results for Jenkins
    mkdir -p target/results
    mv result-*.html target/results/
else
    mvn org.nuxeo.build:nuxeo-distribution-tools:integration-test -Dtarget=run-selenium -Dsuites=suite1,suite2,suite-dm,suite-webengine,suite-webengine-website,suite-webengine-tags -DnuxeoURL=http://127.0.0.1:8080/nuxeo/
fi
ret1=$?
popd

stop_server "$SERVER_HOME"

exit $ret1
