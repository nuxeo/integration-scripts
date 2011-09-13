#!/bin/bash -x
PRODUCT=${PRODUCT:-dm}
SERVER=${SERVER:-jboss}
BENCH_TARGET=${BENCH_TARGET:-bench-long}
HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh
CMISBENCH=cmisbench-jm
JMETER_HOME=/opt/build/tools/jmeter
# size of generated file
SIZE_KB=${SIZE_KB:8}
THREADS=${THREADS:20}
# time to go from 1 to THREADS threads
RAMPUP=${RAMPUP:400}
# total duration of the bench
DURATION=${DURATION:600}


# Cleaning
rm -rf ./jboss ./report ./results ./download
mkdir ./results ./download || exit 1

# Check JMeter
if [ ! -r $JMETER_HOME/lib/junit ]; then
    echo "ERROR $JMETER_HOME/lib/junit must be writable"
    exit 1
fi

# Setup JMeter script and deploy JUnit test
if [ ! -d $CMISBENCH ]; then
    git clone git://github.com/nuxeo/tools-nuxeo-cmis-jmeter.git $CMISBENCH || exit 1
else
    (cd $CMISBENCH &&  git pull) || exit 1
fi

# Configure bench
cat > $CMISBENCH/build.properties <<EOF || exit 1
jmeter.home=$JMETER.HOME
username=Administrator
password=Administrator
base_url=http://localhost:8080/nuxeo/atom/cmis
size_kb=$SIZE_KB
threads=$THREADS
rampup=$RAMPUP
duration=$DURATION
EOF

# Build and deploy JUnit test 
(cd $CMISBENCH  && ant deploy) || exit 1


# Build
update_distribution_source
if [ "$SERVER" = "tomcat" ]; then
    build_tomcat
    NEW_TOMCAT=true
    setup_tomcat 127.0.0.1
else
    build_jboss
    NEW_JBOSS=true
    setup_jboss 127.0.0.1
    deploy_ear
fi

# Setup PostgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_postgresql_database
fi

# Start Nuxeo
start_server 127.0.0.1

# Run the bench
echo "Benching  ..."
(cd $CMISBENCH && ant run)
ret1=$?

# Move the bench report
mv $CMISBENCH/reports report

# Stop nuxeo
stop_server

# Exit if some tests failed
[ $ret1 -eq 0 ] || exit 9
