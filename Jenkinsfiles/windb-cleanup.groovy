#!groovy

/*
 * (C) Copyright 2018 Nuxeo http://nuxeo.com/ and others.
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
 *     atimic
 *
 * NXBT-2300 windb cleanup job
 * - Iterates through windb1 to windb8 in order to cleanup workspaces
 */

/**
  Executes a PowerShell command instead of native Batch and without the powershell pipeline step

  https://jenkins.io/doc/pipeline/steps/workflow-durable-task-step/#bat-windows-batch-script
  https://stackoverflow.com/a/42576572/515973
*/
def PowerShell(cmd) {
    cmd=cmd.replaceAll("%", "%%")
    bat '''
      powershell.exe -NonInteractive -Command "\$[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;
        $cmd;
        EXIT \$global:LastExitCode"
    '''
}

def axis = [];
for (slave in jenkins.model.Jenkins.instance.getNodes()) {
    if ((slave.getNodeName().contains('windb')) && (slave.toComputer().isOnline()) && (slave.getComputer().countBusy() == 0)) {
        axis += slave.getDisplayName();
    }
}
println(axis);
for (winnode in axis) {
    node("${winnode}") {
        timestamps {
            timeout(5) {
                PowerShell('set-executionpolicy unrestricted')
                PowerShell('Remove-Item C:\\m2\\repository\\org\\nuxeo -force -recurse')
                PowerShell('Remove-Item C:\\tmp -force -recurse')
                PowerShell('New-Item -ItemType directory C:\\tmp')
                PowerShell('Remove-Item C:\\Users\\jenkins\\AppData\\Local\\temp -force -recurse')
                PowerShell('New-Item -ItemType directory C:\\Users\\jenkins\\AppData\\Local\\temp')
            }
        }
    }
}

