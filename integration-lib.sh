#!/bin/bash

HERE=$(cd $(dirname $0); pwd -P)
NXVERSION=${NXVERSION:-5.2}
NXDIR="$HERE/src-$NXVERSION"
JBOSS_ARCHIVE=${JBOSS_ARCHIVE:-~/jboss-4.2.3.GA.zip}
JBOSS_HOME="$HERE/jboss"


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

build_and_deploy() {
    (cd "$NXDIR" && ant patch -Djboss.dir="$JBOSS_HOME") || exit 1
    (cd "$NXDIR" && ant copy-lib package copy -Djboss.dir="$JBOSS_HOME") || exit 1
}


start_jboss() {
    echo "BINDHOST=0.0.0.0" > "$JBOSS_HOME"/bin/bind.conf
    "$JBOSS_HOME"/bin/jbossctl start || exit 1
}

stop_jboss() {
    "$JBOSS_HOME"/bin/jbossctl stop
    gzip "$JBOSS_HOME"/server/default/log/*.log
}



setup_database() {
    dbname=$1
    if [ X$dbname = 'X' ]; then
        dbname=qualiscope-ci-$(( RANDOM%10 ))
    fi
    echo "### Initializing PostgreSQL DATABASE: $dbname"
    dropdb $dbname -U qualiscope -h localhost
    createdb $dbname -U qualiscope -h localhost || exit 1
    createlang plpgsql qualiscope-ci-7 -U qualiscope -h localhost || exit 1

    NXC_VERSION=$(cd "$JBOSS_HOME"; ls server/default/deploy/nuxeo.ear/system/nuxeo-core-storage-sql-ra-*.rar |cut -d"-" -f6- )

    [ -z $NXC_VERSION ] && exit 1

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
    <config-property name="property" type="java.lang.String">PortNumber/Integer=5432</config-property>
    <config-property name="property" type="java.lang.String">DatabaseName=$dbname</config-property>
    <config-property name="property" type="java.lang.String">User=qualiscope</config-property>
    <config-property name="property" type="java.lang.String">Password=$PGPASSWORD</config-property>
  </tx-connection-factory>
</connection-factories>

EOF

    cat > "$JBOSS_HOME"/server/default/deploy/nuxeo.ear/datasources/unified-nuxeo-ds.xml <<EOF || exit 1
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <local-tx-datasource>
  <jndi-name>NuxeoDS</jndi-name>
  <connection-url>jdbc:postgresql://localhost:5432/$dbname</connection-url>
  <driver-class>org.postgresql.Driver</driver-class>
  <user-name>qualiscope</user-name>
  <password>$PGPASSWORD</password>
  <check-valid-connection-sql>;</check-valid-connection-sql>
  </local-tx-datasource>
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

    cp -u ~/.m2/repository/postgresql/postgresql/8.2-*.jdbc3/postgresql-8.2-*.jdbc3.jar "$JBOSS_HOME"/server/default/lib/

}

