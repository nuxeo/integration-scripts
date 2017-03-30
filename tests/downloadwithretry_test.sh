#!/bin/bash

oneTimeSetUp() {

  echo "Initial test setUp..." >/dev/null

  # load the library containing downloadWithRetry to test it
  . ../integration-lib.sh > /dev/null

  outputDir="${__shunit_tmpDir}/output"

  mkdir -p "${outputDir}"

  stdout="${outputDir}/stdout"

  stderr="${outputDir}/stderr"

  dlDir="${__shunit_tmpDir}/dl"
  mkdir -p "${dlDir}"

  bigFileUrl="http://community.nuxeo.com/static/releases/nuxeo-8.10/nuxeo-8.10-vm-vbox.zip"
  bigFileName=${bigFileUrl##*/}
  smallFileUrl="http://community.nuxeo.com/static/releases/nuxeo-5.3.1/nuxeo-shell-5.3.1.zip"
  smallFileName=${smallFileUrl##*/}
  smallFileMD5Url="http://community.nuxeo.com/static/releases/nuxeo-5.3.1/nuxeo-shell-5.3.1.zip.md5"
  smallFileMD5Name=${smallFileMD5Url##*/}
}

killCURLProcesses() {
  # killing remaining curl processes in case of test failure
  local dlPID
  dlPID=$(pgrep curl)
  if [ -n "${dlPID}" ]; then
    kill -9 "${dlPID}"
  fi
}

oneTimeTearDown() {

  echo "Final test tearDown ..." #>/dev/null

  killCURLProcesses

  rm -rf ${outputDir}
  rm -rf ${dlDir}

}

setUp() {
  cd ${dlDir}
  rm -f ${bigFileName}
  rm -f ${smallFileName}
  rm -f ${smallFileMD5Name}
  killCURLProcesses
}

tearDown() {
  killCURLProcesses
}

function waitForProcessUp() {
  local PROCESS_NAME=$1
  local MAX_WAIT=$2
  local dlPID=$(pgrep ${PROCESS_NAME})
  local WAIT_COUNTER=0

  until [ -n "$dlPID" ]; do
    sleep 1
    WAIT_COUNTER=$((WAIT_COUNTER + 1))
    [ $WAIT_COUNTER -lt $MAX_WAIT ] || return 1
    dlPID=$(pgrep ${PROCESS_NAME})
  done

  echo ${dlPID}
  return 0
}

function waitForProcessDown() {
  local PROCESS_NAME=$1
  local MAX_WAIT=$2
  local dlPID=(pgrep ${PROCESS_NAME})
  local WAIT_COUNTER=0

  until [ -z "$dlPID" ]; do
    sleep 1
    WAIT_COUNTER=$((WAIT_COUNTER + 1))
    [ $WAIT_COUNTER -lt $MAX_WAIT ] || return 1
    dlPID=$(pgrep ${PROCESS_NAME})
  done

  echo ${dlPID}
  return 0
}

function killDownloadInLoop() {
  local MAX_TRIES=$1
  local DELAY=$2
  local dlPID

  for i in $(seq 1 ${MAX_TRIES}); do
    echo -ne "\t[Downloading ${bigFileName}] attempt ${i}/${MAX_TRIES}\n"
    sleep ${DELAY}
    dlPID=$(pgrep curl)
    assertEquals "curl should be running at least ${MAX_TRIES} times -> stopped when i=${i}" "0" "$?" || return 1
    assertTrue "no file was downloaded" "[ -f ${bigFileName} ]" || return 1
    kill -9 ${dlPID}
  done

  return 0
}

function killAndCheckDelay() {
  local DELAY=$1
  local dlPID

  echo -ne "\tChecking the delay is neither too short...\n"
  dlPID=$(waitForProcessUp curl 3)
  assertEquals "curl should be running before killing it" "0" "$?" || return 1
  kill ${dlPID}
  sleep $((DELAY - 1))
  echo -ne "\tNor too long...\n"
  dlPID=$(pgrep curl)
  assertNotEquals "curl should not be running before the wait period" "0" "$?" || return 1
  sleep 2
  echo -ne "\tChecking the download has ended...\n"
  dlPID=$(pgrep curl)
  assertEquals "curl should be running after the wait period" "0" "$?" || return 1

  return 0
}

testInvalidZeroCounter() {
  # fail "DISABLED" || return
  local EXPECTED_RETRIES=0
  local EXPECTED_DELAY=1
  local KILL_RETRIES=5
  local KILL_DELAY=$((EXPECTED_DELAY + 1))

  downloadWithRetry ${bigFileUrl} ${EXPECTED_RETRIES} ${EXPECTED_DELAY} 2>${stderr} 1>${stdout}&
  killDownloadInLoop ${KILL_RETRIES} ${KILL_DELAY} || return
  sleep ${KILL_DELAY}
  pgrep curl
  assertNotEquals "curl should not be running more than ${KILL_RETRIES} times" "0" "$?" || return
}

testInvalidNegativeCounter() {
  # fail "DISABLED" || return
  local EXPECTED_RETRIES="-5"
  local EXPECTED_DELAY=1
  local KILL_RETRIES=5
  local KILL_DELAY=$((EXPECTED_DELAY + 1))

  downloadWithRetry ${bigFileUrl} ${EXPECTED_RETRIES} ${EXPECTED_DELAY} 2>${stderr} 1>${stdout}&
  killDownloadInLoop ${KILL_RETRIES} ${KILL_DELAY} || return
  sleep ${KILL_DELAY}
  pgrep curl
  assertNotEquals "curl should not be running more than ${KILL_RETRIES} times" "0" "$?" || return
}

testDefaultCounter() {
  # fail "DISABLED" || return
  local EXPECTED_RETRIES=5
  local EXPECTED_DELAY=3
  local KILL_RETRIES=${EXPECTED_RETRIES}
  local KILL_DELAY=$((EXPECTED_DELAY + 1))

  downloadWithRetry ${bigFileUrl} 2>${stderr} 1>${stdout}&
  killDownloadInLoop ${KILL_RETRIES} ${KILL_DELAY} || return
  sleep ${KILL_DELAY}
  pgrep curl
  assertNotEquals "curl should not be running more than ${KILL_RETRIES} times" "0" "$?" || return
}

testValidCounter() {
  # fail "DISABLED" || return
  local EXPECTED_RETRIES=4
  local EXPECTED_DELAY=1
  local KILL_RETRIES=${EXPECTED_RETRIES}
  local KILL_DELAY=$((EXPECTED_DELAY + 1))

  downloadWithRetry ${bigFileUrl} ${EXPECTED_RETRIES} ${EXPECTED_DELAY}  2>${stderr} 1>${stdout}&
  killDownloadInLoop ${KILL_RETRIES} ${KILL_DELAY} || return
  sleep ${KILL_DELAY}
  pgrep curl
  assertNotEquals "curl should not be running more than ${KILL_RETRIES} times" "0" "$?" || return
}

testDefaultDelay() {
  # fail "DISABLED" || return
  local EXPECTED_RETRIES=2
  local EXPECTED_DELAY=3

  downloadWithRetry ${bigFileUrl} ${EXPECTED_RETRIES} 2>${stderr} 1>${stdout}&
  killAndCheckDelay ${EXPECTED_DELAY}
}

testSpecificDelay() {
  # fail "DISABLED" || return
  local EXPECTED_RETRIES=2
  local EXPECTED_DELAY=7

  downloadWithRetry ${bigFileUrl} ${EXPECTED_RETRIES} ${EXPECTED_DELAY} 2>${stderr} 1>${stdout}&
  killAndCheckDelay ${EXPECTED_DELAY}
}


testNegativeDelay() {
  # fail "DISABLED" || return
  local EXPECTED_RETRIES=2
  local EXPECTED_DELAY="-8"
  local KILL_DELAY=3

  downloadWithRetry ${bigFileUrl} ${EXPECTED_RETRIES} ${EXPECTED_DELAY} 2>${stderr} 1>${stdout}&
  killAndCheckDelay ${KILL_DELAY}
}

testZeroDelay() {
  # fail "DISABLED" || return
  local EXPECTED_RETRIES=2
  local EXPECTED_DELAY=0
  local KILL_DELAY=3

  downloadWithRetry ${bigFileUrl} ${EXPECTED_RETRIES} ${EXPECTED_DELAY} 2>${stderr} 1>${stdout}&
  killAndCheckDelay ${KILL_DELAY}
}

testHostUnreachable() {
  # fail "DISABLED" || return
  local EXPECTED_RETRIES=2
  local EXPECTED_DELAY=1
  local TARGET_URL="http://10.255.255.1/${bigFileName}"
  local DOWNLOAD_OUTPUT

  echo -ne "\tTrying to download ${TARGET_URL}...\n"
  echo -ne "\tThis test may take some time...\n"
  DOWNLOAD_OUTPUT=$(downloadWithRetry ${TARGET_URL} ${EXPECTED_RETRIES} ${EXPECTED_DELAY})
  assertEquals "incorrect result code" "1" "$?" || return
  echo "$DOWNLOAD_OUTPUT" | grep "FAILED: could not retrieve ${bigFileName}" | wc -l | grep "^\s*2\s*$" 2>${stderr} 1>${stdout}
  assertEquals "there should be ${EXPECTED_RETRIES} failed statements" "0" "$?" || return
  echo "$DOWNLOAD_OUTPUT" | grep "ERROR: could not retrieve ${TARGET_URL}" 2>${stderr} 1>${stdout}
  assertEquals "there should be an ERROR statement" "0" "$?" || return
}

testIfFileExists() {
  # fail "DISABLED" || return
  local DOWNLOAD_OUTPUT

  assertFalse "${smallFileName} should not exist" "[ -f ${smallFileName} ]" || return
  touch ${smallFileName}

  echo -ne "\tTrying to download ${smallFileName}...\n"
  DOWNLOAD_OUTPUT=$(downloadWithRetry ${smallFileUrl})
  assertEquals "incorrect result code" "2" "$?" || return
  echo "$DOWNLOAD_OUTPUT" | grep "ERROR: ${smallFileName} already exists." 2>${stderr} 1>${stdout}
  assertEquals "there should be an ERROR statement" "0" "$?" || return
}

testSuccessfulDownload() {
  # fail "DISABLED" || return
  local DOWNLOAD_OUTPUT

  assertFalse "${smallFileName} should not exist" "[ -f ${smallFileName} ]" || return
  assertFalse "${smallFileMD5Name} should not exist" "[ -f ${smallFileMD5Name} ]" || return

  echo -ne "\tTrying to download ${smallFileName}...\n"
  DOWNLOAD_OUTPUT=$(downloadWithRetry ${smallFileUrl})
  assertEquals "incorrect result code" "0" "$?" || return
  echo "$DOWNLOAD_OUTPUT" | sed '/^$/d' | wc -l | grep "^\s*0\s*$" 2>${stderr} 1>${stdout}
  assertEquals "there should be no output generated" "0" "$?" || return

  echo -ne "\tTrying to download ${smallFileMD5Name}...\n"
  DOWNLOAD_OUTPUT=$(downloadWithRetry ${smallFileMD5Url})
  assertEquals "incorrect result code" "0" "$?" || return
  echo "$DOWNLOAD_OUTPUT" | sed '/^$/d' | wc -l | grep "^\s*0\s*$" 2>${stderr} 1>${stdout}
  assertEquals "there should be no output generated" "0" "$?" || return

  echo -ne "\tChecking download integrity...\n"
  echo -ne "\t"
  md5sum -c ${smallFileMD5Name}
  assertEquals "incorrect result code" "0" "$?" || return
}

testSuccessfulRetriedDownload() {
  # fail "DISABLED" || return
  local dlPID
  local DOWNLOAD_OUTPUT

  assertFalse "${smallFileName} should not exist" "[ -f ${smallFileName} ]" || return
  assertFalse "${smallFileMD5Name} should not exist" "[ -f ${smallFileMD5Name} ]" || return

  echo -ne "\tTrying to download ${smallFileName}...\n"
  DOWNLOAD_OUTPUT=$(downloadWithRetry ${smallFileUrl} 2>${stderr} 1>${stdout}&)
  dlPID=$(waitForProcessUp curl 3)
  assertEquals "curl should be running" "0" "$?" || return
  echo -ne "\tCurl is runnning, killing it and waiting 2 seconds\n"
  kill -9 ${dlPID}
  sleep 2
  pgrep curl
  assertNotEquals "curl should not be running" "0" "$?" || return
  echo -ne "\tCurl is not runnning, waiting (60 seconds max) for download to finish...\n"
  sleep 2
  dlPID=$(waitForProcessDown curl 60)
  assertEquals "curl should have finished downloading" "0" "$?" || return

  echo -ne "\tTrying to download ${smallFileMD5Name}...\n"
  DOWNLOAD_OUTPUT=$(downloadWithRetry ${smallFileMD5Url})
  assertEquals "incorrect result code" "0" "$?" || return
  echo "$DOWNLOAD_OUTPUT" | sed '/^$/d' | wc -l | grep "^\s*0\s*$" 2>${stderr} 1>${stdout}
  assertEquals "there should be no output generated" "0" "$?" || return

  echo -ne "\tChecking download integrity...\n"
  echo -ne "\t"
  md5sum -c ${smallFileMD5Name}
  assertEquals "incorrect result code" "0" "$?" || return
}

. ${SHUNIT2_HOME}/shunit2
