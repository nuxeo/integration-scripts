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

# Prepare wizard's packages.xml file and fill mp directory
mkdir archives/mp archives.bak
unzip -p archives/nuxeo-cap-*-tomcat.zip **/setupWizardDownloads/packages.xml > archives/mp/packages.xml
featured=`xmlstarlet sel -t -m '//packageDefinitions/package' -i "not(@virtual='true')" -v '@id' -n archives/mp/packages.xml`
for file in $(grep uploaded nuxeo/marketplace/release.ini |cut -d ' ' -f 4); do
    # name=`unzip -p $file package.xml|grep -oPm1 '(?<=name=")[^"]+'`
    name=`unzip -p $file package.xml|xmlstarlet sel -t -v 'package/@name'`
    if [[ $featured =~ (^|[[:space:]])"$name"($|[[:space:]]) ]]; then
      cp $file archives/mp/$name.zip
      xmlstarlet ed -L -i "//packageDefinitions/package[@id='$name']" -t 'attr' -n 'filename' -v "$name.zip" archives/mp/packages.xml
      md5=`md5sum archives/mp/$name.zip |cut -d ' ' -f 1`
      xmlstarlet ed -L -i "//packageDefinitions/package[@id='$name']" -t 'attr' -n 'md5' -v "$md5" archives/mp/packages.xml
    fi
done

# Update ZIP archives
cd archives
for zip in nuxeo-cap-*-tomcat.zip nuxeo-cap-*-tomcat-sdk.zip ; do
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
  cp $OLDPWD/mp/packages.xml $DIR/setupWizardDownloads/
  for file in $OLDPWD/mp/*.zip; do
      md5=`md5sum $file |cut -d ' ' -f 1`
      cp $file $DIR/setupWizardDownloads/$md5
  done
  zip -r $DIR.zip $DIR/
  rm -rf $DIR/
  cd -
  mv /tmp/$DIR.zip $zip
  md5sum $zip>$zip.md5
  shasum -a 256 $zip>$zip.sha256
done

for file in nuxeo-*-sources.zip; do
    md5sum $file > $file.md5
    shasum -a 256 $file > $file.sha256
done

cd ..
mv archives/*.bak.zip archives.bak/
