#!/bin/bash

for zip in "$*" ; do
  if [ ! -e $zip ]; then
    echo Ignore non existing $zip!
    continue
  fi
  echo Fixing $zip ...
  DIR=$(basename $zip | sed "s/.zip//")
  rm -rf /tmp/$DIR/ /tmp/$DIR.zip
  unzip $zip -d /tmp/
  cd /tmp/
  chmod +x $DIR/bin/*ctl $DIR/bin/*.sh $DIR/bin/*.command $DIR/*.command
  zip -r $DIR.zip $DIR/
  rm -rf $DIR/
  cd -
  mv /tmp/$DIR.zip $zip
  md5sum $zip>$zip.md5
done
