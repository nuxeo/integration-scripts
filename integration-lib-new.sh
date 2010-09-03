#!/bin/bash

HERE=$(cd $(dirname $0); pwd -P)
NXVERSION=${NXVERSION:-5.4}
NXDISTRIBUTION="$HERE/nuxeo-distribution-$NXVERSION"
JBOSS_HOME="$HERE/jboss"
DBPORT=${DBPORT:-5432}
TOMCAT_HOME="$HERE/tomcat"

check_ports_and_kill_ghost_process() {
    hostname=${1:-0.0.0.0}
    port=${2:-8080}
    RUNNING_PID=`lsof -i@$hostname:$port -sTCP:LISTEN -n -t`
    if [ ! -z $RUNNING_PID ]; then 
        echo [WARN] A process is already using port $port: $RUNNING_PID
        echo [WARN] Storing jstack in $PWD/$RUNNING_PID.jstack then killing process
        [ -e /usr/lib/jvm/java-6-sun/bin/jstack ] && /usr/lib/jvm/java-6-sun/bin/jstack $RUNNING_PID >$PWD/$RUNNING_PID.jstack
        kill $RUNNING_PID || kill -9 $RUNNING_PID
    fi
}

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

set_jboss_log4j_level() {
    LEVEL=$1
    shift
    sed -i "/<root>/,/root>/ s,<level value=.*\$,<level value=\"$LEVEL\"/>," "$JBOSS_HOME"/server/default/conf/jboss-log4j.xml
}


setup_jboss() {
    JBOSS=${1:-$JBOSS_HOME}
    if [ ! -d "$JBOSS" ] || [ ! -z $NEW_JBOSS ] ; then
        [ -d "$JBOSS" ] && rm -rf "$JBOSS"
        cp -r "$NXDISTRIBUTION"/nuxeo-distribution-jboss/target/*jboss "$JBOSS" || exit 1
        if [ ! -e "$JBOSS"/bin/nuxeo.conf ]; then
            cp "$HERE"/nuxeo.conf "$JBOSS"/bin/
        fi
        IP=${1:-0.0.0.0}
        MAIL_FROM=${MAIL_FROM:-`dirname $PWD|xargs basename`@$HOSTNAME}
        cat >> "$JBOSS"/bin/nuxeo.conf <<EOF || exit 1
nuxeo.bind.address=$IP
mail.smtp.host=merguez.in.nuxeo.com
mail.smtp.port=2500
mail.from=$MAIL_FROM
EOF
    else
        echo "Using previously installed JBoss. Set NEW_JBOSS variable to force new JBOSS deployment"
        rm -rf "$JBOSS"/server/default/data/* "$JBOSS"/log/*
    fi
    chmod u+x "$JBOSS"/bin/*.sh "$JBOSS"/bin/*ctl 2>/dev/null
    echo "org.nuxeo.systemlog.token=dolog" > "$JBOSS"/templates/common/config/selenium.properties
    set_jboss_log4j_level INFO
}

build_tomcat() {
    (cd "$NXDISTRIBUTION" && mvn clean install -Ptomcat) || exit 1
}

setup_tomcat() {
    TOMCAT=${1:-$TOMCAT_HOME}
    if [ ! -d "$TOMCAT" ] || [ ! -z $NEW_TOMCAT ] ; then
        [ -d "$TOMCAT" ] && rm -rf "$TOMCAT"
        unzip "$NXDISTRIBUTION"/nuxeo-distribution-tomcat/target/nuxeo-distribution-tomcat-*-nuxeo-dm.zip -d /tmp/ \
        && mv /tmp/nuxeo-dm-*-tomcat "$TOMCAT" || exit 1
    else
        echo "Using previously installed Tomcat. Set NEW_TOMCAT variable to force new TOMCAT deployment"
        rm -rf "$TOMCAT"/webapps/nuxeo/nxserver/data/* "$TOMCAT"/log/*
    fi
    chmod u+x "$TOMCAT"/bin/*.sh "$TOMCAT"/bin/*ctl 2>/dev/null
    echo "org.nuxeo.systemlog.token=dolog" > "$TOMCAT"/nxserver/config/selenium.properties
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
    check_ports_and_kill_ghost_process $IP
    echo "BINDHOST=$IP" > "$JBOSS"/bin/bind.conf
    "$JBOSS"/bin/nuxeoctl start || exit 1
}

stop_jboss() {
    JBOSS=${1:-$JBOSS_HOME}
    "$JBOSS"/bin/nuxeoctl stop
    gzip "$JBOSS"/log/*.log
    gzip -cd  "$JBOSS"/log/server.log.gz 2>/dev/null > "$JBOSS"/log/server.log
}

start_tomcat() {
    TOMCAT=${1:-$TOMCAT_HOME}
    check_ports_and_kill_ghost_process
    "$TOMCAT"/bin/nuxeoctl start || exit 1
}

stop_tomcat() {
    TOMCAT=${1:-$TOMCAT_HOME}
    "$TOMCAT"/bin/nuxeoctl stop
    gzip "$TOMCAT"/log/*.log
    gzip -cd  "$TOMCAT"/log/server.log.gz 2>/dev/null > "$TOMCAT"/log/server.log
}
