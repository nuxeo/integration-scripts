#!/bin/sh

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
    export PGPASSWORD="secret"
    dropdb $dbname -U qualiscope -h localhost
    createdb $dbname -U qualiscope -h localhost || exit 1
}

