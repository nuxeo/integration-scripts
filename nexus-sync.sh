#!/bin/bash

TIMEOUT=${TIMEOUT:-1}
REPO=${REPO:-public-snapshots}
DELAY=${DELAY:-2}

cd $1

find ./org/nuxeo/ -mtime -1 \( -name "*.jar" -o -name "*.pom" -o -name "*.zip" \) | \
  while read artifact; do
    BASE=`basename $artifact`
    EXTENSION=${BASE##*.}
    ARTIFACT=${BASE%.*}
    CLASSIFIER=$(echo $ARTIFACT|sed -e "s/.*[0-9]//"|sed -e "s/^-//")
    ARTIFACT=$(echo $ARTIFACT|sed -e "s/-[0-9].*//")
    DIR=`dirname $artifact`
    VERSION=`basename $DIR`
    GROUP=`dirname $DIR`
    GROUP=`dirname $GROUP`
    GROUP=`echo $GROUP |tr -s '/' '.'|cut -c 2-` 
    
    URL="https://maven.nuxeo.org/nexus/service/local/artifact/maven/redirect?r=$REPO&g=$GROUP&a=$ARTIFACT&v=$VERSION&e=$EXTENSION"
    [ -z $CLASSIFIER ] || URL="$URL&c=$CLASSIFIER"
    
    echo wget -O/dev/null --timeout $TIMEOUT --no-check-certificate \"$URL\"
    wget -O/dev/null --tries 1 --timeout $TIMEOUT --no-check-certificate "$URL"
    sleep $DELAY
  done 
