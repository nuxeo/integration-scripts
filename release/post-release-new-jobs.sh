#!/bin/bash
#
# (C) Copyright 2015 Nuxeo SA (http://nuxeo.com/) and contributors.
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
#     Julien Carsique
#
# Create new Jenkins jobs after LTS release
#

function die {
    echo -e "${BASH_SOURCE[1]}:${BASH_LINENO[0]} (${FUNCNAME[1]}) ${1-die!}" >&2
    exit 1
}

[ "$#" -eq 2 ] || die 'Usage: post-release-new-jobs.sh new_release previous_release'
NEW_RELEASE=$1
PREVIOUS_RELEASE=$2
TMP_RELEASE=/tmp/release-$NEW_RELEASE
[ ! -d "$TMP_RELEASE" ] || die "Directory $TMP_RELEASE already exists"
command -v rename >/dev/null 2>&1 || die "Missing rename command\nsudo apt-get install rename"

echo "Will create jobs for $NEW_RELEASE, copying $PREVIOUS_RELEASE jobs..."

echo "Prepare list of jobs to copy"
ssh hudson@blancheneige "cd .jenkins/jobs; ls -d1 nuxeo-*$PREVIOUS_RELEASE* addons*master* FT-nuxeo-*$PREVIOUS_RELEASE* |sed 's/$PREVIOUS_RELEASE/master/g'|tee /tmp/listMaster"

echo "Prepare list of jobs to create"
scp hudson@blancheneige:/tmp/listMaster /tmp/
mkdir $TMP_RELEASE
rm /tmp/listToCreate
while IFS= read -r job; do
    scp hudson@blancheneige:~/.jenkins/jobs/$job/config.xml $TMP_RELEASE/$job.xml || continue
    echo "$job" | sed "s/master/$NEW_RELEASE/" >> /tmp/listToCreate
done < /tmp/listMaster
sed -i "s/master/$NEW_RELEASE/g" $TMP_RELEASE/*.xml
rename "s/master/$NEW_RELEASE/" $TMP_RELEASE/*.xml

echo "About to create jobs from /tmp/listToCreate and $TMP_RELEASE/"
read -rsp $'Press any key to continue...\n' -n1
while IFS= read -r job; do
    echo -e "\n### Creating $job..."
    curl -n -H "Content-Type: text/xml" -s --data-binary "@$TMP_RELEASE/$job.xml" "http://blancheneige:8080/jenkins/createItem?name=$job"
done < /tmp/listToCreate
