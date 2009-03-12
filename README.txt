================================
nuxeo integration release
================================

Integration builder, and tester.

Requirements
=============

* nx-builder:

  http://svn.nuxeo.org/nuxeo/tools/nx-builder/trunk


Integraiont build
====================

The test.sh script is used by hudson and can be configured::

  ADDONS="addon1 addon2" JBOSS_ARCHIVE=/path/to/jboss.zip ./test.sh

It will produces a build.tar file that contains
   the zip distribution including addons and a md5::

   nuxeo-ep-I20090217_1259.zip
   nuxeo-ep-I20090217_1259.zip.md5

Testing last successful build and make it available for download
==================================================================

The ftest.sh script download the latest build.tar available from hudson and
run selenium tests, if successful it upload the zip files.
