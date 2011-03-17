#!/bin/bash -x
HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

rm -rf jboss
unzip nuxeo-distribution-jboss/target/nuxeo-distribution-jboss-5.4.2-SNAPSHOT-nuxeo-dm.zip -d /tmp/
mv /tmp/nuxeo-dm-5.4.2-SNAPSHOT-jboss jboss
ant copy -Djboss.dir=jboss
start_server 127.0.0.1
sleep 5
stop_server
rm -rf jboss
