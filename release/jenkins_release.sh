#!/bin/bash
#
# Bash command executed by Jenkins to pass parameters and call release
# scripts.
#
# (C) Copyright 2009-2014 Nuxeo SA (http://nuxeo.com/) and contributors.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the GNU Lesser General Public License
# (LGPL) version 2.1 which accompanies this distribution, and is available at
# http://www.gnu.org/licenses/lgpl-2.1.html
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# Contributors:
#

echo JAVA_OPTS: $JAVA_OPTS

if [ ! -z $JDK_PATH ]; then
  export JAVA_HOME=$JDK_PATH
  export PATH=$JDK_PATH/bin:$PATH
fi

export PATH=$MAVEN_PATH/bin:$PATH
if [ ! -z $MAVEN_XMX_RELEASE ]
then
    export MAVEN_OPTS="-Xmx$MAVEN_XMX_RELEASE -Xms1g -XX:MaxPermSize=512m"
else
    export MAVEN_OPTS="-Xmx1g -Xms1g -XX:MaxPermSize=512m"
fi

# remove jenkins archives from workspace if any (?)
rm -rf $WORKSPACE/archives/

# create a specific directory for release scripts
rmdir jenkins_release_dir 2> /dev/null
mkdir -p jenkins_release_dir
cd jenkins_release_dir

# retrieve release scripts
for file in release.py nxutils.py terminalsize.py IndentedHelpFormatterWithNL.py ; do
  wget --no-check-certificate https://raw.github.com/nuxeo/nuxeo/master/scripts/$file -O $file
done
chmod +x *.py

# retrieve utility file for task using jenkins_perform.py, in case release is not
# performed right away
for file in jenkins_perform.sh; do
  wget --no-check-certificate https://raw.github.com/nuxeo/integration-scripts/master/jenkins/$file -O $file
done
chmod +x *.sh

# build up command line options for the release.py script from Jenkins build parameters
OPTIONS=( )
if [ $FINAL = true ]; then
  OPTIONS+=("-f")
fi
if [ ! -z $OTHER_VERSION_TO_REPLACE ]; then
  OPTIONS+=("--arv=$OTHER_VERSION_TO_REPLACE")
fi
if [ $SKIP_TESTS = true ]; then
  OPTIONS+=("--skipTests")
fi
if [ ! -z $PROFILES ]; then
  OPTIONS+=("-p $PROFILES")
fi
if [ ! -z "$MSG_COMMIT" ]; then
  # FIXME: this will fail if message contains a quote but above option fails
  # further down the line when parsing the command in the release.py script
  #OPTIONS+=("--mc="$(printf %q "$MSG_COMMIT"))
  OPTIONS+=("--mc=$MSG_COMMIT")
fi
if [ ! -z "$MSG_TAG" ]; then
  # FIXME: this will fail if message contains a quote but above option fails
  # further down the line when parsing the command in the release.py script
  #OPTIONS+=("--mt="$(printf %q "$MSG_TAG"))
  OPTIONS+=("--mt=$MSG_TAG")
fi

echo Prepare release
echo "../release.py prepare -b $BRANCH -t $TAG -n $NEXT_SNAPSHOT -m $MAINTENANCE ${OPTIONS[@]}"
../release.py prepare -b "$BRANCH" -t "$TAG" -n "$NEXT_SNAPSHOT" -m "$MAINTENANCE" "${OPTIONS[@]}"

# . $WORKSPACE/release.log

echo Check prepared release
git checkout $BRANCH
git pull
git push -n origin $BRANCH
git log $BRANCH..origin/$BRANCH
echo

if [ $NO_STAGING = true ]; then
  echo Perform release
  echo "../release.py perform"
  ../release.py perform
fi