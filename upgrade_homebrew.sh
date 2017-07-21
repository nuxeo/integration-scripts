#!/bin/bash -x

HOMEBREW_FOLDER="homebrew"
HOMEBREW_REPOSITORY="nuxeo/homebrew-core"
HOMEBREW_ORIGINAL="Homebrew/homebrew-core"
VERSION_REGEX="^[0-9]{1,2}\.[0-9]{1,2}(\.[0-9]{1,2})?$"
SHA256_REGEX="^[A-Fa-f0-9]{64}$"
TMP_DIR=/tmp

set -e

function log {
  echo "[INFO] $*"
}

function err {
  >&2 echo "[ERROR] $*"
}

function show_help {
  echo "Usage: $0 [<Nuxeo Version>]"
}

# Prepare homebrew repository
if [ -d $HOMEBREW_FOLDER ]; then
  cd $HOMEBREW_FOLDER

  if [ `git status --porcelain | wc -l` -gt 0 ]; then
    log "Repository contains changes. Clean it before running script."
    exit 1;
  fi
  log "Syncing with $HOMEBREW_REPOSITORY:master..."
  git checkout master
  git pull --rebase
else
  log "Cloning $HOMEBREW_REPOSITORY:master..."
  git clone git@github.com:$HOMEBREW_REPOSITORY.git $HOMEBREW_FOLDER
  cd $HOMEBREW_FOLDER
fi

# Sync upstream if needed
if [ `git remote -v | grep upstream | wc -l` -le 0 ]; then
  log "Adding remote upstream repository..."
  git remote add upstream https://github.com/$HOMEBREW_ORIGINAL.git
fi

log "Fetching & Merge upstream..."
# git fetch upstream
git fetch --all
git merge upstream/master

git diff origin/master master --quiet || {
  log "Pushing to remote/origin"
  git push origin master
}

# If no args passed; exit silently.
if [ $# -lt 1 ]; then
  exit 0
fi

if ! [[ $1 =~ $VERSION_REGEX ]]; then
  err "Version is not in the correct pattern (7.10 for instance)."
  show_help
  exit 1
fi
NUXEO_VERSION=$1
ZIP_NAME="nuxeo-server-$NUXEO_VERSION-tomcat.zip"
ZIP_URL="https://cdn.nuxeo.com/nuxeo-$NUXEO_VERSION/$ZIP_NAME"
SHA256_URL="$ZIP_URL.sha256"

cd $TMP_DIR
if ! [ -f $ZIP_NAME ]; then
  log "Downloading zip..."
  curl -f -q -O $ZIP_URL
fi
log "Checking zip SHA256..."
curl -s -f $SHA256_URL -O
shasum -c $ZIP_NAME.sha256 || {
  err "Corrupted download file. Remove it manually: $TMP_DIR/$ZIP_NAME"
  exit 2
}
SHA256=`cat $ZIP_NAME.sha256 | cut -d' ' -f1`
cd -

# Do not work on master
BRANCH_NAME=upgrade-$NUXEO_VERSION
git branch -qD $BRANCH_NAME 2>/dev/null || true
git checkout -b $BRANCH_NAME

# Regex on Formula/nuxeo.rb
NUXEO_FORMULA="`pwd`/Formula/nuxeo.rb"
# Update versions + SHA256
sed -E -e "s|^([[:space:]]*)url \"https://cdn.nuxeo.com/nuxeo.+$|\1url \"$ZIP_URL\"|g" -i '' $NUXEO_FORMULA
sed -E -e "s|^([[:space:]]*)sha256 \"[A-Fa-f0-9]{64}\"$|\1sha256 \"$SHA256\"|g" -i '' $NUXEO_FORMULA
sed -E -e "s|^([[:space:]]*)version \"[0-9]{1,2}\..+\"$|\1version \"$NUXEO_VERSION\"|g" -i '' $NUXEO_FORMULA
sed -E -e '/^  revision [0-9]+/ d' -i '' $NUXEO_FORMULA

# Log changes
log "Git diff:"
git diff

# Execute tests with local brew (OSX needed)
BREW="/usr/local/bin/brew"
$BREW uninstall nuxeo 2>/dev/null || true
log "Install Nuxeo pre-release formula"
$BREW install --verbose --debug $NUXEO_FORMULA
log "Test installed Nuxeo formula"
$BREW test $NUXEO_FORMULA
$BREW audit --strict --online nuxeo
log "Uninstall Nuxeo"
$BREW uninstall nuxeo

log "Tests OK: Commit and Push."
git commit -am "nuxeo: Upgrade version to $NUXEO_VERSION"
git push --set-upstream origin $BRANCH_NAME

# Create PR
CONTENT_TYPE="Content-Type: application/json; charset=utf-8"
AUTHORIZATION="Authorization: token $GITHUB_TOKEN"

log "Checking no existing pull request on nuxeo"
(curl -f -v -H "$CONTENT_TYPE" -n https://api.github.com/repos/$HOMEBREW_ORIGINAL/pulls | grep -B5 -i "\"title\": .*nuxeo" && {
  err "There is an opened pull request with nuxeo. Manual check needed."
  exit 4
}) || true;

log "Submit Homebrew/homebrew pull request"
PR_TITLE="nuxeo $NUXEO_VERSION"
PR_BODY="Update nuxeo formula to upgrade to version $NUXEO_VERSION."
PR_HEAD="nuxeo:$BRANCH_NAME"
PR_BASE="master"
PR_DATA="{\"title\": \"$PR_TITLE\", \"body\": \"$PR_BODY\", \"head\": \"$PR_HEAD\", \"base\": \"$PR_BASE\"}"
curl -v -H "$CONTENT_TYPE" -H "$AUTHORIZATION" -n -d "$PR_DATA" https://api.github.com/repos/$HOMEBREW_ORIGINAL/pulls
