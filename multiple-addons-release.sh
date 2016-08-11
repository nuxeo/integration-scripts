#!/bin/bash -xe
export MAVEN_OPTS="-Xms1024m -Xmx4096m"
echo JAVA_OPTS: $JAVA_OPTS
echo JAVA_HOME: $JAVA_HOME
export M2_HOME=/opt/build/tools/maven3
export PATH=$M2_HOME/bin:$PATH

rm -rf $WORKSPACE/archives/

pwd

echo Prepare Marketplace Packages
cd $WORKSPACE
wget https://raw.githubusercontent.com/nuxeo/integration-scripts/fix-NXP-20105-release-marketplace-addon-without-cap-nxr/$PACKAGES_NAME -O $WORKSPACE/marketplace-partial.ini
#mkdir $WORKSPACE/scripts

for file in release_mp.py release.py nxutils.py terminalsize.py IndentedHelpFormatterWithNL.py gitfunctions.sh; do
  wget --no-check-certificate https://raw.githubusercontent.com/nuxeo/nuxeo/master/scripts/$file -O $WORKSPACE/scripts/$file
done

chmod +x ./scripts/*

#sed -i "s/TAG/$TAG/" $WORKSPACE/marketplace-partial.ini
#sed -i "s/is_final=True/is_final=$FINAL/" $WORKSPACE/scripts/release_mp.py

./scripts/gitfunctions.sh
rm -rf marketplace || true
./scripts/release_mp.py clone -m file://$WORKSPACE/marketplace-partial.ini
cd marketplace
./scripts/release_mp.py prepare
echo CHECK PREPARE
gitf show -s --pretty=format:'%h%d'
for release in release-*; do echo $release: ; cat $release ; echo ; done
grep -C5 'skip = Failed' release.ini || true
grep uploaded release.ini
cd ..
git checkout -f scripts/release_mp.py scripts/nxutils.py

#echo Fix ZIP
#cd $WORKSPACE
#wget https://raw.githubusercontent.com/nuxeo/integration-scripts/master/fix_zip.sh -Ofix_zip.sh
#chmod +x fix_zip.sh
#./fix_zip.sh

#unzip -p archives/nuxeo-*-sources.zip nuxeo-distribution/nuxeo-distribution-tomcat/pom.xml > /tmp/pom.xml
#mvn deploy:deploy-file -Dfile=$(ls archives/nuxeo-cap-*-tomcat.zip) -DrepositoryId=nightly-staging -Durl=http://mavenin.nuxeo.com/nexus/content/repositories/nightly-staging/ -DpomFile=/tmp/pom.xml -Dclassifier=nuxeo-cap-full -DupdateReleaseInfo=true -Dpackaging=zip
#mvn deploy:deploy-file -Dfile=$(ls archives/nuxeo-server-*-tomcat.zip) -DrepositoryId=nightly-staging -Durl=http://mavenin.nuxeo.com/nexus/content/repositories/nightly-staging/ -DpomFile=/tmp/pom.xml -Dclassifier=full -DupdateReleaseInfo=true -Dpackaging=zip
