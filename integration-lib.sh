#!/bin/bash

HERE=$(cd $(dirname $0); pwd -P)
NXVERSION=${NXVERSION:-5.4}
NXDIR="$HERE/src-$NXVERSION"
NXDISTRIBUTION=${NXDISTRIBUTION:-"$NXDIR"/nuxeo-distribution}
JBOSS_HOME="$HERE/jboss"
TOMCAT_HOME="$HERE/tomcat"
if [ "$SERVER" = "tomcat" ]; then
    SERVER_HOME="$TOMCAT_HOME"
else
    SERVER_HOME="$JBOSS_HOME"
fi
DBPORT=${DBPORT:-5432}
if [ ! -z $PGPASSWORD ]; then
    DBNAME=${DBNAME:-qualiscope-ci-$(( RANDOM%10 ))}
fi
PGSQL_LOG=${PGSQL_LOG:-/var/log/pgsql}


check_ports_and_kill_ghost_process() {
    hostname=${1:-0.0.0.0}
    ports=${2:-8080 14440}
    for port in $ports; do
      RUNNING_PID=`lsof -n -i TCP@$hostname:$port | grep '(LISTEN)' | awk '{print $2}'`
      if [ ! -z $RUNNING_PID ]; then
          echo [WARN] A process is already using port $port: $RUNNING_PID
          echo [WARN] Storing jstack in $PWD/$RUNNING_PID.jstack then killing process
          [ -e /usr/lib/jvm/java-6-sun/bin/jstack ] && /usr/lib/jvm/java-6-sun/bin/jstack $RUNNING_PID >$PWD/$RUNNING_PID.jstack
          kill $RUNNING_PID || true
          sleep 5
          kill -9 $RUNNING_PID || true
      fi
    done
}

update_distribution_source() {
    if [ ! -d "$NXDIR" ]; then
        hg clone -r $NXVERSION http://hg.nuxeo.org/nuxeo/ $NXDIR 2>/dev/null || exit 1
    else
        (cd $NXDIR && hg pull && hg up -C $NXVERSION) || exit 1
    fi
    if [ ! -d $NXDIR/nuxeo-distribution ]; then
        hg clone -r $NXVERSION http://hg.nuxeo.org/nuxeo/nuxeo-distribution $NXDIR/nuxeo-distribution 2>/dev/null || exit 1
    else
        (cd $NXDIR/nuxeo-distribution && hg pull && hg up $NXVERSION) || exit 1
    fi
}

# DEPRECATED: deploy into an existing jboss
build_and_deploy() {
    echo "ERROR - deprecated method"
    exit 1
    (cd "$NXDIR" && ant patch -Djboss.dir="$JBOSS_HOME") || exit 1
    (cd "$NXDIR" && ant copy-lib package copy -Djboss.dir="$JBOSS_HOME") || exit 1
}

set_jboss_log4j_level() {
    LEVEL=$1
    shift
    sed -i "/<root>/,/root>/ s,<level value=.*\$,<level value=\"$LEVEL\"/>," "$JBOSS_HOME"/server/default/conf/jboss-log4j.xml
}


setup_monitoring() {
    IP=${1:-0.0.0.0}
    # Change log4j threshold from info to debug
    set_jboss_log4j_level INFO
    mkdir -p "$JBOSS_HOME"/log
    "$JBOSS_HOME"/bin/monitorctl.sh start
}

