#!/bin/bash

HERE=$(cd $(dirname $0); pwd -P)
NXVERSION=${NXVERSION:-5.3}
NXDISTRIBUTION="$HERE/nuxeo-distribution-$NXVERSION"
JBOSS_HOME="$HERE/jboss"
DBPORT=${DBPORT:-5432}
TOMCAT_HOME="$HERE/tomcat"

update_distribution_source() {
    if [ ! -d "$NXDISTRIBUTION" ]; then
        hg clone -r $NXVERSION http://hg.nuxeo.org/nuxeo/nuxeo-distribution "$NXDISTRIBUTION" 2>/dev/null || exit 1
    else
        (cd "$NXDISTRIBUTION" && hg pull && hg up -C $NXVERSION) || exit 1
    fi
}

build_jboss() {
    # should detect when it's necessary to rebuild JBoss (libraries or source code changed)
    (cd "$NXDISTRIBUTION" && mvn clean install -Pnuxeo-dm,cmis,jboss,nuxeo-dm-jboss) || exit 1
}

build_jboss_ep() {
    # should detect when it's necessary to rebuild JBoss (libraries or source code changed)
    (cd "$NXDISTRIBUTION" && mvn clean install -Pnuxeo-ep,jboss) || exit 1
}

setup_jboss() {
    JBOSS=${1:-$JBOSS_HOME}
    if [ ! -d "$JBOSS" ] || [ ! -z $NEW_JBOSS ] ; then
        [ -d "$JBOSS" ] && rm -rf "$JBOSS"
        cp -r "$NXDISTRIBUTION"/nuxeo-distribution-jboss/target/*jboss "$JBOSS" || exit 1
        cp "$HERE"/jbossctl.conf "$JBOSS"/bin/
    else
        echo "Using previously installed JBoss. Set NEW_JBOSS variable to force new JBOSS deployment"
        rm -rf "$JBOSS"/server/default/data/*
        rm -rf "$JBOSS"/server/default/log/*
    fi
    chmod u+x "$JBOSS"/bin/*.sh "$JBOSS"/bin/jbossctl
}

build_tomcat() {
    (cd "$NXDISTRIBUTION" && mvn clean install -Ptomcat) || exit 1
}

setup_tomcat() {
    TOMCAT=${1:-$TOMCAT_HOME}
    if [ ! -d "$TOMCAT" ] || [ ! -z $NEW_TOMCAT ] ; then
        [ -d "$TOMCAT" ] && rm -rf "$TOMCAT"
        # cp -r "$NXDISTRIBUTION"/nuxeo-distribution-tomcat/target/stage/nuxeo-distribution-tomcat "$TOMCAT" || exit 1
        unzip "$NXDISTRIBUTION"/nuxeo-distribution-tomcat/target/nuxeo-distribution-tomcat-*nuxeo-dm-jtajca.zip -d /tmp/ \
        && mv /tmp/nuxeo-distribution-tomcat "$TOMCAT" || exit 1
    else
        echo "Using previously installed Tomcat. Set NEW_TOMCAT variable to force new TOMCAT deployment"
        rm -rf "$TOMCAT"/webapps/nuxeo/nxserver/data/*
        rm -rf "$TOMCAT"/logs/*
    fi
    chmod u+x "$TOMCAT"/bin/*.sh
}

deploy_ear() {
  if [ ! -d "$JBOSS"/server/default/deploy/nuxeo.ear ] || [ -z $NEW_JBOSS ] ; then
    deploySRCtoDST "$NXDISTRIBUTION"/nuxeo-distribution-jboss/target/nuxeo-dm-jboss/server/default/deploy/nuxeo.ear "$JBOSS_HOME"/server/default/deploy/nuxeo.ear
  else
    echo "Using EAR already present in JBoss assuming it's a fresh build."
  fi
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
    gzip -cd  "$JBOSS"/server/default/log/server.log.gz > "$JBOSS"/server/default/log/server.log
}

start_tomcat() {
    TOMCAT=${1:-$TOMCAT_HOME}
    "$TOMCAT"/bin/startup.sh || exit 1
}

stop_tomcat() {
    TOMCAT=${1:-$TOMCAT_HOME}
    "$TOMCAT"/bin/shutdown.sh
    gzip "$TOMCAT"/logs/*.log
    gzip -cd  "$TOMCAT"/logs/nxserver.log.gz > "$TOMCAT"/logs/nxserver.log
}
