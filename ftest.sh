#!/bin/sh -x

NXVERSION=${NXVERSION:-5.2}
LAST_BUILD_URL=http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Release/lastSuccessfulBuild/artifact/trunk/release/archives
LAST_BUILD=build.tar
DAILY_DOWNLOAD="zope@gironde.nuxeo.com:/home/zope/static/nuxeo.org/snapshots"

#cleaning
rm -rf ./jboss ./results ./download
mkdir ./results ./download || exit 1

# download and unpack distrib
cd download
wget -nv $LAST_BUILD_URL/$LAST_BUILD || exit 1
tar xvf $LAST_BUILD || exit 1
unzip -q *.zip
cd ..
build=$(find ./download -maxdepth 1 -name 'nuxeo-ep*'  -type d)
mv $build ./jboss || exit 1

# Start jboss
echo "BINDHOST=0.0.0.0" > jboss/bin/bind.conf
./jboss/bin/jbossctl start || exit 1


# Run selenium tests
CMD="xvfb-run -e xvfb.log java -jar selenium/selenium-server.jar -port 14440 -timeout 7200"
if [ $NXVERSION = "5.1" ] ; then
        suite1=suite1.html
        suite2=suite2.html
else
        suite1=suite1-5.2.html
        suite2=suite2-5.2.html
fi

($CMD -htmlSuite "*firefox" http://localhost:8080/nuxeo/ \
  "$PWD/selenium/tests/$suite1" "$PWD/results/results1.html" \
   -userExtensions selenium/user-extensions.js)
ret1=$?

($CMD -htmlSuite "*firefox" http://localhost:8080/nuxeo/ \
  "$PWD/selenium/tests/$suite2" "$PWD/results/results2.html" \
  -userExtensions selenium/user-extensions.js)
ret2=$?


# Stop nuxeo
./jboss/bin/jbossctl stop
gzip jboss/server/default/log/*.log

# Exit if some tests failed
[ $ret1 -eq 0 -a $ret2 -eq 0 ] || exit 9
date
# Upload succesfully tested package on http://www.nuxeo.org/static/snapshots/
scp ${build}.zip.md5 ${build}.zip $DAILY_DOWNLOAD || exit 1
date
