#!/bin/bash +xe
#
# (C) Copyright 2015-2016 Nuxeo SA (http://nuxeo.com/) and others.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Contributors:
#     Theo Davidovits
#     Julien Carsique
#
# NXBT-736: cleanup deprecated branches

JIRA_PROJECTS=${JIRA_PROJECTS:-"NXP|NXBT|APG|NXDRIVE|NXROADMAP|NXS|NXMOB|NXDOC"}
PATTERNS=${PATTERNS:-'^origin/master$
 ^origin/stable$
 ^origin/[0-9]+(\.[0-9]+)+-SNAPSHOT$
 ^origin/[0-9]+(\.[0-9]+)+-HF[0-9]+-SNAPSHOT$
 ^origin/[0-9]+(\.[0-9]+)+$
 5.4.2-I20110404_0115'}
DEPRECATED_PATTERNS=${DEPRECATED_PATTERNS:-'^origin/5\.[0-7](\.[0-9])*$
 ^origin/5\.9\..*$
 ^origin/[1-7](\.[0-9]+)+-SNAPSHOT$'}

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
  touch $FILE_UNKNOWN $FILE_DELETE $FILE_KEEP

  git fetch --prune
  complete=`git ls-remote --heads -q origin|cut -f 2|sed "s,refs/heads,origin,g"`
  nb_complete=`echo $complete|wc -w`

  echo "Nb branches before cleanup: $nb_complete"
  #	git reflog expire --all --expire=now
  #	git gc --prune=now --aggressive
  echo "Nb commit objects before cleanup: $(git rev-list --objects --all|wc -l)"
  git count-objects -vH

  echo "Looking for branches older than 3 days and which JIRA issue is resolved or closed, and with no 'backport-*' tag..."
  count=0
  for branch in $complete; do
    count=$(( $count + 1 ))
    printf "\r\e[K(%3d/%d) Analyzing branch %s ..." $count $nb_complete $branch
    echo "$branch" >> $FILE_LIST
    for pattern in $DEPRECATED_PATTERNS; do
      if [[ $branch =~ $pattern ]]; then
        printf "%-20s\t%-80s\t%s\n" "system" $branch "(deprecated pattern '$pattern')" >> $FILE_DELETE
        continue 2
      fi
    done
    for pattern in $PATTERNS; do
      if [[ $branch =~ $pattern ]]; then
        printf "%-20s\t%-80s\t%s\n" "system" $branch "(pattern '$pattern')" >> $FILE_KEEP
        continue 2
      fi
    done

    if $INVERT_GREP; then
      author=$(git log -1 --no-merges --grep="Merge branch '.*' from multiple repositories" --invert-grep --pretty=format:'%aE' $branch)
    else
      author=$(git log -20 --format=%H $branch | grep -v -f <(git log -20 --format=%H "--grep=Merge branch '.*' from multiple repositories" $branch) | git log -1 --pretty=format:'%aE' --stdin --no-walk)
    fi
    if [ -z "$(git log -1 --since='3 days ago' --oneline $branch)" ]; then
      jira=$(echo "$branch" | awk -v jira_pattern="($JIRA_PROJECTS)-[0-9]+" 'match(toupper($0), jira_pattern) {print substr($0,RSTART,RLENGTH)}')
      if [ -z "$jira" ]; then
        printf "%-20s\t%-80s\t%s\n" $author $branch "(unknown pattern)" >> $FILE_UNKNOWN
        continue
      fi
      # Check JIRA ref exists
      rc=$(curl -u $USER:$PASS -I -o /dev/null -w "%{http_code}" -s https://jira.nuxeo.com/rest/api/2/issue/$jira)
      if [ $rc -ne 200 ]; then
        printf "%-20s\t%-80s\t%s\t%s\n" $author $branch "($jira does not exist)" "http_code:$rc" >> $FILE_UNKNOWN
        continue
      fi
        status=$(curl -u $USER:$PASS -s https://jira.nuxeo.com/rest/api/2/issue/$jira?fields=status|python -c 'import sys, json; print json.load(sys.stdin)["fields"]["status"]["id"]')
        tags=$(curl -u $USER:$PASS -s https://jira.nuxeo.com/rest/api/2/issue/$jira?fields=customfield_10080|python -c 'import sys, json; print json.load(sys.stdin)["fields"]["customfield_10080"]')
      if (echo "$tags"|grep -q 'backport-'); then
        printf "%-20s\t%-80s\t%s\n" $author $branch "($jira has a backport tag)" >> $FILE_KEEP
      elif [ $status -eq 5 -o $status -eq 6 ]; then
        printf "%-20s\t%-80s\t%s\n" $author $branch "($jira is resolved)" >> $FILE_DELETE
      else
        printf "%-20s\t%-80s\t%s\n" $author $branch "($jira not resolved)" >> $FILE_KEEP
      fi
    else
      printf "%-20s\t%-80s\t%s\n" $author $branch "(<3 days)" >> $FILE_KEEP
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
    branch=$(echo $line|tr "\t" " ")
    branch=${branch#* }
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
  if $INVERT_GREP; then
    git log -1 --no-merges --grep="Merge branch '.*' from multiple repositories" --invert-grep --pretty=format:'%aE' $branch
  else
    git log -20 --format=%H $branch | grep -v -f <(git log -20 --format=%H "--grep=Merge branch '.*' from multiple repositories" $branch) | git log -1 --pretty=format:'%aE' --stdin --no-walk
  fi
  { set +x; } 2>/dev/null

  echo -e "\n>> Extract JIRA reference..."
  set -x
  jira=$(echo "$branch" | awk -v jira_pattern="($JIRA_PROJECTS)-[0-9]+" 'match(toupper($0), jira_pattern) {print substr($0,RSTART,RLENGTH)}')
  if [ -z "$jira" ]; then
    printf "%-20s\t%-80s\t%s\n" $author $branch "(unknown pattern)" >> $FILE_UNKNOWN
    return
  fi
  { set +x; } 2>/dev/null
  echo -e "\n>> Check JIRA reference '$jira' exists (and is public), get its status and optional tags..."
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
\t\tTest analysis of the given branch\n\
Environment variables:\n\
\tJIRA_PROJECTS\n\
\t\tJIRA project refs (pipe-separated; ie: "NXP\|NXBT").\n\
\tPATTERNS\n\
\t\tRegEx patterns of branches to keep.\n\
\tDEPRECATED_PATTERNS\n\
\t\tRegEx deprecated patterns of branches to delete.\n"
}

info() {
  echo ---
  echo "Working on $PWD"
  echo JIRA_PROJECTS=$JIRA_PROJECTS
  echo PATTERNS=$PATTERNS
  echo DEPRECATED_PATTERNS=$DEPRECATED_PATTERNS
  echo ---
}

if [ "$#" -eq 0 -o "$1" = "test" -a -z "$2" ]; then
  usage
  info
  exit 1
elif [ "$1" = "help" ]; then
  usage
  info
  exit 0
fi
[ -d .git ] || git rev-parse --git-dir >/dev/null 2>&1 || die "Not a Git repository"
git config remote.origin.url >/dev/null || die "No remote named 'origin'"
git help log |grep 'invert-grep' >/dev/null 2>&1 && INVERT_GREP=true || INVERT_GREP=false
if ! $INVERT_GREP ; then
  echo "You should upgrade Git!"
fi

info
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
