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
  for (slave in Jenkins.instance.getNodes()) { // iterate on all slaves
    for (label in slave.getLabelString().split()) { // look for a known "static" label
      if ("STATIC".equalsIgnoreCase(label)) {
          if (slave.toComputer().isOnline() && slave.toComputer().isIdle()) {
              staticSlaves.add(slave.getDisplayName());
          } else {
              println 'Ignore unavailable slave ' + slave.getDisplayName()
          }
          break
      }
    }
  }

  timeout(time: 1, unit: 'HOURS') {
    timestamps {
      def isStartedByUser = currentBuild.rawBuild.getCause(Cause$UserIdCause) != null
      if (doConfirm || isStartedByUser) {
        input(message: "Are you wishing to update the following slaves?\n$staticSlaves")
      }
      stage('Execute') {
        sh """#!/bin/bash -xe
          for i in 1 2 3; do
            cd $WORKSPACE/qa-ovh-maintenance/qa-ovh0"\${i}"/
            ssh jenkins@qa-ovh0"\${i}".nuxeo.com "bash -s" < ../common/pull_images.sh
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
}

return this


