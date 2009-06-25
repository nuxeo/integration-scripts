#!/bin/bash -x

HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib-new.sh

# Cleaning
rm -rf ./jboss ./results ./download
mkdir ./results ./download || exit 1

# Build
update_distribution_source

setup_jboss"

cd "$NXDISTRIBUTION"
ant distrib -Ddistrib=nuxeo-dm -Dmvn.opts=-Djcr
deploySRCtoDST "$NXDISTRIBUTION"/nuxeo-distribution-dm/target/nuxeo-jcr.ear "$JBOSS_HOME"/server/default/deploy/nuxeo.ear
sed -i "s/<application-policy name = \"other\">/<application-policy name = \"other-notused-for-jcr\">/" $JBOSS_HOME/server/default/conf/login-config.xml

# Start Nuxeo
start_jboss 

# Run selenium tests
HIDE_FF=true URL=http://127.0.1.2:8080/nuxeo/ "$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/selenium/run.sh
#URL=http://127.0.1.2:8080/nuxeo/ "$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/selenium/run.sh
ret1=$?

# Stop Nuxeo
stop_jboss

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9

