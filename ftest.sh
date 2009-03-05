#!/bin/sh -x

# non standard date pattern
NOW=$(date +"%y%m%d")
DAILY_RELEASE=${DAILY_RELEASE:-nuxeo-ep-5.2-${NOW}}
DAILY_DOWNLOAD="zope@gironde.nuxeo.com:/home/zope/static/nuxeo.org/snapshots"
NXVERSION=${NXVERSION:-5.2}

# download and start last packaged server
rm -f nuxeo-ep*.zip
wget -nv -r -nd http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Release/lastSuccessfulBuild/artifact/trunk/release/archives/${DAILY_RELEASE}.zip || exit 1
unzip -q ${DAILY_RELEASE}.zip || exit -1
mkdir -p output
rm -rf output/jboss
mv ${DAILY_RELEASE} output/jboss
echo "BINDHOST=0.0.0.0" > output/jboss/bin/bind.conf

# Start jboss
output/jboss/bin/jbossctl start || exit 1

# Run functional tests
mkdir -p "$PWD/results/" 2>/dev/null
CMD="xvfb-run java -jar selenium/selenium-server.jar -port 14440 -timeout 7200 "
if [ $NXVERSION = "5.1" ] ; then
        suite1=suite1.html
        suite2=suite2.html
else
        suite1=suite1-5.2.html
        suite2=suite2-5.2.html
fi

$CMD -htmlSuite "*firefox" http://127.0.0.1:8080/nuxeo/ \
  "$PWD/selenium/tests/$suite1" "$PWD/results/results1.html" \
   -userExtensions selenium/user-extensions.js

ret1=$?

$CMD -htmlSuite "*firefox" http://127.0.0.1:8080/nuxeo/ \
  "$PWD/selenium/tests/$suite2" "$PWD/results/results2.html" \
  -userExtensions selenium/user-extensions.js
ret2=$?

# Stop nuxeo
output/jboss/bin/jbossctl stop

[ $ret1 -eq 0 -a $ret2 -eq 0 ] || exit 9

## upload succesfully tested package on http://www.nuxeo.org/static/snapshots/
scp -C ${DAILY_RELEASE}.zip $DAILY_DOWNLOAD || exit 1
rm -f ${DAILY_RELEASE}.zip
