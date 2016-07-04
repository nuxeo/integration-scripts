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

NUXEO_JSF_UI=nuxeo-jsf-ui
mkdir -p archives
cd archives
for kind in nuxeo-server nuxeo-cap; do
  MP=mp-$kind
  mkdir -p $MP
  PACKAGES_XML=$MP/packages.xml
  unzip -p $kind-*-tomcat.zip "**/setupWizardDownloads/packages.xml" > $PACKAGES_XML
  featured=$(xmlstarlet sel -t -m '//packageDefinitions/package' -i "not(@virtual='true')" -v '@id' -n $PACKAGES_XML)

  # Loop on all uploaded marketplace packages and the nuxeo-jsf-ui one prepared for the release
  for file in $(grep uploaded ../nuxeo/marketplace/release.ini | cut -d ' ' -f 4) $NUXEO_JSF_UI-*.zip; do
      name=$(unzip -p $file package.xml | xmlstarlet sel -t -v 'package/@name')
      if [[ $featured =~ (^|[[:space:]])"$name"($|[[:space:]]) ]]; then
	cp $file $MP/$name.zip
	xmlstarlet ed -L -i "//packageDefinitions/package[@id='$name']" -t 'attr' -n 'filename' -v "$name.zip" $PACKAGES_XML
	md5=$(md5 $MP/$name.zip)
	xmlstarlet ed -L -i "//packageDefinitions/package[@id='$name']" -t 'attr' -n 'md5' -v "$md5" $PACKAGES_XML
      fi
  done

  # Update ZIP archives
  for zip in $kind-*-tomcat.zip $kind-*-tomcat-sdk.zip ; do
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
    for file in $OLDPWD/$MP/*.zip; do
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
done

for file in nuxeo-*-sources.zip; do
    md5sum $file > $file.md5
    sha256sum $file > $file.sha256
done

cd ..
mkdir -p archives.bak
mv archives/*.bak.zip archives.bak/
mv archives/$NUXEO_JSF_UI-*.zip archives.bak/
