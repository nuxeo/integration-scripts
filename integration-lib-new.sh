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
    # should detect when it's necessary to rebuild JBoss (libraries or source code changed)
    (cd "$NXDISTRIBUTION" && mvn clean package -Pnuxeo-ep-jboss) || exit 1
}

setup_jboss() {
    JBOSS=${1:-$JBOSS_HOME}
    if [ ! -d "$JBOSS" ] || [ ! -z $NEW_JBOSS ] ; then
        [ -d "$JBOSS" ] && rm -rf "$JBOSS"
        cp -r "$NXDISTRIBUTION"/nuxeo-distribution-jboss/target/jboss "$JBOSS" || exit 1
        svn export --force https://svn.nuxeo.org/nuxeo/tools/jboss/bin "$JBOSS"/bin/ || exit 1
        cp "$HERE"/jbossctl.conf "$JBOSS"/bin/
    else
        echo "Using previously installed JBoss. Set NEW_JBOSS variable to force new JBOSS deployment"
        rm -rf "$JBOSS"/server/default/data/*
        rm -rf "$JBOSS"/server/default/log/*
    fi
}

deploy_ear() {
  deploySRCtoDST "$NXDISTRIBUTION"/nuxeo-platform-ear/target/nuxeo.ear "$JBOSS_HOME"/server/default/deploy/nuxeo.ear
}

deploySRCtoDST() {
  SRC=$1
  DST=$2
  [ -d "$DST" ] && rm -rf "$DST"
  cp -r $SRC $DST 
}

start_jboss() {
    JBOSS=${1:-$JBOSS_HOME}
    IP=${2:-0.0.0.0}
    echo "BINDHOST=$IP" > "$JBOSS"/bin/bind.conf
    "$JBOSS"/bin/jbossctl start || exit 1
}

stop_jboss() {
    JBOSS=${1:-$JBOSS_HOME}
    "$JBOSS"/bin/jbossctl stop
    gzip "$JBOSS"/server/default/log/*.log
}

