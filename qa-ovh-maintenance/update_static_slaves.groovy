import hudson.model.Cause;
import jenkins.model.Jenkins;

def update_static_slaves(boolean doConfirm=false) {
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
  sh """ #!bin/bash -x
  rm -f result.txt
  for i in 1 2 3; do
    cd $WORKSPACE/qa-ovh-maintenance/qa-ovh0"\${i}"/
    for slave in ${availableSlaves}; do
      slave=\${slave/[/} && slave=\${slave/]/} && slave=\${slave/,/}
      echo "\$slave"
      ssh jenkins@qa-ovh0"\${i}".nuxeo.com "bash -s -- \${slave}" < . ../common/check.sh
      if [ \$? -eq 1 ]; then
        echo "\${slave} must be updated";
        echo "\$slave" >> ../../result.txt
      else
        echo "\$slave is already up to date";
      fi;
    done
    echo "\$slave" >> ../../result.txt
  done
  """
  /*
  resultExist = fileExists 'result.txt'
  if (resultExist == false) {
    currentBuild.result = 'SUCCESS'
    return
  }
  */
  availableSlaves = []
  results = readFile ('result.txt'.trim());
  result = results.readLines();
  //println("\n\n\n" + results);
  for (validatedSlave in result) {
      for (slave in staticSlaves) {
        if (validatedSlave == slave.getDisplayName()) {
            availableSlaves.add(slave);
        }
      }
  }
  staticSlaves = [];
  availableSlaves.unique();
  println(availableSlaves);
  for (slave in availableSlaves) {
          if (slave.toComputer().isOffline()) {
            if (slave.toComputer().isIdle()) {
              // Upgrade
              offlineIdleSlaves.add(slave.getDisplayName());
              staticSlaves.add(slave.getDisplayName());
            }
          }
          if (slave.toComputer().isOnline() && slave.toComputer().countBusy() > 0) {
            //slave.toComputer().setTemporarilyOffline(true, new hudson.slaves.OfflineCause.ByCLI("Slave update planned"));
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

  timeout(time: 1, unit: 'HOURS') {
    timestamps {
      def isStartedByUser = currentBuild.rawBuild.getCause(Cause$UserIdCause) != null
      println("List of offline idle slaves\n" + offlineIdleSlaves + "\n")
      println("List of online busy slaves\n" + onlineBusySlaves + "\nThose one will be set offline once build finish")
      println("List of needeed slaves update\n" + staticSlaves + "\n")
      if (doConfirm || isStartedByUser) {
        input(message: "Are you wishing to update the following slaves?\n$staticSlaves $offlineIdleSlaves")
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
  // if (offlineIdleSlaves.size() > 0) {
    //  build job: 'update_static_slaves', propagate: false, quietPeriod: 3600
  //}
}

return this
