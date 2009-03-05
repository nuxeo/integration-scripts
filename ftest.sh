#!/bin/sh -x

# non standard date pattern
NOW=$(date +"%y%m%d")
NXVERSION=${NXVERSION:-5.2}
DAILY_RELEASE=${DAILY_RELEASE:-nuxeo-ep-${NXVERSION}-${NOW}}
DAILY_DOWNLOAD="zope@gironde.nuxeo.com:/home/zope/static/nuxeo.org/snapshots"
LAST_BUILD=http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Release/lastSuccessfulBuild/artifact/trunk/release/archives/${DAILY_RELEASE}.zip

#cleaning
rm -rf nuxeo-ep*.zip output results
mkdir results output

# download and start last packaged server
wget -nv -r -nd $LAST_BUILD || exit 1
unzip -q ${DAILY_RELEASE}.zip || exit -1
mv ${DAILY_RELEASE} output/jboss
echo "BINDHOST=0.0.0.0" > output/jboss/bin/bind.conf

# Start jboss
output/jboss/bin/jbossctl start || exit 1


# Run functional tests
CMD="xvfb-run java -jar selenium/selenium-server.jar -port 14440 -timeout 7200"
if [ $NXVERSION = "5.1" ] ; then
        suite1=suite1.html
        suite2=suite2.html
else
        suite1=suite1-5.2.html
        suite2=suite2-5.2.html
fi

date
$CMD -htmlSuite "*firefox" http://localhost:8080/nuxeo/ \
  "$PWD/selenium/tests/$suite1" "$PWD/results/results1.html" \
   -userExtensions selenium/user-extensions.js
ret1=$?
date
$CMD -htmlSuite "*firefox" http://localhost:8080/nuxeo/ \
  "$PWD/selenium/tests/$suite2" "$PWD/results/results2.html" \
  -userExtensions selenium/user-extensions.js
ret2=$?
date

# Stop nuxeo
output/jboss/bin/jbossctl stop
gzip output/jboss/server/default/log/*.log

# Exit if some tests failed
[ $ret1 -eq 0 -a $ret2 -eq 0 ] || exit 9

# Upload succesfully tested package on http://www.nuxeo.org/static/snapshots/
scp ${DAILY_RELEASE}.zip $DAILY_DOWNLOAD || exit 1

