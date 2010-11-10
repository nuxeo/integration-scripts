#!/bin/bash -x

HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

# Cleaning
rm -rf ./jboss ./results ./download
mkdir ./results ./download || exit 1

# Build
update_distribution_source
build_jboss
setup_jboss 127.0.0.1

cd "$NXDISTRIBUTION"
ant distrib -Ddistrib=nuxeo-dm -Dmvn.opts=-Djcr
deploySRCtoDST "$NXDISTRIBUTION"/nuxeo-distribution-dm/target/nuxeo-jcr.ear "$JBOSS_HOME"/server/default/deploy/nuxeo.ear
sed -i "s/<application-policy name = \"other\">/<application-policy name = \"other-notused-for-jcr\">/" $JBOSS_HOME/server/default/conf/login-config.xml

# Start Nuxeo
start_jboss 127.0.0.1

# Run selenium tests
SELENIUM_PATH=${SELENIUM_PATH:-"$NXDISTRIBUTION"/nuxeo-distribution-dm/ftest/selenium}
SUITES="suite1 suite2 suite-dm suite-webengine suite-webengine-website" HIDE_FF=true URL=http://127.0.0.1:8080/nuxeo/ "$SELENIUM_PATH"/run.sh
ret1=$?

# Stop Nuxeo
stop_jboss

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
