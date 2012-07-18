#!/bin/bash

for zip in $* ; do
  if [ ! -e $zip ]; then
    echo Ignore non existing $zip!
    continue
  fi
  echo Fixing $zip ...
  SOURCE_DIR=$(dirname $zip)
  DIR=$(basename $zip | sed "s/.zip//")
  rm -rf /tmp/$DIR/
  unzip $zip -d /tmp/
  cd /tmp/
  chmod +x $DIR/bin/*ctl $DIR/bin/*.sh $DIR/bin/*.command $DIR/*.command
  zip -r $DIR.zip $DIR/ && mv $DIR.zip $zip
  rm -rf $DIR/
  cd -
  md5sum $zip>$zip.md5
done