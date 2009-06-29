#!/bin/bash -x
HERE=$(cd $(dirname $0); pwd -P)

. $HERE/integration-lib.sh

BUILD_URL=${BUILD_URL:-http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Integration_build/lastSuccessfulBuild/artifact/trunk/release/archives}
UPLOAD_URL=${UPLOAD_URL:-}
ZIP_FILE=${ZIP_FILE:-}

NBNODES=${NBNODES:-1000}
FILESIZEKB=${FILESIZEKB:-50}
THREADS=${THREADS:-1 2 3 4 5 6 7 8 9 10 1}
#THREADS=${THREADS:-1 2 3 4 5 6 1}

# Cleaning
rm -rf ./jboss ./results ./download
mkdir ./results ./download || exit 1

cd download
if [ -z $ZIP_FILE ]; then
    # extract list of links
    links=`lynx --dump $BUILD_URL | grep -o "http:.*nuxeo\-dm.*.zip" | sort -u`

    # Download and unpack the lastest builds
    for link in $links; do
        wget -nv $link || exit 1
    done

    unzip -q nuxeo-*jboss*.zip
else
    unzip -q $ZIP_FILE || exit 1
fi
cd ..

# JBOSS tests --------------------------------------------------------

build=$(find ./download -maxdepth 1 -name 'nuxeo-*'  -type d)
mv $build ./jboss || exit 1


# Update selenium tests
update_distribution_source

# Use postgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_database
fi

# mass import COMPIL
npi="$NXDIR/nuxeo-platform-importer"
if [ ! -d $npi ]; then
    (cd $NXDIR; hg clone -r 5.2 http://hg.nuxeo.org/sandbox/nuxeo-platform-importer nuxeo-platform-importer) || exit 1
else
    (cd $npi && hg pull && hg up -C 5.2) || exit 1
fi

(cd $npi; mvn -Dmaven.test.skip=true clean install) || exit 1
find $npi -type f -name '*.[js]ar' ! -name '*sources.jar' | grep target | xargs -i cp {} $JBOSS_HOME/server/default/deploy/nuxeo.ear/system/ || exit 1

# remove ooo daemon
cp ./ooo-config.xml $JBOSS_HOME/server/default/deploy/nuxeo.ear/config/

# Start jboss
start_jboss


# create a document to init the database
time curl -u Administrator:Administrator "http://localhost:8080/nuxeo/site/randomImporter/run?targetPath=/default-domain/workspaces&batchSize=10&nbThreads=1&interactive=true&nbNodes=5&fileSizeKB=$FILESIZEKB&bulkMode=true&onlyText=false"

# drop fulltext trigger and gin index
psql $dbname -U qualiscope -h localhost -p $DBPORT <<EOF || exit 1
DROP TRIGGER IF EXISTS nx_trig_ft_update ON fulltext;
DROP INDEX IF EXISTS fulltext_fulltext_idx;
CREATE OR REPLACE FUNCTION nx_to_tsvector(string character varying) RETURNS tsvector
  AS 'SELECT NULL::tsvector'
  LANGUAGE 'SQL';
EOF


# Run mass import test
ret1=9

for thread in $THREADS; do
    echo "### Import with $thread threads ----------------------------------"
    date --rfc-3339=seconds
    time curl -s -v -u Administrator:Administrator "http://localhost:8080/nuxeo/site/randomImporter/run?targetPath=/default-domain/workspaces&batchSize=10&nbThreads=$thread&interactive=true&nbNodes=$NBNODES&fileSizeKB=$FILESIZEKB&bulkMode=true&onlyText=false"
    ret1=$?
    sleep 30
done


# Stop nuxeo
stop_jboss

# Exit if some tests failed
exit $ret1

# --------------------- misc notes
# test creation
time curl -vu Administrator:Administrator "http://localhost:8080/nuxeo/site/randomImporter/run?targetPath=/default-domain/workspaces&batchSize=10&nbThreads=1$thread&interactive=true&nbNodes=100&fileSizeKB=50&bulkMode=true&onlyText=false"

# recreate fulltext trigger and idx
CREATE TRIGGER nx_trig_ft_update
    BEFORE INSERT OR UPDATE ON fulltext
    FOR EACH ROW
    EXECUTE PROCEDURE nx_update_fulltext();
ALTER TABLE fulltext DISABLE TRIGGER nx_trig_ft_update;
CREATE INDEX fulltext_fulltext_idx ON fulltext USING gin (fulltext);


# drop fulltext
DROP TRIGGER IF EXISTS nx_trig_ft_update ON fulltext;
DROP INDEX fulltext_fulltext_idx;
CREATE OR REPLACE FUNCTION nx_to_tsvector(string character varying) RETURNS tsvector
  AS 'SELECT NULL::tsvector'
  LANGUAGE 'SQL';
EOF
