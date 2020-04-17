#!/bin/bash -x
# (C) Copyright 2012-2017 Nuxeo SA (http://nuxeo.com/) and others.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Usage: ./fix_zip.sh
#
# Local path is the root of the release
#.
#├── archives
#│   └── mp-nuxeo-server
#├── archives.bak
#└── nuxeo
#    ├── marketplace
#    │   └── release.ini
#    ├── scripts
#    └── ...

# use openssl to compute digests to be portable between Linux and Mac OS X
# just the md5 hash
md5() {
  openssl dgst -md5 -hex $1 | cut -d ' ' -f 2
}
# md5 hash followed by two spaces then filename
md5sum() {
  echo "$(md5 $1)  $(basename $1)"
}
# just the sha256 hash
sha256() {
  openssl dgst -sha256 -hex $1 | cut -d ' ' -f 2
}
# sha256 hash followed by two spaces then filename
sha256sum() {
  echo "$(sha256 $1)  $(basename $1)"
}

mkdir -p archives
cd archives
# already renamed and archived by release.py script
ARCHIVED_PACKAGES="nuxeo-jsf-ui-*.zip"
# adding a default value just in case it is not defined upfront
FINAL=${FINAL:-False}

MP_DIR=mp-nuxeo-server
mkdir -p $MP_DIR

# Rename packages mentioned in the wizard; move all packages to $MP_DIR/
for file in $ARCHIVED_PACKAGES; do
  name=$(unzip -p $file package.xml | xmlstarlet sel -t -v 'package/@name') || echo ERROR: package.xml parsing failed on $file >&2
  if [ -z "$name" ]; then
    continue
  else
    mv $file $MP_DIR/$name.zip
  fi
done

# Update ZIP archives
for zip in nuxeo-server-*-tomcat.zip ; do
  if [ ! -e $zip ]; then
    echo Ignore non existing $zip!
    continue
  fi
  echo Fixing $zip ...
  DIR=$(basename $zip | sed "s/.zip//")
  cp $zip $(dirname $zip)/$DIR.bak.zip
  rm -rf /tmp/$DIR/ /tmp/$DIR.zip
  unzip $zip -d /tmp/
  cd /tmp/
  chmod +x $DIR/bin/*ctl $DIR/bin/*.sh $DIR/bin/*.command $DIR/*.command
  zip -r $DIR.zip $DIR/
  rm -rf $DIR/
  cd -
  mv /tmp/$DIR.zip $zip
  md5sum $zip > $zip.md5
  sha256sum $zip > $zip.sha256
done

for file in nuxeo-*-sources.zip; do
  md5sum $file > $file.md5
  sha256sum $file > $file.sha256
done

cd ..
mkdir -p archives.bak
mv archives/*.bak.zip archives.bak/
