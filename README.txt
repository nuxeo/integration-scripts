================================
nuxeo integration release
================================

Integration builder, and tester.

Requirements
=============

* nx-builder:

  http://svn.nuxeo.org/nuxeo/tools/nx-builder/trunk

* funkload >=  FunkLoad 1.9.1b-r53416
  http://funkload.nuxeo.org/INSTALL.html

* lynx

* wget


Scripts
========

package-all-distributions.sh
-------------------------------

Apply the release process and build jboss zip, jboss jar (izpack), webengine
glassfish zip and webengine jetty zip.

Options
~~~~~~~~

JBOSS_ARCHIVE   Path of the jboss 4.2.3 zip
ADDONS          List of nuxeo ep addons to deploy with the nuxeo ep ear
TAG             The 5.2.x release tag like "-b" for beta or "-RC1" for
                release candidate, default is integration build tag
                "-I20090316_1200", to release the final 5.2.x use "TAG=final".
LABEL           The jboss zip label can be "all" to produce
                nuxeo-ep-5.2.0-jboss-all.zip fo instance.
DISTRIBUTIONS   ZIP -> Build only the jboss zip
                ALL -> Build jboss zip, jar, jetty and glassfish

Outputs
~~~~~~~~

 * Packages: release/archives/*
   - nuxeo-ep-5.2.0$TAG-jboss-$LABEL.zip
   - nuxeo-ep-5.2.0$TAG-jboss-$LABEL.jar
   - nuxeo-ep-5.2.0$TAG-jboss-$LABEL-win32-x86_64.exe (TODO)
   - nuxeo-we-5.2.0$TAG-jetty.zip
   - nuxeo-we-5.2.0$TAG-glassfish.zip
   - all md5 files

exemples:
   - nuxeo-ep-5.2.0-RC1-jboss-all.zip
   - nuxeo-ep-5.2.0-RC1-jboss-all.zip.md5
   - nuxeo-ep-5.2.0-I20090315_1200-jboss.zip



test-all-distributions.sh
------------------------------

Run test on all available distribution including:

  - funkload test on webengine jetty/glassfish
  - selenium test on jboss
  - funkload test on webengine jboss
  - shell test (TODO)

Options
~~~~~~~~

BUILD_URL   Where to get the builds, permalinks to hudson artifacts (lastSuccessfulBuild)
UPLOAD_URL  Where to upload the builds if all tests pass
            zope@gironde.nuxeo.com:/home/zope/static/nuxeo.org/snapshots
JAVA6_HOME  Java 6 path for glassfish tests

Output
~~~~~~~~

* Selenium test results:
  src-5.2/nuxeo-distribution/nuxeo-platform-ear/ftest/selenium/result-*.html

* Jboss logs
  jboss/server/default/log/*



build-and-test.sh
------------------------------

Deploy into a jboss then perform tests:

  - selenium test on jboss
  - funkload test on webengine jboss (TODO)
  - shell test (TODO)

The assembly used current ~/.m2/repo artifacts.

Options
~~~~~~~~

JBOSS_ARCHIVE The 4.2.3 zip archive
NEW_JBOSS     If set full reset of the jboss

Output
~~~~~~~~

* Selenium test results:
  src-5.2/nuxeo-distribution/nuxeo-platform-ear/ftest/selenium/result-*.html

* Jboss logs
  jboss/server/default/log/*


Hudson Jobs
============

Continuous builds
-------------------

FT-nuxeo-5.2-selenium
~~~~~~~~~~~~~~~~~~~~~~~~~~

* Execute shell

 JBOSS_ARCHIVE=~/appservers/jboss-4.2.3.GA.zip \
    ./build-and-tests.sh

* launched after nuxeo-distribution-5.2-skip.test

* Archive artifacts

  trunk/src-5.2/nuxeo-distribution/nuxeo-platform-ear/ftest/selenium/result-*.html, trunk/jboss/server/default/log/*




Integration
---------------

IT-nuxeo-5.2-build
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

* Execute shell

  DISTRIBUTIONS=ZIP \
    JBOSS_ARCHIVE=~/appservers/jboss-4.2.3.GA.zip \
    ./package-all-distributions.sh

* Schedule working day at 5AM

  0 5 * * 0-6

* Archive artifacts

  trunk/release/archives/*


IT-nuxeo-5.2-tests
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

* Execute shell

  UPLOAD_URL="zope@gironde.nuxeo.com:/home/zope/static/nuxeo.org/snapshots" \
    BUILD_URL=http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Integration_build/lastBuild/ \
    ./test-all-distributions.sh

* Schedule: After a successful Integration_build

* Archive artifacts

  trunk/src-5.2/nuxeo-distribution/nuxeo-platform-ear/ftest/selenium/result-*.html, trunk/jboss/server/default/log/*



Release
---------------

IT-nuxeo-5.2-release-build
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

* Execute shell

  TAG="-RC1" \
    LABEL="all" \
    ADDONS="nuxeo-platform-userworkspace \
nuxeo-searchcenter \
nuxeo-platform-nxwss-rootfilter \
nuxeo-platform-nxwss \
nuxeo-platform-annotations nuxeo-platform-preview \
nuxeo-platform-imaging nuxeo-platform-imaging-tiling \
nuxeo-platform-virtualnavigation nuxeo-platform-mail \
nuxeo-platform-restpack" \
    JBOSS_ARCHIVE=~/appservers/jboss-4.2.3.GA.zip \
    ./package-all-distributions.sh

* Schedule: Manual launch


IT-nuxeo-5.2-release-tests
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

When: After a successful release build

* Execute shell

  cd trunk
  BUILD_URL=http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Release_build/lastBuild/ \
    ./test-all-distributions.sh

* Schedule: After a successful Release_build

* Archive artifacts
 trunk/src-5.2/nuxeo-distribution/nuxeo-platform-ear/ftest/selenium/result-*.html, trunk/jboss/server/default/log/*



