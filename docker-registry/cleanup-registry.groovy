/*
 * (C) Copyright 2020 Nuxeo (http://nuxeo.com/) and others.
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
 *     Antoine Taillefer <ataillefer@nuxeo.com>
 *     Julien Carsique <jcarsique@nuxeo.com>
 */

properties([
        [$class: 'GithubProjectProperty', projectUrlStr: 'https://github.com/nuxeo/integration-scripts/'],
        [$class: 'BuildDiscarderProperty', strategy: [$class: 'LogRotator', daysToKeepStr: '60', numToKeepStr: '60', artifactNumToKeepStr: '5']],
        disableConcurrentBuilds(),
])

pipeline {
    agent {
        label 'jenkins-jx-base'
    }
    triggers {
        cron('H H * * 6')
    }
    parameters {
        choice(name: 'KUBE_NS', choices: ['ai'], description: 'Kubernetes namespace hosting the registry')
        booleanParam(name: 'DELETE_CACHE', defaultValue: true, description: 'Delete cache repositories')
        string(name: 'PURGE_PATTERN', defaultValue: 'PR|feat|fix|task|master|sprint|SNAPSHOT|bump-regex-version|INSIGHT', description: 'Tags to delete')
        string(name: 'IMAGES', defaultValue: '', description: 'Fixed list of images. By default, all the images are analyzed.')
        booleanParam(name: 'DRY_RUN', defaultValue: false, description: 'Dry run mode if set.')
    }
    options {
        disableConcurrentBuilds()
        buildDiscarder(logRotator(daysToKeepStr: '60', numToKeepStr: '10', artifactNumToKeepStr: '3'))
        timeout(time: 3, unit: 'HOURS')
    }
    stages {
        stage('Clean Up Docker Registry') {
            steps {
                container('jx-base') {
                    withCredentials([string(credentialsId: 'github_token', variable: 'GITHUB_TOKEN')]) {
                        withEnv(["DELETE_CACHE=${params.DELETE_CACHE}", "IMAGES=${params.IMAGES}",
                                 "PURGE_PATTERN=${params.PURGE_PATTERN}", "KUBE_NS=${params.KUBE_NS}",
                                 "DRY_RUN=${params.DRY_RUN}"]) {
                            dir('docker-registry') {
                                sh 'if [[ $DELETE_CACHE = "true" ]]; then ./deleteCache.sh | tee deleteCache.out ; fi'
                                sh "./purge.sh $DELETE_CACHE | tee purge.out"
                            }
                        }
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'docker-registry/deleteCache.out, docker-registry/purge.*', allowEmptyArchive: true
                }
            }
        }
    }
}
