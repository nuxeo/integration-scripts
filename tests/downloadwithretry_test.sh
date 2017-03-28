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

function killDownloadInLoop() {
  local L_MAX_TRIES=$1
  local L_DELAY=$2

  for i in $(seq 1 ${L_MAX_TRIES}); do
    echo -ne "\t[Downloading ${bigFileName}] attempt ${i}/${L_MAX_TRIES}\n"
    sleep ${L_DELAY}
    dlPID=$(pgrep curl)
    assertEquals "curl should be running at least ${L_MAX_TRIES} times -> stopped when i=${i}" "0" "$?" || return 1
    assertTrue "no file was downloaded" "[ -f ${bigFileName} ]" || return 1
    kill -9 ${dlPID}
  done

  return 0
}

function killAndCheckDelay() {
  local L_DELAY=$1

  echo -ne "\tChecking the delay is neither too short...\n"
  dlPID=$(pgrep curl)
  assertEquals "curl should be running before killing it" "0" "$?" || return 1
  kill ${dlPID}
  sleep $((L_DELAY - 1))
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
#  fail "DISABLED" || return
  local L_EXPECTED_RETRIES=0
  local L_EXPECTED_DELAY=1
  local L_KILL_RETRIES=5
  local L_KILL_DELAY=$((L_EXPECTED_DELAY + 1))

  downloadWithRetry ${bigFileUrl} ${L_EXPECTED_RETRIES} ${L_EXPECTED_DELAY} 2>${stderr} 1>${stdout}&
  killDownloadInLoop ${L_KILL_RETRIES} ${L_KILL_DELAY} || return
  sleep ${L_KILL_DELAY}
  pgrep curl
  assertNotEquals "curl should not be running more than ${L_KILL_RETRIES} times" "0" "$?" || return
}

testInvalidNegativeCounter() {
#  fail "DISABLED" || return
  local L_EXPECTED_RETRIES="-5"
  local L_EXPECTED_DELAY=1
  local L_KILL_RETRIES=5
  local L_KILL_DELAY=$((L_EXPECTED_DELAY + 1))

  downloadWithRetry ${bigFileUrl} ${L_EXPECTED_RETRIES} ${L_EXPECTED_DELAY} 2>${stderr} 1>${stdout}&
  killDownloadInLoop ${L_KILL_RETRIES} ${L_KILL_DELAY} || return
  sleep ${L_KILL_DELAY}
  pgrep curl
  assertNotEquals "curl should not be running more than ${L_KILL_RETRIES} times" "0" "$?" || return
}

testDefaultCounter() {
#  fail "DISABLED" || return
  local L_EXPECTED_RETRIES=5
  local L_EXPECTED_DELAY=3
  local L_KILL_RETRIES=${L_EXPECTED_RETRIES}
  local L_KILL_DELAY=$((L_EXPECTED_DELAY + 1))

  downloadWithRetry ${bigFileUrl} 2>${stderr} 1>${stdout}&
  killDownloadInLoop ${L_KILL_RETRIES} ${L_KILL_DELAY} || return
  sleep ${L_KILL_DELAY}
  pgrep curl
  assertNotEquals "curl should not be running more than ${L_KILL_RETRIES} times" "0" "$?" || return
}

testValidCounter() {
#  fail "DISABLED" || return
  local L_EXPECTED_RETRIES=4
  local L_EXPECTED_DELAY=1
  local L_KILL_RETRIES=${L_EXPECTED_RETRIES}
  local L_KILL_DELAY=$((L_EXPECTED_DELAY + 1))

  downloadWithRetry ${bigFileUrl} ${L_EXPECTED_RETRIES} ${L_EXPECTED_DELAY}  2>${stderr} 1>${stdout}&
  killDownloadInLoop ${L_KILL_RETRIES} ${L_KILL_DELAY} || return
  sleep ${L_KILL_DELAY}
  pgrep curl
  assertNotEquals "curl should not be running more than ${L_KILL_RETRIES} times" "0" "$?" || return
}

testDefaultDelay() {
#  fail "DISABLED" || return
  local L_EXPECTED_RETRIES=2
  local L_EXPECTED_DELAY=3

  downloadWithRetry ${bigFileUrl} ${L_EXPECTED_RETRIES} 2>${stderr} 1>${stdout}&
  killAndCheckDelay ${L_EXPECTED_DELAY}
}

testSpecificDelay() {
#  fail "DISABLED" || return
  local L_EXPECTED_RETRIES=2
  local L_EXPECTED_DELAY=7

  downloadWithRetry ${bigFileUrl} ${L_EXPECTED_RETRIES} ${L_EXPECTED_DELAY} 2>${stderr} 1>${stdout}&
  killAndCheckDelay ${L_EXPECTED_DELAY}
}


testNegativeDelay() {
#  fail "DISABLED" || return
  local L_EXPECTED_RETRIES=2
  local L_EXPECTED_DELAY="-8"
  local L_KILL_DELAY=3

  downloadWithRetry ${bigFileUrl} ${L_EXPECTED_RETRIES} ${L_EXPECTED_DELAY} 2>${stderr} 1>${stdout}&
  killAndCheckDelay ${L_KILL_DELAY}
}

