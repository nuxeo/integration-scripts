#!/bin/bash -xe

LASTBUILD_URL=${LASTBUILD_URL:-https://qa.nuxeo.org/jenkins/job/Deploy/job/IT-nuxeo-master-build/lastSuccessfulBuild/artifact/archives}
HERE=$(cd $(dirname $0); pwd -P)

# Upload successfully tested package and sources on $UPLOAD_URL
UPLOAD_URL=${UPLOAD_URL:-}
SRC_URL=${SRC_URL:-download}
if [ ! -z "$UPLOAD_URL" ]; then
    ls $SRC_URL/*HF*.zip >/dev/null 2>&1 && exit 0 || true
    date
    scp -C $SRC_URL/*.zip* $UPLOAD_URL || true
    MP_DIR=$HERE/download/mp-nuxeo-server
    mkdir -p $MP_DIR
    cd $MP_DIR
    links=`lynx --dump -listonly $LASTBUILD_URL/mp-nuxeo-server | grep -E -o 'https?:.*archives\/mp[a-z-]+\/([a-z-]+\.zip|packages.xml|\.featured)' | sort -u`
    if [ ! -z "$links" ]; then
        wget -nv $links
    fi
    for pkg in $(cat .featured); do
        scp -C $pkg*.zip $UPLOAD_URL/mp-nuxeo-server/ || true
    done
    scp packages.xml $UPLOAD_URL/mp-nuxeo-server/ || true
    cd -
    date
fi
