#!/bin/bash -x
HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

unzip nuxeo-distribution-jboss/target/nuxeo-distribution-jboss-5.4.0-SNAPSHOT-nuxeo-dm.zip -d jboss
ant copy -Djboss.dir=jboss/nuxeo-dm-5.4.0-SNAPSHOT-jboss/
start_jboss
sleep 3
stop_jboss
rm -rf jboss
