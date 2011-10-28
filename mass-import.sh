#!/bin/bash -x
PRODUCT=${PRODUCT:-dm}
SERVER=${SERVER:-jboss}
HERE=$(cd $(dirname $0); pwd -P)
. $HERE/integration-lib.sh

LASTBUILD_URL=${LASTBUILD_URL:-http://qa.nuxeo.org/hudson/job/IT-nuxeo-5.5-build/lastSuccessfulBuild/artifact/trunk/release/archives}
ZIP_FILE=${ZIP_FILE:-}

NBNODES=${NBNODES:-1000}
FILESIZEKB=${FILESIZEKB:-50}
THREADS=${THREADS:-1 2 3 4 5 6 7 8 9 10 1}
#THREADS=${THREADS:-1 2 3 4 5 6 1}

# Cleaning
rm -rf ./jboss ./results ./download ./tomcat
mkdir ./results ./download || exit 1

cd download
if [ -z $ZIP_FILE ]; then
    # extract list of links
    link=`lynx --dump $LASTBUILD_URL | grep -o "http:.*archives\/nuxeo\-.*.zip\(.md5\)*" | sort -u |grep $PRODUCT-[0-9]|grep $SERVER|grep -v md5|grep -v ear`
    wget -nv $link || exit 1
    ZIP_FILE=nuxeo-$PRODUCT*$SERVER.zip
fi
unzip -q $ZIP_FILE || exit 1
cd ..
build=$(find ./download -maxdepth 1 -name 'nuxeo-*' -name "*$PRODUCT*" -type d)
mv $build ./$SERVER || exit 1

[ "$SERVER" = jboss ] && setup_jboss 127.0.0.1
[ "$SERVER" = tomcat ] && setup_tomcat 127.0.0.1

# Use postgreSQL
if [ ! -z $PGPASSWORD ]; then
    setup_postgresql_database
fi

# mass import COMPIL
npi="./nuxeo-platform-importer"
if [ ! -d $npi ]; then
    hg clone http://hg.nuxeo.org/addons/nuxeo-platform-importer nuxeo-platform-importer || exit 1
fi
(cd $npi && hg pull && hg up -C 5.5) || exit 1
(cd $npi; mvn -Dmaven.test.skip=true clean install) || exit 1
[ -r $SERVER/nxserver/bundles ] && dest=$SERVER/nxserver/bundles
[ -r $SERVER/server/default/deploy/nuxeo.ear/bundles ] && dest=$SERVER/server/default/deploy/nuxeo.ear/bundles

find $npi -type f -name '*.[js]ar' ! -name '*sources.jar' | grep target | xargs -i cp {} $dest/ || exit 1

# Start Server
start_server 127.0.0.1

# create a document to init the database
time curl -u Administrator:Administrator "http://127.0.0.1:8080/nuxeo/site/randomImporter/run?targetPath=/default-domain/workspaces&batchSize=10&nbThreads=1&interactive=true&nbNodes=5&fileSizeKB=$FILESIZEKB&bulkMode=true&onlyText=false"

# drop fulltext trigger and gin index
psql $DBNAME -U $DBUSER -h $DBHOST -p $DBPORT <<EOF || exit 1
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
    time curl -s -v -u Administrator:Administrator "http://127.0.0.1:8080/nuxeo/site/randomImporter/run?targetPath=/default-domain/workspaces&batchSize=10&nbThreads=$thread&interactive=true&nbNodes=$NBNODES&fileSizeKB=$FILESIZEKB&bulkMode=true&onlyText=false"
    ret1=$?
    sleep 30
done

# Stop nuxeo
stop_server

# Exit if some tests failed
exit $ret1

# --------------------- misc notes
# test creation
time curl -vu Administrator:Administrator "http://127.0.0.1:8080/nuxeo/site/randomImporter/run?targetPath=/default-domain/workspaces&batchSize=10&nbThreads=1$thread&interactive=true&nbNodes=100&fileSizeKB=50&bulkMode=true&onlyText=false"

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
