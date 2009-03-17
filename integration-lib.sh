#!/bin/sh

HERE=$(cd $(dirname $0); pwd -P)
NXVERSION=${NXVERSION:-5.2}
NXDIR="$HERE/src-$NXVERSION"
JBOSS_ARCHIVE=${JBOSS_ARCHIVE:-~/jboss-4.2.3.GA.zip}
JBOSS_HOME="$HERE/jboss"


# update all source should be removed as soon as cyclic dependency is resolved
NXC_MODULES="nuxeo-common nuxeo-runtime nuxeo-core"
NXP_MODULES="nuxeo-theme nuxeo-platform nuxeo-webengine nuxeo-shell nuxeo-distribution"

_hgf() {
    repo=$1; shift
    modules=$1; shift
    force=
    if [ "$1x" = "--forcex" ]; then
        # do not exit on hg errors
        shift
        force=yes
    fi
    if [ "$1x" = "--with-rootx" ]; then
        shift
        if [ "$1x" = "--forcex" ]; then
            shift
            force=yes
        fi
        echo "[$repo] hg $@ ..."
        cd "$repo" || exit 1
        hg "$@" || [ ! -z $force ] || exit 1
    fi
    for mod in $modules; do
        echo "[$mod] hg $@ ..."
        cd "$repo/$mod" || exit 1
        hg "$@" || [ ! -z $force ] || exit 1
    done
}

nxc_hgf() {
    _hgf "$NXDIR" "$NXC_MODULES" "$@"
}

nxp_hgf() {
    _hgf "$NXDIR" "$NXP_MODULES" --with-root "$@"
}

update_all_sources() {
    if [ ! -d $NXDIR ]; then
        hg clone http://hg.nuxeo.org/nuxeo $NXDIR || exit 1
        cd $NXDIR
        hg clone http://hg.nuxeo.org/nuxeo/nuxeo-runtime || exit 1
        hg clone http://hg.nuxeo.org/nuxeo/nuxeo-core || exit 1
        hg clone http://hg.nuxeo.org/nuxeo/nuxeo-theme || exit 1
        hg clone http://hg.nuxeo.org/nuxeo/nuxeo-platform || exit 1
        hg clone http://hg.nuxeo.org/nuxeo/nuxeo-shell || exit 1
        hg clone http://hg.nuxeo.org/nuxeo/nuxeo-webengine || exit 1
        hg clone http://hg.nuxeo.org/nuxeo/nuxeo-distribution || exit 1
    else
        cd $NXDIR
        nxc_hgf pull
        nxp_hgf pull
    fi
    nxp_hgf up -C 5.2
    nxc_hgf up -C 1.5
}
# end of update_all_source

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

