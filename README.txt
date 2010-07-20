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

* cluster mode is tested using pound
  sudo aptitude install pound

* system monitoring sysstat sar
  sudo aptitude install sysstat

* PostgreSQL with a qualiscope account:
  sudo -u postgres createuser -SdRPe qualiscope
  sudo -u postgres createlang plpgsql template1

* PostgreSQL log for pgfouine report

  - setup PostgreSQL config  with log in /var/log/pgsql
     http://pgfouine.projects.postgresql.org/tutorial.html

  - aptitude install logtail

* oracle 10

  Make this work:
  ssh -l oracle $ORACLE_HOST sqlplus $ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_SID
  scp oracle@$ORACLE_HOST:/opt/oracle/10g/jdbc/lib/ojdbc14.jar .

  WARNING the script will remove all objects in the $ORACLE_USER schema.
  To enable read acl optim:
  GRANT EXECUTE ON DBMS_CRYPTO TO nuxeo;

* mysql

  aptitude install mysql-server mysql-client
  mysql -u root -p
  CREATE DATABASE qualiscope_ci;
  CREATE USER 'qualiscope'@'localhost' IDENTIFIED BY 'secret';
  GRANT ALL PRIVILEGES ON *.* TO 'qualiscope'@'localhost' WITH GRANT OPTION;
  quit

  Add to /etc/mysql/my.cnf in [mysqld]  lower_case_table_names=1



Scripts
========

package-all-distributions.sh
-------------------------------

Apply the release process and build jboss zip, jboss jar (izpack), webengine
glassfish zip and webengine jetty zip.

Options
~~~~~~~~

JBOSS_ARCHIVE   Path of the jboss 4.2.3 zip
ADDONS          List of nuxeo addons to release after nuxeo source code and before
                nuxeo-distribution
TAG             The 5.2.x release tag like "-b" for beta or "-RC1" for
                release candidate, default is integration build tag
                "-I20090316_1200", to release the final 5.2.x use "TAG=final".
LABEL           (DEPRECATED) The jboss zip label can be "all" to produce
                nuxeo-ep-5.2.0-jboss-all.zip fo instance.
DISTRIBUTIONS   DEFAULT -> Archive only the jboss zip
                ALL -> Archive all distributions

Outputs
~~~~~~~~

 * Packages: release/archives/*
   - nuxeo-*-5.4.0-$TAG-jboss.zip
   - nuxeo-*-5.4.0-$TAG-tomcat.zip
   - all md5 files
   

test-all-distributions.sh
------------------------------

Run test on all available distribution including:

  - funkload test on webengine jetty/glassfish
  - selenium test on jboss
  - funkload test on webengine jboss
  - shell test (TODO)

Options
~~~~~~~~

LASTBUILD_URL   Where to get the builds, permalinks to hudson artifacts (lastSuccessfulBuild)
UPLOAD_URL  Where to upload the builds if all tests pass
            nuxeo@styx.nuxeo.com:/opt/www/www.nuxeo.org/static/snapshots/
JAVA6_HOME  Java 6 path for glassfish tests
PGPASSWORD  Use PostgreSQL 8.3 for unified data source and VCS using qualiscope
            account with the $PGPASSWORD password.
DBPORT      PostgreSQL local port 5432 by default

Output
~~~~~~~~

* Selenium test results:
  src-5.2/nuxeo-distribution/nuxeo-distribution-dm/ftest/selenium/result-*.html

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
PGPASSWORD Use PostgreSQL for unified data source and VCS using qualiscope
           account with the $PGPASSWORD password.
Output
~~~~~~~~

* Selenium test results:
  src-5.2/nuxeo-distribution/nuxeo-distribution-dm/ftest/selenium/result-*.html

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

  trunk/src-5.2/nuxeo-distribution/nuxeo-distribution-dm/ftest/selenium/result-*.html, trunk/jboss/server/default/log/*




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

  UPLOAD_URL="nuxeo@styx.nuxeo.com:/opt/www/www.nuxeo.org/static/snapshots/" \
    LASTBUILD_URL=http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Integration_build/lastBuild/ \
    ./test-all-distributions.sh

* Schedule: After a successful Integration_build

* Archive artifacts

  trunk/src-5.2/nuxeo-distribution/nuxeo-distribution-dm/ftest/selenium/result-*.html, trunk/jboss/server/default/log/*



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
  LASTBUILD_URL=http://selenium.nuxeo.org/hudson/job/Server_Test_5.2_-_Release_build/lastBuild/ \
    ./test-all-distributions.sh

* Schedule: After a successful Release_build

* Archive artifacts
 trunk/src-5.2/nuxeo-distribution/nuxeo-distribution-dm/ftest/selenium/result-*.html, trunk/jboss/server/default/log/*



