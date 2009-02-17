================================
nuxeo integration release
================================

Test the release process for a 5.2 under continuous integration.

It requires nx-builder:
http://svn.nuxeo.org/nuxeo/tools/nx-builder/trunk

The test.sh script is used by hudson and can be configured::

  ADDONS="addon1 addon2" JBOSS_ARCHIVE=/path/to/jboss.zip ./test.sh

It will produces a zip distribution including addons ::

   release/archive/nuxeo-ep-090217.zip

