#!/bin/bash

HERE=$(cd $(dirname $0); pwd -P)
NXVERSION=${NXVERSION:-5.2}
NXDISTRIBUTION="$HERE/nuxeo-distribution-$NXVERSION"
JBOSS_HOME="$HERE/jboss"
DBPORT=${DBPORT:-5432}


update_distribution_source() {
    if [ ! -d "$NXDISTRIBUTION" ]; then
        hg clone -r $NXVERSION http://hg.nuxeo.org/nuxeo/nuxeo-distribution "$NXDISTRIBUTION" 2>/dev/null || exit 1
    else
        (cd "$NXDISTRIBUTION" && hg pull && hg up -C $NXVERSION) || exit 1
    fi
}

setup_jboss() {
    if [ ! -d "$JBOSS_HOME" ] || [ ! -z $NEW_JBOSS ] ; then
        [ -d "$JBOSS_HOME" ] && rm -rf "$JBOSS_HOME"
        (cd "$NXDISTRIBUTION" && mvn clean package -Pnuxeo-ep-jboss) || exit 1
        mv  "$NXDISTRIBUTION"/nuxeo-distribution-jboss/target/jboss "$JBOSS_HOME" || exit 1
        svn export --force https://svn.nuxeo.org/nuxeo/tools/jboss/bin "$JBOSS_HOME"/bin/ || exit 1
        cp "$HERE"/jbossctl.conf "$JBOSS_HOME"/bin/
    else
        echo "Using previously installed JBoss. Set NEW_JBOSS variable to force new JBOSS deployment"
        rm -rf "$JBOSS_HOME"/server/default/data/*
        rm -rf "$JBOSS_HOME"/server/default/log/*
    fi
}

deploy_ear() {
  deploySRCtoDST "$NXDISTRIBUTION"/nuxeo-platform-ear/target/nuxeo.ear "$JBOSS_HOME"/server/default/deploy/nuxeo.ear
}

deploySRCtoDST() {
  SRC=$1
  DST=$2
  [ -d "$DST" ] && rm -rf "$DST"
  mv $SRC $DST 
}

start_jboss() {
    echo "BINDHOST=0.0.0.0" > "$JBOSS_HOME"/bin/bind.conf
    "$JBOSS_HOME"/bin/jbossctl start || exit 1
}

stop_jboss() {
    "$JBOSS_HOME"/bin/jbossctl stop
    gzip "$JBOSS_HOME"/server/default/log/*.log
}

