#!/bin/bash -x
# Local path is root of release
#.
#├── archives
#│   └── mp
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
# package modules located under nuxeo-distribution
DISTRIB_PACKAGES="../nuxeo/nuxeo-distribution/nuxeo-marketplace-dm/target/nuxeo-marketplace-dm-*.zip"
# packages managed by release_mp.py script
RELEASED_PACKAGES=$(grep uploaded ../nuxeo/marketplace/release.ini | cut -d ' ' -f 4-)

MP_DIR=mp-nuxeo-server
mkdir -p $MP_DIR
PACKAGES_XML=$MP_DIR/packages.xml
unzip -p nuxeo-server-*-tomcat.zip "**/setupWizardDownloads/packages.xml" > $PACKAGES_XML
featured=$(xmlstarlet sel -t -m '//packageDefinitions/package' -i "not(@virtual='true')" -v '@id' -n $PACKAGES_XML)
echo "$featured" > $MP_DIR/.featured

# Rename packages mentioned in the wizard; move all packages to $MP_DIR/
for file in $ARCHIVED_PACKAGES $DISTRIB_PACKAGES $RELEASED_PACKAGES; do
  name=$(unzip -p $file package.xml | xmlstarlet sel -t -v 'package/@name') || echo ERROR: package.xml parsing failed on $file >&2
  if [ -z "$name" ]; then
    continue
  elif [[ $featured =~ (^|[[:space:]])"$name"($|[[:space:]]) ]]; then
    cp $file $MP_DIR/$name.zip
    xmlstarlet ed -L -i "//packageDefinitions/package[@id='$name']" -t 'attr' -n 'filename' -v "$name.zip" $PACKAGES_XML
    md5=$(md5 $MP_DIR/$name.zip)
    xmlstarlet ed -L -i "//packageDefinitions/package[@id='$name']" -t 'attr' -n 'md5' -v "$md5" $PACKAGES_XML
  else
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
