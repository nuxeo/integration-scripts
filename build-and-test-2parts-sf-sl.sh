#!/bin/bash -x

HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib-new.sh

JBOSS_HOME_SF="$JBOSS_HOME"-sf
JBOSS_HOME_SL="$JBOSS_HOME"-sl

# Cleaning
rm -rf ./jboss ./results ./download
mkdir ./results ./download || exit 1

# Build
update_distribution_source

setup_jboss
cp -r "$JBOSS_HOME" "$JBOSS_HOME_SF"
setup_jboss
cp -r "$JBOSS_HOME" "$JBOSS_HOME_SL"

(cd "$NXDISTRIBUTION"/nuxeo-platform-ear/ && ./package.sh nuxeo-2parts) || exit 1
deploySRCtoDST "$NXDISTRIBUTION"/nuxeo-platform-ear/target/nuxeo-platform-stateful.ear "$JBOSS_HOME_SF"/server/default/deploy/nuxeo.ear
deploySRCtoDST "$NXDISTRIBUTION"/nuxeo-platform-ear/target/nuxeo-web-stateless.ear "$JBOSS_HOME_SL"/server/default/deploy/nuxeo.ear

# Setup PostgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_database
fi

# Start
echo "BINDHOST=127.0.1.2" > "$JBOSS_HOME_SF"/bin/bind.conf
"$JBOSS_HOME_SF"/bin/jbossctl start || exit 1
echo "BINDHOST=127.0.0.1" > "$JBOSS_HOME_SL"/bin/bind.conf
"$JBOSS_HOME_SL"/bin/jbossctl start || exit 1

# Run selenium tests
HIDE_FF=true "$NXDISTRIBUTION"/nuxeo-platform-ear/ftest/selenium/run.sh
ret1=$?

# Stop nuxeo
"$JBOSS_HOME_SL"/bin/jbossctl stop
gzip "$JBOSS_HOME_SL"/server/default/log/*.log
"$JBOSS_HOME_SF"/bin/jbossctl stop
gzip "$JBOSS_HOME_SF"/server/default/log/*.log

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
