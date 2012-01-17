#!/bin/bash

SERVER=${SERVER:-tomcat}
HERE=$(cd $(dirname $0); pwd -P)

LASTBUILD_URL=${LASTBUILD_URL:-http://qa.nuxeo.org/hudson/job/IT-nuxeo-master-build/lastSuccessfulBuild/artifact/archives}
ZIP_FILE=${ZIP_FILE:-}
SKIP_FUNKLOAD=${SKIP_FUNKLOAD:-}

# Cleaning
rm -rf ./jboss ./results ./download ./tomcat* ./nuxeo*/
mkdir ./download || exit 1

if [ -z "$ZIP_FILE" ]; then
    cd download
    # extract link
    link=`lynx --dump $LASTBUILD_URL | grep -E -o "http:.*archives\/nuxeo-.*(-sdk)*.zip(.md5)*" | sort -u |grep cap-[0-9]|grep $SERVER|grep -v ear`
    wget -nv $link || exit 1
    export ZIP_FILE=$PWD/$(ls nuxeo-cap*$SERVER.zip)
    export SDK_ZIP_FILE=$PWD/$(ls nuxeo-cap*$SERVER-sdk.zip 2>/dev/null)
    cd ..
fi
export SOURCES_ZIP_FILE=`dirname $ZIP_FILE`/nuxeo-*-sources.zip
if [ ! -e "$SOURCES_ZIP_FILE" ]; then
    cd download
    # extract link
    link=`lynx --dump $LASTBUILD_URL |grep -o "http:.*archives\/.*sources.*\.zip"| sort -u`
    wget -nv $link || exit 1
    export SOURCES_ZIP_FILE=$PWD/$(ls *sources*.zip)
    cd ..
fi
unzip -q $ZIP_FILE -d download || exit 1
build=$(find ./download -maxdepth 1 -name 'nuxeo-*' -name "*cap*" -type d)
mv $build ./$SERVER || exit 1
unzip -q $SOURCES_ZIP_FILE -d nuxeo || exit 1
