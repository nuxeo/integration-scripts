================================
nuxeo integration release
================================

Integration builder, and tester.

Requirements
=============

* nx-builder:

  http://svn.nuxeo.org/nuxeo/tools/nx-builder/trunk



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

TODO

BUILD_URL   http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Release/lastSuccessfulBuild/artifact/trunk/release/archives
UPLOAD_URL  zope@gironde.nuxeo.com:/home/zope/static/nuxeo.org/snapshots
JAVA6_HOME  used by gf3





Jobs
=======

Integration
---------------

5.2_Integration_build
TODO: describe job configuration

5.2_Integration_test
TODO: describe job configuration


Release
---------------

5.2_Release_build
TODO: describe job configuration

5.2_Release_test
TODO: describe job configuratin









