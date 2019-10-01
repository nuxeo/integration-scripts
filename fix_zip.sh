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
# packages managed by release_mp.py script
RELEASED_PACKAGES=$(grep uploaded ../nuxeo/marketplace/release.ini | cut -d ' ' -f 4-)
RELEASED_PACKAGES="$RELEASED_PACKAGES ../nuxeo/packages/nuxeo-*-package/target/nuxeo-*-package-*.zip"
# adding a default value just in case it is not defined upfront
FINAL=${FINAL:-False}

MP_DIR=mp-nuxeo-server
mkdir -p $MP_DIR
PACKAGES_XML=$MP_DIR/packages.xml
unzip -p nuxeo-server-*-tomcat.zip "**/setupWizardDownloads/packages.xml" > $PACKAGES_XML
featured=$(xmlstarlet sel -t -m '//packageDefinitions/package' -i "not(@virtual='true')" -v '@id' -n $PACKAGES_XML)
echo "$featured" > $MP_DIR/.featured

# Rename packages mentioned in the wizard; move all packages to $MP_DIR/
for file in $ARCHIVED_PACKAGES $RELEASED_PACKAGES; do
  name=$(unzip -p $file package.xml | xmlstarlet sel -t -v 'package/@name') || echo ERROR: package.xml parsing failed on $file >&2
  if [ -z "$name" ]; then
    continue
  elif [[ $featured =~ (^|[[:space:]])"$name"($|[[:space:]]) ]]; then
    cp $file $MP_DIR/$name.zip
    xmlstarlet ed -L -i "//packageDefinitions/package[@id='$name']" -t 'attr' -n 'filename' -v "$name.zip" $PACKAGES_XML
    md5=$(md5 $MP_DIR/$name.zip)
    xmlstarlet ed -L -i "//packageDefinitions/package[@id='$name']" -t 'attr' -n 'md5' -v "$md5" $PACKAGES_XML
  elif [ "${FINAL}" = "False" ]; then # embed all addons only for non final releases
    mv $file $MP_DIR/$name.zip
  fi
done

# Update ZIP archives
for zip in nuxeo-server-*-tomcat.zip nuxeo-server-*-tomcat-sdk.zip ; do
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
  cp $OLDPWD/$PACKAGES_XML $DIR/setupWizardDownloads/
  for file in $OLDPWD/$MP_DIR/*.zip; do
    md5=$(md5 $file)
    cp $file $DIR/setupWizardDownloads/$md5
  done
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
