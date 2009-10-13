#!/bin/bash
# TODO: replace DEPRECATED JBOSS_ARCHIVE: JBoss must be retrieved from Maven

HERE=$(cd $(dirname $0); pwd -P)
NXVERSION=${NXVERSION:-5.3}
NXDIR="$HERE/src-$NXVERSION"
JBOSS_ARCHIVE=${JBOSS_ARCHIVE:-~/jboss-4.2.3.GA.zip}
JBOSS_HOME="$HERE/jboss"
DBPORT=${DBPORT:-5432}
if [ ! -z $PGPASSWORD ]; then
    DBNAME=${DBNAME:-qualiscope-ci-$(( RANDOM%10 ))}
fi
PGSQL_LOG=${PGSQL_LOG:-/var/log/pgsql}
PGSQL_OFFSET="$JBOSS_HOME"/server/default/log/pgsql.offset
LOGTAIL=/usr/sbin/logtail

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

setup_jboss() {
    if [ ! -d "$JBOSS_HOME" ] || [ ! -z $NEW_JBOSS ] ; then
        [ -d "$JBOSS_HOME" ] && rm -rf "$JBOSS_HOME"
        unzip -q "$JBOSS_ARCHIVE" -d jboss.tmp || exit 1
        mv  jboss.tmp/* "$JBOSS_HOME" || exit 1
        rm -rf jboss.tmp
        svn export --force https://svn.nuxeo.org/nuxeo/tools/jboss/bin "$JBOSS_HOME"/bin/ || exit 1
        cp "$HERE"/jbossctl.conf "$JBOSS_HOME"/bin/
    else
        echo "Using previously installed JBOSS. Set NEW_JBOSS variable to force new JBOSS deployment"
        rm -rf "$JBOSS_HOME"/server/default/data/*
        rm -rf "$JBOSS_HOME"/server/default/log/*
    fi
}


setup_monitoring() {
    IP=${1:-0.0.0.0}
    # Change log4j threshold from info to debug
    sed -i '/server.log/,/<\/appender>/ s,name="Threshold" value="INFO",name="Threshold" value="DEBUG",' "$JBOSS_HOME"/server/default/conf/jboss-log4j.xml
    mkdir -p "$JBOSS_HOME"/server/default/log
    # postgres
    if [ ! -z $PGPASSWORD ]; then
        if [ -r $PGSQL_LOG ]; then
            rm -rf $PGSQL_OFFSET
            $LOGTAIL -f $PGSQL_LOG -o $PGSQL_OFFSET > /dev/null
        fi
    fi
    # Let sysstat sar record activity every 5s during 60min
    sar -d -o  "$JBOSS_HOME"/server/default/log/sysstat-sar.log 5 720 >/dev/null 2>&1 &
    # Activate logging monitor
    cp "$JBOSS_HOME"/docs/examples/jmx/logging-monitor/lib/logging-monitor.jar "$JBOSS_HOME"/server/default/lib/
    # Add mbean attributes to monitor
    cat >  "$JBOSS_HOME"/server/default/deploy/webthreads-monitor-service.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE server PUBLIC "-//JBoss//DTD MBean Service 4.0//EN" "http://www.jboss.org/j2ee/dtd/jboss-service_4_0.dtd">
<server>
  <mbean code="org.jboss.services.loggingmonitor.LoggingMonitor"
         name="jboss.monitor:type=LoggingMonitor,name=WebThreadMonitor">
    <attribute name="Filename">\${jboss.server.log.dir}/webthreads.log</attribute>
    <attribute name="AppendToFile">false</attribute>
    <attribute name="RolloverPeriod">DAY</attribute>
    <attribute name="MonitorPeriod">5000</attribute>
    <attribute name="MonitoredObjects">
      <configuration>
        <monitoredmbean name="jboss.web:name=http-$IP-8080,type=ThreadPool" logger="jboss.thread">
          <attribute>currentThreadCount</attribute>
          <attribute>currentThreadsBusy</attribute>
          <attribute>maxThreads</attribute>
        </monitoredmbean>
      </configuration>
    </attribute>
    <depends>jboss.web:service=WebServer</depends>
  </mbean>
</server>
EOF

    cat >  "$JBOSS_HOME"/server/default/deploy/jvm-monitor-service.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE server PUBLIC "-//JBoss//DTD MBean Service 4.0//EN" "http://www.jboss.org/j2ee/dtd/jboss-service_4_0.dtd">
<server>
  <mbean code="org.jboss.services.loggingmonitor.LoggingMonitor"
         name="jboss.monitor:type=LoggingMonitor,name=JVMMonitor">
    <attribute name="Filename">\${jboss.server.log.dir}/jvm.log</attribute>
    <attribute name="AppendToFile">false</attribute>
    <attribute name="RolloverPeriod">DAY</attribute>
    <attribute name="MonitorPeriod">5000</attribute>
    <attribute name="MonitoredObjects">
      <configuration>
        <monitoredmbean name="jboss.system:type=ServerInfo" logger="jvm">
          <attribute>ActiveThreadCount</attribute>
          <attribute>FreeMemory</attribute>
          <attribute>TotalMemory</attribute>
          <attribute>MaxMemory</attribute>
        </monitoredmbean>
      </configuration>
    </attribute>
  </mbean>
</server>
EOF

    cat >  "$JBOSS_HOME"/server/default/deploy/default-ds-monitor-service.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE server PUBLIC "-//JBoss//DTD MBean Service 4.0//EN" "http://www.jboss.org/j2ee/dtd/jboss-service_4_0.dtd">
<server>
  <mbean code="org.jboss.services.loggingmonitor.LoggingMonitor"
         name="jboss.monitor:type=LoggingMonitor,name=NuxeoDSMonitor">
    <attribute name="Filename">\${jboss.server.log.dir}/nuxeo-ds.log</attribute>
    <attribute name="AppendToFile">false</attribute>
    <attribute name="RolloverPeriod">DAY</attribute>
    <attribute name="MonitorPeriod">5000</attribute>
    <attribute name="MonitoredObjects">
      <configuration>
        <monitoredmbean name="jboss.jca:name=NuxeoDS,service=ManagedConnectionPool" logger="jca">
          <attribute>InUseConnectionCount</attribute>
          <attribute>AvailableConnectionCount</attribute>
          <attribute>ConnectionCreatedCount</attribute>
          <attribute>ConnectionDestroyedCount</attribute>
          <attribute>MaxConnectionsInUseCount</attribute>
        </monitoredmbean>
      </configuration>
    </attribute>
    <depends>jboss.jca:name=DefaultDS,service=ManagedConnectionPool</depends>
  </mbean>
</server>
EOF

}


build_and_deploy() {
    (cd "$NXDIR" && ant patch -Djboss.dir="$JBOSS_HOME") || exit 1
    (cd "$NXDIR" && ant copy-lib package copy -Djboss.dir="$JBOSS_HOME") || exit 1
}


start_jboss() {
    if [ ! -e "$JBOSS_HOME"/bin/jbossctl.conf ]; then
        cp "$HERE"/jbossctl.conf "$JBOSS_HOME"/bin/
    fi
    IP=${1:-0.0.0.0}
    echo "BINDHOST=$IP" > "$JBOSS_HOME"/bin/bind.conf
    setup_monitoring $IP
    "$JBOSS_HOME"/bin/jbossctl start || exit 1
}

stop_jboss() {
    "$JBOSS_HOME"/bin/jbossctl stop
    [ -r "$JBOSS_HOME"/log/gc.log ] && mv "$JBOSS_HOME"/log/gc.log "$JBOSS_HOME"/server/default/log/
    if [ -r $PGSQL_OFFSET ]; then
        $LOGTAIL -f $PGSQL_LOG -o $PGSQL_OFFSET > "$JBOSS_HOME"/server/default/log/pgsql.log
    fi
    if [ ! -z $PGPASSWORD ]; then
        vacuumdb -fzv $DBNAME -U qualiscope -h localhost -p $DBPORT &> "$JBOSS_HOME"/server/default/log/vacuum.log
    fi
    gzip "$JBOSS_HOME"/server/default/log/*.log
}


setup_postgresql_database() {
    DBNAME=${1:-$DBNAME}
    echo "### Initializing PostgreSQL DATABASE: $DBNAME"
    dropdb $DBNAME -U qualiscope -h localhost -p $DBPORT
    createdb $DBNAME -U qualiscope -h localhost -p $DBPORT || exit 1
    createlang plpgsql $DBNAME -U qualiscope -h localhost -p $DBPORT

    NXC_VERSION=$(cd "$JBOSS_HOME"; ls server/default/deploy/nuxeo.ear/system/nuxeo-core-storage-sql-ra-*.rar |cut -d"-" -f6- )

    [ -z $NXC_VERSION ] && exit 1

    # switch nxtags to unified ds
    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/datasources/nxtags-ds.xml <<EOF || exit 1
<?xml version="1.0"?>
<datasources>
  <mbean code="org.jboss.naming.NamingAlias"
    name="jboss.jca:name=nxtags,service=DataSourceBinding">
    <attribute name="ToName">java:/NuxeoDS</attribute>
    <attribute name="FromName">java:/nxtags</attribute>
  </mbean>
</datasources>
EOF

    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/datasources/default-repository-ds.xml <<EOF || exit 1
<?xml version="1.0"?>
<connection-factories>
  <tx-connection-factory>
    <jndi-name>NXRepository/default</jndi-name>
    <xa-transaction/>
    <track-connection-by-tx/>
    <adapter-display-name>Nuxeo SQL Repository DataSource</adapter-display-name>
    <rar-name>nuxeo.ear#nuxeo-core-storage-sql-ra-$NXC_VERSION</rar-name>
    <connection-definition>org.nuxeo.ecm.core.storage.sql.Repository</connection-definition>
    <config-property name="name">default</config-property>
    <config-property name="xaDataSource" type="java.lang.String">org.postgresql.xa.PGXADataSource</config-property>
    <config-property name="property" type="java.lang.String">ServerName=localhost</config-property>
    <config-property name="property" type="java.lang.String">PortNumber/Integer=$DBPORT</config-property>
    <config-property name="property" type="java.lang.String">DatabaseName=$DBNAME</config-property>
    <config-property name="property" type="java.lang.String">User=qualiscope</config-property>
    <config-property name="property" type="java.lang.String">Password=$PGPASSWORD</config-property>
  </tx-connection-factory>
</connection-factories>

EOF

    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/datasources/unified-nuxeo-ds.xml <<EOF || exit 1
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
   <xa-datasource>
     <jndi-name>NuxeoDS</jndi-name>
     <track-connection-by-tx/>
     <xa-datasource-class>org.postgresql.xa.PGXADataSource</xa-datasource-class>
     <xa-datasource-property name="ServerName">localhost</xa-datasource-property>
     <xa-datasource-property name="PortNumber">$DBPORT</xa-datasource-property>
     <xa-datasource-property name="DatabaseName">$DBNAME</xa-datasource-property>
     <xa-datasource-property name="User">qualiscope</xa-datasource-property>
     <xa-datasource-property name="Password">$PGPASSWORD</xa-datasource-property>
   </xa-datasource>
</datasources>
EOF

    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/config/default-repository-config.xml <<EOF || exit 1
<?xml version="1.0"?>
<component name="default-repository-config">
  <extension target="org.nuxeo.ecm.core.repository.RepositoryService"
    point="repository">
    <repository name="default"
      factory="org.nuxeo.ecm.core.storage.sql.coremodel.SQLRepositoryFactory">
      <repository name="default">
        <schema>
          <field type="largetext">note</field>
        </schema>
        <indexing>
          <fulltext analyzer="english"/>
        </indexing>
      </repository>
    </repository>
  </extension>
</component>
EOF

    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/config/sql.properties <<EOF || exit 1
# Jena database type and transaction mode
org.nuxeo.ecm.sql.jena.databaseType=PostgreSQL
org.nuxeo.ecm.sql.jena.databaseTransactionEnabled=false
EOF

    cp -u ~/.m2/repository/postgresql/postgresql/8.3-*.jdbc3/postgresql-8.3-*.jdbc3.jar "$JBOSS_HOME"/server/default/lib/

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

    echo "### Initializing Oracle DATABASE: $ORACLE_SID $ORACLE_USER"

    ssh -l oracle $ORACLE_HOST sqlplus $ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_SID << EOF || exit 1
SET ECHO OFF NEWP 0 SPA 0 PAGES 0 FEED OFF HEAD OFF TRIMS ON TAB OFF
SET ESCAPE \\
SET SQLPROMPT ' '
SPOOL DELETEME.SQL
SELECT 'DROP TABLE  "'|| table_name|| '" CASCADE CONSTRAINTS \;' FROM user_tables;
SPOOL OFF
SET SQLPROMPT 'SQL: '
SET ECHO ON
@DELETEME.SQL
EOF

    # TODO: use private nexus to get jdbc driver
    scp oracle@$ORACLE_HOST:/opt/oracle/10g/jdbc/lib/ojdbc14.jar  "$JBOSS_HOME"/server/default/lib/ || exit 1

    NXC_VERSION=$(cd "$JBOSS_HOME"; ls server/default/deploy/nuxeo.ear/system/nuxeo-core-storage-sql-ra-*.rar |cut -d"-" -f6- )

    [ -z $NXC_VERSION ] && exit 1

    # switch nxtags to unified ds
    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/datasources/nxtags-ds.xml <<EOF || exit 1
<?xml version="1.0"?>
<datasources>
  <mbean code="org.jboss.naming.NamingAlias"
    name="jboss.jca:name=nxtags,service=DataSourceBinding">
    <attribute name="ToName">java:/NuxeoDS</attribute>
    <attribute name="FromName">java:/nxtags</attribute>
  </mbean>
</datasources>
EOF

    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/datasources/default-repository-ds.xml <<EOF || exit 1
<?xml version="1.0"?>
<connection-factories>
  <tx-connection-factory>
    <jndi-name>NXRepository/default</jndi-name>
    <xa-transaction/>
    <track-connection-by-tx/>
    <adapter-display-name>Nuxeo SQL Repository DataSource</adapter-display-name>
    <rar-name>nuxeo.ear#nuxeo-core-storage-sql-ra-$NXC_VERSION</rar-name>
    <connection-definition>org.nuxeo.ecm.core.storage.sql.Repository</connection-definition>
    <config-property name="name">default</config-property>
    <config-property name="xaDataSource" type="java.lang.String">oracle.jdbc.xa.client.OracleXADataSource</config-property>
    <config-property name="property" type="java.lang.String">URL=jdbc:oracle:thin:@$ORACLE_HOST:$ORACLE_PORT:$ORACLE_SID</config-property>
    <config-property name="property" type="java.lang.String">User=$ORACLE_USER</config-property>
    <config-property name="property" type="java.lang.String">Password=$ORACLE_PASSWORD</config-property>
    <max-pool-size>20</max-pool-size>
  </tx-connection-factory>
</connection-factories>

EOF

    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/datasources/unified-nuxeo-ds.xml <<EOF || exit 1
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
   <local-tx-datasource>
     <jndi-name>NuxeoDS</jndi-name>
     <driver-class>oracle.jdbc.driver.OracleDriver</driver-class>
     <connection-url>jdbc:oracle:thin:@$ORACLE_HOST:$ORACLE_PORT:$ORACLE_SID</connection-url>
     <user-name>$ORACLE_USER</user-name>
     <password>$ORACLE_PASSWORD</password>
     <min-pool-size>5</min-pool-size>
     <max-pool-size>20</max-pool-size>
  </local-tx-datasource>
</datasources>
EOF

    # xa does not work at ddl time for oracle
    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/datasources/unified-nuxeo-ds.xml-xa <<EOF || exit 1
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
   <xa-datasource>
     <jndi-name>NuxeoDS</jndi-name>
     <track-connection-by-tx/>
     <no-tx-separate-pools/> 
     <isSameRM-override-value>false</isSameRM-override-value>
     <xa-datasource-class>oracle.jdbc.xa.client.OracleXADataSource</xa-datasource-class>
     <xa-datasource-property name="URL">jdbc:oracle:thin:@$ORACLE_HOST:$ORACLE_PORT:$ORACLE_SID</xa-datasource-property>
     <xa-datasource-property name="User">$ORACLE_USER</xa-datasource-property>
     <xa-datasource-property name="Password">$ORACLE_PASSWORD</xa-datasource-property>
   </xa-datasource>
</datasources>
EOF

    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/config/default-repository-config.xml <<EOF || exit 1
<?xml version="1.0"?>
<component name="default-repository-config">
  <extension target="org.nuxeo.ecm.core.repository.RepositoryService"
    point="repository">
    <repository name="default"
      factory="org.nuxeo.ecm.core.storage.sql.coremodel.SQLRepositoryFactory">
      <repository name="default">
      <schema>
         <field type="largetext">note</field>
       </schema>
       <indexing>
         <!-- for Oracle (Oracle Text indexing parmeters): 
              http://download.oracle.com/docs/cd/B19306_01/text.102/b14218/cdatadic.htm
         <fulltext analyzer="LEXER MY_LEXER"/>-->
       </indexing>
      </repository>
    </repository>
  </extension>
</component>
EOF


    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/config/sql.properties <<EOF || exit 1
# Jena database type and transaction mode
org.nuxeo.ecm.sql.jena.databaseType=Oracle
org.nuxeo.ecm.sql.jena.databaseTransactionEnabled=false
EOF


}


setup_mysql_database() {
    MYSQL_HOST=${MYSQL_HOST:-localhost}
    MYSQL_PORT=${MYSQL_PORT:-3306}
    MYSQL_DB=${MYSQL_DB:-qualiscope_ci}
    MYSQL_USER=${MYSQL_USER:-qualiscope}
    MYSQL_PASSWORD=${MYSQL_PASSWORD:-secret}
    MYSQL_JDBC_VERSION=${MYSQL_JDBC_VERSION:-5.1.6}
    MYSQL_JDBC=mysql-connector-java-$MYSQL_JDBC_VERSION.jar

    if [ ! -r $MYSQL_JDBC  ]; then
        wget "http://maven.nuxeo.org/nexus/service/local/artifact/maven/redirect?r=nuxeo-central&g=mysql&a=mysql-connector-java&v=$MYSQL_JDBC_VERSION&p=jar" || exit
    fi
    cp $MYSQL_JDBC  "$JBOSS_HOME"/server/default/lib/ || exit 1
    echo "### Initializing MySQL DATABASE: $MYSQL_DB"
    mysql -u $MYSQL_USER --password=$MYSQL_PASSWORD <<EOF || exit 1
DROP DATABASE $MYSQL_DB;
CREATE DATABASE $MYSQL_DB;
EOF

    NXC_VERSION=$(cd "$JBOSS_HOME"; ls server/default/deploy/nuxeo.ear/system/nuxeo-core-storage-sql-ra-*.rar |cut -d"-" -f6- )

    [ -z $NXC_VERSION ] && exit 1

    # switch nxtags to unified ds
    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/datasources/nxtags-ds.xml <<EOF || exit 1
<?xml version="1.0"?>
<datasources>
  <mbean code="org.jboss.naming.NamingAlias"
    name="jboss.jca:name=nxtags,service=DataSourceBinding">
    <attribute name="ToName">java:/NuxeoDS</attribute>
    <attribute name="FromName">java:/nxtags</attribute>
  </mbean>
</datasources>
EOF

    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/datasources/default-repository-ds.xml <<EOF || exit 1
<?xml version="1.0"?>
<connection-factories>
  <tx-connection-factory>
    <jndi-name>NXRepository/default</jndi-name>
    <xa-transaction/>
    <track-connection-by-tx/>
    <adapter-display-name>Nuxeo SQL Repository DataSource</adapter-display-name>
    <rar-name>nuxeo.ear#nuxeo-core-storage-sql-ra-$NXC_VERSION</rar-name>
    <connection-definition>org.nuxeo.ecm.core.storage.sql.Repository</connection-definition>
    <config-property name="name">default</config-property>

    <config-property name="xaDataSource" type="java.lang.String">com.mysql.jdbc.jdbc2.optional.MysqlXADataSource</config-property>
    <config-property name="property" type="java.lang.String">URL=jdbc:mysql://$MYSQL_HOST:$MYSQL_PORT/$MYSQL_DB?relaxAutoCommit=true</config-property>
    <config-property name="property" type="java.lang.String">User=$MYSQL_USER</config-property>
    <config-property name="property" type="java.lang.String">Password=$MYSQL_PASSWORD</config-property>

  </tx-connection-factory>
</connection-factories>
EOF

    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/datasources/unified-nuxeo-ds.xml <<EOF || exit 1
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
   <local-tx-datasource>
     <jndi-name>NuxeoDS</jndi-name>
     <driver-class>com.mysql.jdbc.Driver</driver-class> 
     <connection-url>jdbc:mysql://$MYSQL_HOST:$MYSQL_PORT/$MYSQL_DB?relaxAutoCommit=true</connection-url>
     <user-name>$MYSQL_USER</user-name>
     <password>$MYSQL_PASSWORD</password>
     <min-pool-size>5</min-pool-size>
     <max-pool-size>20</max-pool-size>
  </local-tx-datasource>
</datasources>
EOF

    # XA raise XAER_RMFAIL  on table creation
    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/datasources/unified-nuxeo-ds.xml-xa <<EOF || exit 1
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
   <xa-datasource>
     <jndi-name>NuxeoDS</jndi-name>
     <track-connection-by-tx/>
     <xa-datasource-class>com.mysql.jdbc.jdbc2.optional.MysqlXADataSource</xa-datasource-class>
     <xa-datasource-property name="URL">jdbc:mysql://$MYSQL_HOST:$MYSQL_PORT/$MYSQL_DB?relaxAutoCommit=true</xa-datasource-property>
     <xa-datasource-property name="User">$MYSQL_USER</xa-datasource-property>
     <xa-datasource-property name="Password">$MYSQL_PASSWORD</xa-datasource-property>
   </xa-datasource>
</datasources>
EOF

    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/config/default-repository-config.xml <<EOF || exit 1
<?xml version="1.0"?>
<component name="default-repository-config">
  <extension target="org.nuxeo.ecm.core.repository.RepositoryService"
    point="repository">
    <repository name="default"
      factory="org.nuxeo.ecm.core.storage.sql.coremodel.SQLRepositoryFactory">
      <repository name="default">
        <schema>
          <field type="largetext">note</field>
        </schema>
      </repository>
    </repository>
  </extension>
</component>
EOF


    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/config/sql.properties <<EOF || exit 1
# Jena database type and transaction mode
org.nuxeo.ecm.sql.jena.databaseType=MySQL
org.nuxeo.ecm.sql.jena.databaseTransactionEnabled=false
EOF


}
