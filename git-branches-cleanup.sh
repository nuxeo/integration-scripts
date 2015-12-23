#!/bin/bash +xe
#
# (C) Copyright 2010-2015 Nuxeo SA (http://nuxeo.com/) and contributors.
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
#     Theo Davidovits
#     Julien Carsique
#
# NXBT-736: cleanup deprecated branches

JIRA_PROJECTS="NXP|NXBT|APG|NXDRIVE|NXROADMAP|NXS|NXMOB|NXDOC"
PATTERNS='^origin/master$ \
 ^origin/[0-9]+(\.[0-9]+)+-SNAPSHOT$ \
 ^origin/[0-9]+(\.[0-9]+)+-HF[0-9]+-SNAPSHOT$ \
 ^origin/[0-9]+(\.[0-9]+)+$ \
 5.4.2-I20110404_0115'
# Output files
basedir=${PWD##*/}
FILE_LIST=/tmp/cleanup-$basedir-complete
FILE_UNKNOWN=/tmp/cleanup-$basedir-unknown
FILE_DELETE=/tmp/cleanup-$basedir-delete
FILE_KEEP=/tmp/cleanup-$basedir-keep

die() {
    #echo -e "${BASH_SOURCE[1]}:${BASH_LINENO[0]} (${FUNCNAME[1]}) ${1-die!}" >&2
    echo -e "${1-die!}" >&2
    exit 1
}

analyze() {
	echo "# Branches analyzed" > $FILE_LIST
	rm -f $FILE_UNKNOWN $FILE_DELETE $FILE_KEEP

	git fetch --prune
	complete=`git branch -r --list "origin/*"`
	nb_complete=`echo $complete|wc -w`

	echo "Nb branches before cleanup: $nb_complete"
	#	git reflog expire --all --expire=now
	#	git gc --prune=now --aggressive
	echo "Nb commit objects before cleanup: $(git rev-list --objects --all|wc -l)"
	git count-objects -vH

	echo "Looking for branches older than 3 months and which JIRA issue is resolved or closed, and with no 'backport-*' tag..."
	count=0
	for branch in $complete; do
		count=$(( $count + 1 ))
		printf "\r\e[K(%3d/%d) Analyzing branch %s ..." $count $nb_complete $branch
		echo "$branch" >> $FILE_LIST
		for pattern in $PATTERNS; do
			if [[ $branch =~ $pattern ]]; then
				printf "%-20s\t%-80s\t%s\n" "system" $branch "(pattern '$pattern')" >> $FILE_KEEP
				continue 2
			fi
		done

		author=$(git log -1 --no-merges --grep="Merge branch '.*' from multiple repositories" --invert-grep --pretty=format:'%aE' $branch)
		if [ -z "$(git log -1 --since='3 months ago' --oneline $branch)" ]; then
		    jira=$(echo "$branch" | awk -v jira_pattern="($JIRA_PROJECTS)-[0-9]+" 'match($0, jira_pattern) {print substr($0,RSTART,RLENGTH)}')
			if [ -z "$jira" ]; then
				printf "%-20s\t%-80s\t%s\n" $author $branch "(unknown pattern)" >> $FILE_UNKNOWN
				continue
			fi
			# Check JIRA ref exists
			rc=$(curl -I -o /dev/null -w "%{http_code}" -s https://jira.nuxeo.com/rest/api/2/issue/$jira)
			if [ $rc -ne 200 ]; then
				printf "%-20s\t%-80s\t%s\n" $author $branch "($jira does not exist)" >> $FILE_UNKNOWN
				continue
			fi
		    status=$(curl -s https://jira.nuxeo.com/rest/api/2/issue/$jira?fields=status|python -c 'import sys, json; print json.load(sys.stdin)["fields"]["status"]["id"]')
		    tags=$(curl -s https://jira.nuxeo.com/rest/api/2/issue/$jira?fields=customfield_10080|python -c 'import sys, json; print json.load(sys.stdin)["fields"]["customfield_10080"]')
			if (echo "$tags"|grep -q 'backport-'); then
				printf "%-20s\t%-80s\t%s\n" $author $branch "($jira has a backport tag)" >> $FILE_KEEP
			elif [ $status -eq 5 -o $status -eq 6 ]; then
				printf "%-20s\t%-80s\t%s\n" $author $branch "($jira is resolved)" >> $FILE_DELETE
			else
				printf "%-20s\t%-80s\t%s\n" $author $branch "($jira not resolved)" >> $FILE_KEEP
			fi
		else
			printf "%-20s\t%-80s\t%s\n" $author $branch "(<3 months)" >> $FILE_KEEP
		fi
	done

	echo "# Unknown status. JIRA ref pattern is: '($JIRA_PROJECTS)-[0-9]+'" > $FILE_UNKNOWN.tmp
	echo "# Branches to delete" > $FILE_DELETE.tmp
	echo "# Active branches to keep (reason within parenthesis)" > $FILE_KEEP.tmp
	sort -f $FILE_UNKNOWN >> $FILE_UNKNOWN.tmp && mv $FILE_UNKNOWN.tmp $FILE_UNKNOWN
	sort -f $FILE_DELETE >> $FILE_DELETE.tmp && mv $FILE_DELETE.tmp $FILE_DELETE
	sort -f $FILE_KEEP >> $FILE_KEEP.tmp && mv $FILE_KEEP.tmp $FILE_KEEP
	echo
	echo "Branches analyzed: $FILE_LIST"
	echo "Unrecognized branch name pattern: $FILE_UNKNOWN"
	echo "Branches to delete: $FILE_DELETE"
	echo "Active branches to keep: $FILE_KEEP"
}

perform() {
	branches=""
	while read line; do
		[[ $line =~ ^"#" ]] && continue
		branch=${line#* }
		branch=${branch#*origin/}
		branch=${branch%% *}
		branches+=" $branch"
	done < "$1"
	[ -z "$branches" ] && echo "Nothing to delete in file $1" && return
	git push --delete origin $branches
	git reflog expire --all --expire=now
	git gc --prune=now --aggressive
	echo "Nb branches after cleanup: $(git branch -r|wc -l)"
	echo "Nb commit objects after cleanup: $(git rev-list --objects --all|wc -l)"
	git count-objects -vH
}

test() {
	branch=$1
	echo ">> Get author..."
	set -x
	git log -1 --no-merges --grep="Merge branch '.*' from multiple repositories" --invert-grep --pretty=format:'%aE' $branch
	{ set +x; } 2>/dev/null

	echo -e "\n>> Extract JIRA reference..."
	set -x
	jira=$(echo "$branch" | awk -v jira_pattern="($JIRA_PROJECTS)-[0-9]+" 'match($0, jira_pattern) {print substr($0,RSTART,RLENGTH)}')
	{ set +x; } 2>/dev/null

	echo -e "\n>> Check JIRA reference exists (and is public), get its status and optional tags..."
	set -x
	curl -I -o /dev/null -w "%{http_code}\n" -s https://jira.nuxeo.com/rest/api/2/issue/$jira
	curl -s https://jira.nuxeo.com/rest/api/2/issue/$jira?fields=status|python -c 'import sys, json; print json.load(sys.stdin)["fields"]["status"]["id"]'
	curl -s https://jira.nuxeo.com/rest/api/2/issue/$jira?fields=customfield_10080|python -c 'import sys, json; print json.load(sys.stdin)["fields"]["customfield_10080"]'
	{ set +x; } 2>/dev/null
}

usage() {
	echo -ne "Analyze and delete deprecated remote branches based on their name, age and related JIRA issue.\n\
Usage: $(basename $0) <command>\n\
Commands:\n\
\thelp\n\
\tanalyze\n\
\t\tAnalyze the 'origin' remote in the current Git repository\n\
\tperform [<source file>]\n\
\t\tDelete remote branches listed in the given source file (defaults to $FILE_DELETE)\n\
\tfull\n\
\t\tAnalyze and delete\n\
\ttest <branch>\n\
\t\tTest analysis of the given branch\n"
}

if [ "$#" -eq 0 -o "$1" = "test" -a -z "$2" ]; then
	usage
	exit 1
elif [ "$1" = "help" ]; then
	usage
	exit 0
fi
[ -d .git ] || git rev-parse --git-dir >/dev/null 2>&1 || die "Not a Git repository"
git config remote.origin.url >/dev/null || die "No remote named 'origin'"
if [ "$1" = "analyze" ]; then
	analyze
elif [ "$1" = "full" ]; then
	analyze
	echo
	perform $FILE_DELETE
elif [ "$1" = "perform" ]; then
	if [ "$#" -eq 2 ]; then
		perform $2
	else
		perform $FILE_DELETE
	fi
elif [ "$1" = "test" ]; then
	test $2
else
	usage
	exit 1
fi
exit 0


