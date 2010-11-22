#!/bin/bash
###
# DB Setup
# this lib must be sourced from integration-lib.sh

setup_postgresql_database() {
    if [ -z $PGPASSWORD ]; then
	echo "Missing PGPASSWORD to init a PostgreSQL DB"
	return
    fi
    DBNAME=${DBNAME:-qualiscope-ci-$(( RANDOM%10 ))}
    DBPORT=${DBPORT:-5432}
    DBUSER=${DBUSER:-qualiscope}
    DBHOST=${DBHOST:-localhost}
    PGSQL_LOG=${PGSQL_LOG:-/var/log/pgsql}
    echo "### Initializing PostgreSQL DATABASE: $DBNAME"
    dropdb $DBNAME -U $DBUSER -h $DBHOST -p $DBPORT
    if [ $? != 0 ]; then
        # try to remove pending transactions
        psql $DBNAME -U $DBUSER -h $DBHOST -p $DBPORT <<EOF
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
        dropdb $DBNAME -U $DBUSER -h $DBHOST -p $DBPORT
    fi
    createdb $DBNAME -U $DBUSER -h $DBHOST -p $DBPORT || exit 1
    createlang plpgsql $DBNAME -U $DBUSER -h $DBHOST -p $DBPORT

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
          -O "$SERVER_LIB"/ojdbc14-10.2.0.5.jar
    # http://mavenpriv.in.nuxeo.com/nexus/service/local/artifact/maven/redirect?r=releases&g=com.oracle&a=ojdbc14&v=10.2.0.5&e=jar
    # http://mavenpriv.in.nuxeo.com/nexus/service/local/artifact/maven/redirect?r=releases&g=com.oracle&a=ojdbc14&v=10.2.0.5&e=jar&c=g
    # http://mavenpriv.in.nuxeo.com/nexus/service/local/artifact/maven/redirect?r=releases&g=com.oracle&a=ojdbc6&v=11.2.0.2&e=jar
    # http://mavenpriv.in.nuxeo.com/nexus/service/local/artifact/maven/redirect?r=releases&g=com.oracle&a=ojdbc6&v=11.2.0.2&e=jar&c=g
    [ "$ORACLE_VERSION" == "11" ] && \
      wget "http://mavenpriv.in.nuxeo.com/nexus/service/local/artifact/maven/redirect?r=releases&g=com.oracle&a=ojdbc6&v=11.2.0.2&e=jar" \
        -O "$SERVER_LIB"/ojdbc6-11.2.0.2.jar
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
        wget "http://maven.nuxeo.org/nexus/service/local/artifact/maven/redirect?r=thirdparty-releases&g=mysql&a=mysql-connector-java&v=$MYSQL_JDBC_VERSION&p=jar" \
          -O "$JBOSS_HOME"/server/default/lib/$MYSQL_JDBC || exit 1
    fi
    if [ ! -r "$TOMCAT_HOME"/lib/mysql-connector-java-*.jar  ]; then
        wget "http://maven.nuxeo.org/nexus/service/local/artifact/maven/redirect?r=thirdparty-releases&g=mysql&a=mysql-connector-java&v=$MYSQL_JDBC_VERSION&p=jar" \
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

setup_database() {
    # default db is pg
    setup_postgresql_database
}
