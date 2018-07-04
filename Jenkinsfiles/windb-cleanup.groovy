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
 *     atimic, jcarsique
 *
 * NXBT-2300 windb cleanup job. It iterates idle 'windb' slaves to delete:
 * - Nuxeo Maven artifacts
 * - temporary folders and files
 */

def winNodes = [];
for (aNode in jenkins.model.Jenkins.instance.getNodes()) {
   if ((aNode.getNodeName().contains('windb')) && (aNode.toComputer().isOnline()) && (aNode.toComputer().countBusy() == 0)) {
       winNodes += aNode.getDisplayName();
    }
}
println("Cleaning $winNodes...");

for (winNode in winNodes) {
    node("${winNode}") {
        timestamps {
            timeout(5) {
                sh """#!/bin/bash -xe
                    rm -rvf C:/m2/repository/org/nuxeo
                    rm -rvf C:/tmp
                    mkdir c:/tmp
                    rm -rvf C:/Users/jenkins/AppData/Local/temp
                    mkdir C:/Users/jenkins/AppData/Local/temp
                """
            }
        }
    }
}