testZeroDelay() {
#  fail "DISABLED" || return
  local L_EXPECTED_RETRIES=2
  local L_EXPECTED_DELAY=0
  local L_KILL_DELAY=3

  downloadWithRetry ${bigFileUrl} ${L_EXPECTED_RETRIES} ${L_EXPECTED_DELAY} 2>${stderr} 1>${stdout}&
  killAndCheckDelay ${L_KILL_DELAY}
}

testHostUnreachable() {
#  fail "DISABLED" || return
  local L_EXPECTED_RETRIES=2
  local L_EXPECTED_DELAY=1
  local L_TARGET_URL="http://10.255.255.1/${bigFileName}"

  echo -ne "\tTrying to download ${L_TARGET_URL}...\n"
  echo -ne "\tThis test may take some time...\n"
  DL_OUT=$(downloadWithRetry ${L_TARGET_URL} ${L_EXPECTED_RETRIES} ${L_EXPECTED_DELAY})
  assertEquals "incorrect result code" "1" "$?" || return
  echo "$DL_OUT" | grep "FAILED: could not retrieve ${bigFileName}" | wc -l | grep "^\s*2\s*$" 2>${stderr} 1>${stdout}
  assertEquals "there should be ${L_EXPECTED_RETRIES} failed statements" "0" "$?" || return
  echo "$DL_OUT" | grep "ERROR: could not retrieve ${L_TARGET_URL}" 2>${stderr} 1>${stdout}
  assertEquals "there should be an ERROR statement" "0" "$?" || return
}

testIfFileExists() {
#  fail "DISABLED" || return
  local L_EXPECTED_RETRIES=1
  local L_EXPECTED_DELAY=1

  assertFalse "${smallFileName} should not exist" "[ -f ${smallFileName} ]" || return
  touch ${smallFileName}

  echo -ne "\tTrying to download ${smallFileName}...\n"
  DL_OUT=$(downloadWithRetry ${smallFileUrl})
  assertEquals "incorrect result code" "2" "$?" || return
  echo "$DL_OUT" | grep "ERROR: ${smallFileName} already exists." 2>${stderr} 1>${stdout}
  assertEquals "there should be an ERROR statement" "0" "$?" || return
}

testSuccessfulDownload() {
#  fail "DISABLED" || return
  assertFalse "${smallFileName} should not exist" "[ -f ${smallFileName} ]" || return
  assertFalse "${smallFileMD5Name} should not exist" "[ -f ${smallFileMD5Name} ]" || return

  echo -ne "\tTrying to download ${smallFileName}...\n"
  DL_OUT=$(downloadWithRetry ${smallFileUrl})
  assertEquals "incorrect result code" "0" "$?" || return
  echo "$DL_OUT" | sed '/^$/d' | wc -l | grep "^\s*0\s*$" 2>${stderr} 1>${stdout}
  assertEquals "there should be no output generated" "0" "$?" || return

  echo -ne "\tTrying to download ${smallFileMD5Name}...\n"
  DL_OUT=$(downloadWithRetry ${smallFileMD5Url})
  assertEquals "incorrect result code" "0" "$?" || return
  echo "$DL_OUT" | sed '/^$/d' | wc -l | grep "^\s*0\s*$" 2>${stderr} 1>${stdout}
  assertEquals "there should be no output generated" "0" "$?" || return

  echo -ne "\tChecking download integrity...\n"
  echo -ne "\t"
  md5sum -c ${smallFileMD5Name}
  assertEquals "incorrect result code" "0" "$?" || return
}

testSuccessfulRetriedDownload() {
  # fail "DISABLED" || return
  assertFalse "${smallFileName} should not exist" "[ -f ${smallFileName} ]" || return
  assertFalse "${smallFileMD5Name} should not exist" "[ -f ${smallFileMD5Name} ]" || return

  echo -ne "\tTrying to download ${smallFileName}...\n"
  DL_OUT=$(downloadWithRetry ${smallFileUrl} 2>${stderr} 1>${stdout}&)
  dlPID=$(pgrep curl)
  assertEquals "curl should be running" "0" "$?" || return
  echo -ne "\tCurl is runnning, killing it and waiting 2 seconds\n"
  kill -9 ${dlPID}
  sleep 2
  pgrep curl
  assertNotEquals "curl should not be running" "0" "$?" || return
  echo -ne "\tCurl is not runnning, waiting 10 seconds for download to finish...\n"
  sleep 10
  pgrep curl
  assertNotEquals "curl should have finished downloading" "0" "$?" || return

  echo -ne "\tTrying to download ${smallFileMD5Name}...\n"
  DL_OUT=$(downloadWithRetry ${smallFileMD5Url})
  assertEquals "incorrect result code" "0" "$?" || return
  echo "$DL_OUT" | sed '/^$/d' | wc -l | grep "^\s*0\s*$" 2>${stderr} 1>${stdout}
  assertEquals "there should be no output generated" "0" "$?" || return

  echo -ne "\tChecking download integrity...\n"
  echo -ne "\t"
  md5sum -c ${smallFileMD5Name}
  assertEquals "incorrect result code" "0" "$?" || return
}

. ${SHUNIT2_HOME}/shunit2
