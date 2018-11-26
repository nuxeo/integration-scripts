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
  def staticSlaves = [];
  def offlineIdleSlaves = [];
  def onlineBusySlaves = [];
  for (slave in Jenkins.instance.getNodes()) { // iterate on all slaves
    if (slave.toComputer().getConnectTime() > 0) {
      for (label in slave.getLabelString().split()) { // look for a known "static" label
        if ("STATIC".equalsIgnoreCase(label)) {
          if (slave.toComputer().isOffline()) {
            if (slave.toComputer().isIdle()) {
              offlineIdleSlaves.add(slave.getDisplayName());
              staticSlaves.add(slave.getDisplayName());
            }
          }
          if (slave.toComputer().isOnline() && slave.toComputer().countBusy() > 0) {
            slave.toComputer().setTemporarilyOffline(true, new hudson.slaves.OfflineCause.ByCLI("Slave update planned"));
            onlineBusySlaves.add(slave.getDisplayName());
          }
          if (slave.toComputer().isOnline() && slave.toComputer().isIdle()) {
            staticSlaves.add(slave.getDisplayName());
          }
          if (slave.getDisplayName() in staticSlaves == false && slave.getDisplayName() in offlineIdleSlaves == false && slave.getDisplayName() in onlineBusySlaves == false)  {
            println 'Ignore unavailable slave ' + slave.getDisplayName();
          }
          break
        }
      }
    }
  }


  timeout(time: 1, unit: 'HOURS') {
    timestamps {
      def isStartedByUser = currentBuild.rawBuild.getCause(Cause$UserIdCause) != null
      println("List of offline idle slaves\n" + offlineIdleSlaves + "\n")
      println("List of online busy slaves\n" + onlineBusySlaves + "\nThose one will be set offline once build finish")
      println("List of needeed slaves update\n" + staticSlaves + "\n")
      if (doConfirm || isStartedByUser) {
        input(message: "Are you wishing to update the following slaves?\n$staticSlaves \n$offlineIdleSlaves")
      }
      stage('Execute') {
        sh """#!/bin/bash -xe
          for i in 1 2 3; do
            cd $WORKSPACE/qa-ovh-maintenance/qa-ovh0"\${i}"/
            ssh jenkins@qa-ovh0"\${i}".nuxeo.com "bash -s" < ../common/pull_images.sh
            for slave in ${staticSlaves}; do
              slave=\${slave/[/} && slave=\${slave/]/} && slave=\${slave/,/}
              echo "\$slave"
              ssh jenkins@qa-ovh0"\${i}".nuxeo.com "bash -s -- \${slave}" < ../common/uptodate_check.sh
            done
            ssh jenkins@qa-ovh0"\${i}".nuxeo.com "bash -s" < ./start_remote.sh
            ssh jenkins@qa-ovh0"\${i}".nuxeo.com "bash -s" < ./start_remote_priv.sh
          done
        """
      }
    }
  }
}

return this


