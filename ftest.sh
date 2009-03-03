#!/bin/sh -x

# non standard date pattern
NOW=$(date +"%y%m%d")
DAILY_RELEASE=${DAILY_RELEASE:-nuxeo-ep-5.2-${NOW}}

# download and start last packaged server
wget http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Release/lastSuccessfulBuild/artifact/trunk/release/archives/${DAILY_RELEASE}.zip
unzip ${DAILY_RELEASE}.zip
echo "BINDHOST=127.0.0.1" >${DAILY_RELEASE}/bin/bind.conf
${DAILY_RELEASE}/bin/jbossctl start

# Run functional tests
#echo HOME_URL=\"http://127.0.0.1:8080/nuxeo/\" > runtests.conf
#chmod u+x runtests
#./runtests
mkdir -p "$PWD/results/" 2>/dev/null
CMD="xvfb-run java -jar selenium/selenium-server.jar -port 14440 -timeout 7200 "
$CMD -htmlSuite "*firefox" http://127.0.0.1:8080/nuxeo/ "$PWD/selenium/tests/suite1.html" "$PWD/results/results1.html"
$CMD -htmlSuite "*firefox" http://127.0.0.1:8080/nuxeo/ "$PWD/selenium/tests/suite2.html" "$PWD/results/results2.html"

#stop nuxeo
${DAILY_RELEASE}/bin/jbossctl stop