start_jboss() {
    if [ $# == 2 ]; then
        JBOSS="$1"
        shift
    else
        JBOSS="$JBOSS_HOME"
    fi
    IP=${1:-0.0.0.0}
    if [ ! -e "$JBOSS"/bin/nuxeo.conf ]; then
        cp "$HERE"/nuxeo.conf "$JBOSS"/bin/
    fi
    check_ports_and_kill_ghost_process $IP
    MAIL_FROM=${MAIL_FROM:-`dirname $PWD|xargs basename`@$HOSTNAME}
    cat >> "$JBOSS"/bin/nuxeo.conf <<EOF || exit 1
nuxeo.bind.address=$IP
mail.smtp.host=merguez.in.nuxeo.com
mail.smtp.port=2500
mail.from=$MAIL_FROM
JAVA_OPTS=-server -Xms1g -Xmx1g -XX:MaxPermSize=512m \
  -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000 \
  -Xloggc:\$DIRNAME/../log/gc.log  -verbose:gc -XX:+PrintGCDetails \
  -XX:+PrintGCTimeStamps
EOF
    setup_monitoring $IP
    echo "org.nuxeo.systemlog.token=dolog" > "$JBOSS"/templates/common/config/selenium.properties
    chmod u+x "$JBOSS"/bin/*.sh "$JBOSS"/bin/*ctl 2>/dev/null
    "$JBOSS"/bin/nuxeoctl start || exit 1
}

stop_jboss() {
    JBOSS=${1:-$JBOSS_HOME}
    "$JBOSS"/bin/monitorctl stop
    "$JBOSS"/bin/nuxeoctl stop
    if [ ! -z $PGPASSWORD ]; then
        vacuumdb -fzv $DBNAME -U qualiscope -h localhost -p $DBPORT &> "$JBOSS"/log/vacuum.log
    fi
    killall sar
    gzip "$JBOSS"/log/*.log
    gzip -cd  "$JBOSS"/log/server.log.gz > "$JBOSS"/log/server.log
}

setup_postgresql_database() {
    DBNAME=${1:-$DBNAME}
    echo "### Initializing PostgreSQL DATABASE: $DBNAME"
    dropdb $DBNAME -U qualiscope -h localhost -p $DBPORT
    if [ $? != 0 ]; then
        # try to remove pending transactions
        psql $DBNAME -U qualiscope -h localhost -p $DBPORT <<EOF
\t
\a
\o /tmp/hudson-remove-transactions.sql
SELECT 'ROLLBACK PREPARED ''' || gid || ''';'  AS cmd
  FROM pg_prepared_xacts
  WHERE database=current_database();
\o
\i /tmp/hudson-remove-transactions.sql
\q
EOF
        sleep 5
        dropdb $DBNAME -U qualiscope -h localhost -p $DBPORT
    fi
    createdb $DBNAME -U qualiscope -h localhost -p $DBPORT || exit 1
    createlang plpgsql $DBNAME -U qualiscope -h localhost -p $DBPORT

    cat >> "$SERVER_HOME"/bin/nuxeo.conf <<EOF || exit 1
nuxeo.templates=postgresql,monitor
nuxeo.db.port=$DBPORT
nuxeo.db.name=$DBNAME
nuxeo.db.user=qualiscope
nuxeo.db.password=$PGPASSWORD
nuxeo.db.max-pool-size=40
nuxeo.vcs.max-pool-size=40
PG_LOG=$PGSQL_LOG
EOF
}

setup_database() {
    # default db
    setup_postgresql_database
}

setup_oracle_database() {
    ORACLE_SID=${ORACLE_SID:-NUXEO}
    ORACLE_HOST=${ORACLE_HOST:-ORACLE_HOST}
    ORACLE_USER=${ORACLE_USER:-hudson}
    ORACLE_PASSWORD=${ORACLE_PASSWORD:-ORACLE_USER}
    ORACLE_PORT=${ORACLE_PORT:-1521}
    ORACLE_VERSION=${ORACLE_VERSION:-11}

    cat >> "$SERVER_HOME"/bin/nuxeo.conf <<EOF || exit 1
nuxeo.templates=oracle,monitor
nuxeo.db.host=$ORACLE_HOST
nuxeo.db.port=$ORACLE_PORT
nuxeo.db.name=$ORACLE_SID
nuxeo.db.user=$ORACLE_USER
nuxeo.db.password=$ORACLE_PASSWORD
EOF

    echo "### Initializing Oracle DATABASE: $ORACLE_SID $ORACLE_USER"
    ssh -o "ConnectTimeout 0" -l oracle $ORACLE_HOST sqlplus $ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_SID << EOF || exit 1
SET ECHO OFF NEWP 0 SPA 0 PAGES 0 FEED OFF HEAD OFF TRIMS ON TAB OFF
SET ESCAPE \\
SET SQLPROMPT ' '
SPOOL DELETEME.SQL
SELECT 'DROP TABLE  "' || table_name || '" CASCADE CONSTRAINTS \;' FROM user_tables WHERE table_name NOT LIKE '%$%';
SPOOL OFF
SET SQLPROMPT 'SQL: '
SET ECHO ON
@DELETEME.SQL
EOF

    # Available JDBC drivers from private Nexus
    [ "$ORACLE_VERSION" == "10" ] && \
        wget "http://mavenpriv.in.nuxeo.com/nexus/service/local/artifact/maven/redirect?r=releases&g=com.oracle&a=ojdbc14&v=10.2.0.5&e=jar" \
          -O "$JBOSS_HOME"/server/default/lib/ojdbc14-10.2.0.5.jar && \
        cp "$JBOSS_HOME"/server/default/lib/ojdbc14-10.2.0.5.jar "$TOMCAT_HOME"/lib/
    # http://mavenpriv.in.nuxeo.com/nexus/service/local/artifact/maven/redirect?r=releases&g=com.oracle&a=ojdbc14&v=10.2.0.5&e=jar
    # http://mavenpriv.in.nuxeo.com/nexus/service/local/artifact/maven/redirect?r=releases&g=com.oracle&a=ojdbc14&v=10.2.0.5&e=jar&c=g
    # http://mavenpriv.in.nuxeo.com/nexus/service/local/artifact/maven/redirect?r=releases&g=com.oracle&a=ojdbc6&v=11.2.0.2&e=jar
    # http://mavenpriv.in.nuxeo.com/nexus/service/local/artifact/maven/redirect?r=releases&g=com.oracle&a=ojdbc6&v=11.2.0.2&e=jar&c=g
    [ "$ORACLE_VERSION" == "11" ] && \
      wget "http://mavenpriv.in.nuxeo.com/nexus/service/local/artifact/maven/redirect?r=releases&g=com.oracle&a=ojdbc6&v=11.2.0.2&e=jar" \
        -O "$JBOSS_HOME"/server/default/lib/ojdbc6-11.2.0.2.jar && \
        cp "$JBOSS_HOME"/server/default/lib/ojdbc14-10.2.0.5.jar "$TOMCAT_HOME"/lib/
}

setup_mysql_database() {
    MYSQL_HOST=${MYSQL_HOST:-localhost}
    MYSQL_PORT=${MYSQL_PORT:-3306}
    MYSQL_DB=${MYSQL_DB:-qualiscope_ci}
    MYSQL_USER=${MYSQL_USER:-qualiscope}
    MYSQL_PASSWORD=${MYSQL_PASSWORD:-secret}
    MYSQL_JDBC_VERSION=${MYSQL_JDBC_VERSION:-5.1.6}
    MYSQL_JDBC=mysql-connector-java-$MYSQL_JDBC_VERSION.jar

    cat >> "$SERVER_HOME"/bin/nuxeo.conf <<EOF || exit 1
nuxeo.templates=mysql,monitor
nuxeo.db.host=$MYSQL_HOST
nuxeo.db.port=$MYSQL_PORT
nuxeo.db.name=$MYSQL_DB
nuxeo.db.user=$MYSQL_USER
nuxeo.db.password=$MYSQL_PASSWORD
EOF

    if [ ! -r "$JBOSS_HOME"/server/default/lib/mysql-connector-java-*.jar  ]; then
        wget "http://maven.nuxeo.org/nexus/service/local/artifact/maven/redirect?r=nuxeo-central&g=mysql&a=mysql-connector-java&v=$MYSQL_JDBC_VERSION&p=jar" \
          -O "$JBOSS_HOME"/server/default/lib/$MYSQL_JDBC || exit 1
    fi
    if [ ! -r "$TOMCAT_HOME"/lib/mysql-connector-java-*.jar  ]; then
        wget "http://maven.nuxeo.org/nexus/service/local/artifact/maven/redirect?r=nuxeo-central&g=mysql&a=mysql-connector-java&v=$MYSQL_JDBC_VERSION&p=jar" \
          -O "$TOMCAT_HOME"/lib/$MYSQL_JDBC || exit 1
    fi
    echo "### Initializing MySQL DATABASE: $MYSQL_DB"
    mysql -u $MYSQL_USER --password=$MYSQL_PASSWORD <<EOF || exit 1
DROP DATABASE $MYSQL_DB;
CREATE DATABASE $MYSQL_DB
CHARACTER SET utf8
COLLATE utf8_bin;

EOF
}

# DEPRECATED: included in nx-builder
package_sources() {
  NXP=$1
  NXC=$2
  wget -nv http://hg.nuxeo.org/nuxeo/archive/$NXP.zip -O nuxeo-$NXP.zip
  [ -d nuxeo-$NXP ] && rm -rf nuxeo-$NXP
  mkdir nuxeo-$NXP
  for mod in nuxeo-common nuxeo-runtime nuxeo-core; do
    wget -nv http://hg.nuxeo.org/nuxeo/$mod/archive/$NXC.zip -O nuxeo-$NXP/$mod.zip
    unzip nuxeo-$NXP/$mod.zip -d nuxeo-$NXP && rm nuxeo-$NXP/$mod.zip
    mv nuxeo-$NXP/$mod-$NXC nuxeo-$NXP/$mod
  done
  for mod in nuxeo-theme nuxeo-services nuxeo-jsf nuxeo-features nuxeo-dm nuxeo-webengine \
    nuxeo-gwt nuxeo-distribution; do
    wget -nv http://hg.nuxeo.org/nuxeo/$mod/archive/$NXP.zip -O nuxeo-$NXP/$mod.zip
    unzip nuxeo-$NXP/$mod.zip -d nuxeo-$NXP && rm nuxeo-$NXP/$mod.zip
    mv nuxeo-$NXP/$mod-$NXP nuxeo-$NXP/$mod
  done
  zip -r nuxeo-$NXP.zip nuxeo-$NXP/nuxeo-* && rm -rf nuxeo-$NXP
}

# Mercurial function that recurses all sub-directories containing a .hg directory and runs on them hg with given parameters
hgf() {
  for dir in . nuxeo-*; do
    if [ -d "$dir"/.hg ]; then
      echo "[$dir]"
      (cd "$dir" && hg "$@")
    fi
  done
}

hgx() {
  NXP=$1
  NXC=$2
  shift 2;
  if [ -d .hg ]; then
    echo $PWD
    hg $@ $NXP
    # NXC
    (echo nuxeo-common ; cd nuxeo-common; hg $@ $NXC || true)
    (echo nuxeo-runtime ; cd nuxeo-runtime; hg $@ $NXC || true)
    (echo nuxeo-core ; cd nuxeo-core; hg $@ $NXC || true)
    # NXP
    (echo nuxeo-theme ; cd nuxeo-theme; hg $@ $NXP || true)
    [ -d nuxeo-shell ] && (echo nuxeo-shell ; cd nuxeo-shell; hg $@ $NXP || true) || (echo ignore nuxeo-shell)
    [ -d nuxeo-platform ] && (echo nuxeo-platform ; cd nuxeo-platform && hg $@ $NXP || true) || (echo ignore nuxeo-platform)
    [ -d nuxeo-services ] && (echo nuxeo-services ; cd nuxeo-services && hg $@ $NXP || true) || (echo ignore nuxeo-services)
    [ -d nuxeo-jsf ] && (echo nuxeo-jsf ; cd nuxeo-jsf && hg $@ $NXP || true) || (echo ignore nuxeo-jsf)
    [ -d nuxeo-features ] && (echo nuxeo-features ; cd nuxeo-features && hg $@ $NXP || true) || (echo ignore nuxeo-features)
    [ -d nuxeo-dm ] && (echo nuxeo-dm ; cd nuxeo-dm && hg $@ $NXP || true) || (echo ignore nuxeo-dm)
    [ -d nuxeo-webengine ] && (echo nuxeo-webengine ; cd nuxeo-webengine; hg $@ $NXP || true) || (echo ignore nuxeo-webengine)
    [ -d nuxeo-gwt ] && (echo nuxeo-gwt ; cd nuxeo-gwt; hg $@ $NXP || true) || (echo ignore nuxeo-gwt)
    (echo nuxeo-distribution ; cd nuxeo-distribution; hg $@ $NXP || true)
  fi
}

