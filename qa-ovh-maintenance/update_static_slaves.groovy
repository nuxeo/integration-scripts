/*
 * (C) Copyright 2018 Nuxeo (http://nuxeo.com/) and others.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Contributors:
 * - atimic
 * - jcarsique
 *
 * QA OVH
 */

import hudson.model.Cause;
import jenkins.model.Jenkins;

def update_static_slaves(boolean doConfirm=false) {

  // Get All static slaves
  def staticSlaves = [];
  def offlineIdleSlaves = [];
  def onlineBusySlaves = [];
  def availableSlaves = [];
  for (slave in Jenkins.instance.getNodes()) { // iterate on all slaves
    if (slave.toComputer().getConnectTime() > 0) {
      for (label in slave.getLabelString().split()) { // look for a known "static" label
        if ("STATIC".equalsIgnoreCase(label)) {
          availableSlaves.add(slave.getDisplayName());
          staticSlaves.add(slave);
          println("adding " + slave.getDisplayName() + " to availableSlaves");
        }
      }
    }
  }
  // Check if those slaves are outdated | if yes, write slave name to result.txt
  sh """ #!bin/bash -xe
  rm -f result.txt
  for i in 1 2 3; do
    cd $WORKSPACE/qa-ovh-maintenance/qa-ovh0"\${i}"/
    ssh jenkins@qa-ovh0"\${i}".nuxeo.com "bash -s" < ../common/pull_images.sh
    ssh jenkins@qa-ovh0"\${i}".nuxeo.com "bash -s" < ./start_remote.sh
    ssh jenkins@qa-ovh0"\${i}".nuxeo.com "bash -s" < ./start_remote_priv.sh
  done
  for slave in ${availableSlaves}; do
    slave=\${slave/[/} && slave=\${slave/]/} && slave=\${slave/,/}
    echo "\$slave"
    . ../common/swarm_check.sh \${slave}
    if [ \${retval} -eq 1 ]; then
      echo "\${slave} must be updated";
      echo "\$slave" >> ../../result.txt
    else
      echo "\$slave is already up to date";
    fi;
  done
  """
  // if all slaves are up to date, finish build on success
  resultExist = fileExists 'result.txt'
  if (resultExist == false) {
    println("All slaves are up to date .... Exiting ....");
    currentBuild.result = 'SUCCESS'
    return
  }
  // Compare and create new array filled with outdated static slaves
  availableSlaves = []
  results = readFile('result.txt'.trim()).readLines();
  println("Fichier results.txt : " + results)
  for (slaveToUpdate in results) {
      for (slave in staticSlaves) {
        if (slaveToUpdate == slave.getDisplayName()) {
            availableSlaves.add(slave);
        }
      }
  }
  println("New array filled with with slave to be updated : " + availableSlaves)
  // Parse and output slaves depending of their states
  staticSlaves = [];
  for (slave in availableSlaves) {
          if (slave.toComputer().isOffline()) {
            if (slave.toComputer().isIdle()) {
              offlineIdleSlaves.add(slave.getDisplayName());
              staticSlaves.add(slave.getDisplayName());
            }
          }
          if (slave.toComputer().isOnline() && !slave.toComputer().isIdle()) {
            slave.toComputer().setTemporarilyOffline(true, new hudson.slaves.OfflineCause.ByCLI("Slave update planned"));
            onlineBusySlaves.add(slave.getDisplayName());
          }
          if (slave.toComputer().isOnline() && slave.toComputer().isIdle()) {
            slave.toComputer().setTemporarilyOffline(true, new hudson.slaves.OfflineCause.ByCLI("Slave update planned"));
            staticSlaves.add(slave.getDisplayName());
          }
          if (slave.getDisplayName() in staticSlaves == false && slave.getDisplayName() in offlineIdleSlaves == false && slave.getDisplayName() in onlineBusySlaves == false)  {
            println 'Ignore unavailable slave ' + slave.getDisplayName();
          }
        }

  timeout(time: 1, unit: 'HOURS') {
    timestamps {
      def isStartedByUser = currentBuild.rawBuild.getCause(Cause$UserIdCause) != null
      println("List of offline outdated idle slaves\n" + offlineIdleSlaves + "\n")
      println("List of online outdated busy slaves\n" + onlineBusySlaves + "\nThose one will be set offline once build finish")
      println("List of needeed slaves update\n" + staticSlaves + "\n")
      if (doConfirm || isStartedByUser) {
        input(message: "Are you wishing to update the following slaves?\n$staticSlaves $offlineIdleSlaves")
      }
      stage('Execute') {
        sh """#!/bin/bash -xe
          for i in 1 2 3; do
            cd $WORKSPACE/qa-ovh-maintenance/qa-ovh0"\${i}"/
            for slave in ${staticSlaves}; do
              slave=\${slave/[/} && slave=\${slave/]/} && slave=\${slave/,/}
              echo "\$slave"
              ssh jenkins@qa-ovh0"\${i}".nuxeo.com "bash -s -- \${slave}" < ../common/kill_remote.sh
            done
            ssh jenkins@qa-ovh0"\${i}".nuxeo.com "bash -s" < ./start_remote.sh
            ssh jenkins@qa-ovh0"\${i}".nuxeo.com "bash -s" < ./start_remote_priv.sh
          done
        """
      }
    }
  }
  // trigger this job again if we have set slaves offline
  if (onlineBusySlaves.size() > 0) {
    build job: 'update_static_slaves', propagate: false, quietPeriod: 3600
  }
}

return this
