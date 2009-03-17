================================
nuxeo integration release
================================

Integration builder, and tester.

Requirements
=============

* nx-builder:

  http://svn.nuxeo.org/nuxeo/tools/nx-builder/trunk

* lynx, wget

Scripts
========

* package-all-distributions.sh

Apply the release process and build jboss zip, jboss jar (izpack), webengine
glassfish zip and webengine jetty zip.

Options:

JBOSS_ARCHIVE   Path of the jboss 4.2.3 zip
ADDONS          List of nuxeo ep addons to deploy with the nuxeo ep ear
TAG             The 5.2.x release tag like "-b" for beta or "-RC1" for
                release candidate, default is integration build tag
                "-I20090316_1200", to release the final 5.2.x use "TAG=final".
LABEL           The jboss zip label can be "all" to produce
                nuxeo-ep-5.2.0-jboss-all.zip fo instance.
DISTRIBUTIONS   ZIP -> Build only the jboss zip
                ALL -> Build jboss zip, jar, jetty and glassfish

Outputs:
release/archives/
   - nuxeo-ep-5.2.0$TAG-jboss-$LABEL.zip
   - nuxeo-ep-5.2.0$TAG-jboss-$LABEL.jar
   - nuxeo-ep-5.2.0$TAG-jboss-$LABEL-win32-x86_64.exe (TODO)
   - nuxeo-we-5.2.0$TAG-jetty.zip
   - nuxeo-we-5.2.0$TAG-glassfish.zip
   - all md5 files

ex of jboss zip name
   - nuxeo-ep-5.2.0-RC1-jboss-all.zip
   - nuxeo-ep-5.2.0-I20090315_1200-jboss.zip



* test-all-distributions.sh

Run test on all available distribution including:

  - funkload test on webengine jetty/glassfish
  - selenium test on jboss
  - funkload test on webengine jboss
  - shell test (TODO)

Options:

BUILD_URL   Where to get the builds
            http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Release/lastSuccessfulBuild/artifact/trunk/release/archives
UPLOAD_URL  Where to upload the builds if all tests pass
            zope@gironde.nuxeo.com:/home/zope/static/nuxeo.org/snapshots
JAVA6_HOME  Java 6 path for glassfish tests





Jobs
=======

Integration
---------------

5.2_Integration_build

JBOSS_ARCHIVE=~/appservers/jboss-4.2.3.GA.zip \
./package-all-distributions.sh


5.2_Integration_test

UPLOAD_URL="zope@gironde.nuxeo.com:/home/zope/static/nuxeo.org/snapshots"
BUILD_URL=http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Integration_build/lastBuild/


TODO: describe job configuration


Release
---------------


5.2_Release_build

When: Manual launch

TAG="-RC1" \
LABEL="all" \
ADDONS="nuxeo-platform-annotations nuxeo-platform-preview \
nuxeo-platform-imaging nuxeo-platform-imaging-tiling \
nuxeo-platform-virtualnavigation nuxeo-platform-mail \
nuxeo-platform-restpack" \
JBOSS_ARCHIVE=~/appservers/jboss-4.2.3.GA.zip \
./package-all-distributions.sh


5.2_Release_test

When: After a successful release build

BUILD_URL=http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Release/lastBuild/


TODO: describe job configuraton









