@Library('nuxeo@fix-NXP-23257-release-private-packages')
import org.nuxeo.ci.jenkins.pipeline.GithubUtils

class ReleaseBuild implements Serializable {
    def projectName
    def buildNumber

    ReleaseBuild(def releaseBuild) {
        projectName = releaseBuild.project.fullName
        buildNumber = releaseBuild.number as String
    }
}

timestamps {
    timeout(300) {
        def releaseJob
        if (params.RELEASE_TYPE == "release") {
            releaseJob = "IT-release-on-demand-build"
        } else {
            releaseJob = Jenkins.instance.getItemByFullName("Deploy/IT-nuxeo-${params.BRANCH}-build") ?
                    "Deploy/IT-nuxeo-${params.BRANCH}-build" : "Deploy/IT-nuxeo-master-build"
        }
        def repository
        def nodeLabel

        withCredentials([usernamePassword(
                credentialsId: 'eea4e470-2c5e-468f-ab3a-e6c81fde94c0',
                passwordVariable: 'GITHUB_PASSWD',
                usernameVariable: 'GITHUB_TOKEN')]) {

            repository = GithubUtils.getRepositoryFromBlob(env.MARKETPLACE_INI, env.GITHUB_TOKEN, env.GITHUB_PASSWD)

            nodeLabel = repository.isPrivate?'IT_PRIV':'IT'

            node(nodeLabel) {
                stage('clone') {
                    def releaseBuild = new ReleaseBuild(input(message: 'Select the distribution to release against:', parameters: [
                            [$class: 'RunParameterDefinition', filter: 'SUCCESSFUL', name: 'RELEASE_BUILD', projectName: releaseJob]
                    ]))
                    checkout([
                            $class: 'GitSCM',
                            branches: [[name: GithubUtils.checkForBranch('nuxeo', 'nuxeo', params.BRANCH, env.GITHUB_TOKEN, env.GITHUB_PASSWD, 'master')]],
                            browser: [$class: 'GithubWeb', repoUrl: 'https://github.com/nuxeo/nuxeo'],
                            extensions: [
                                    [$class: 'RelativeTargetDirectory', relativeTargetDir: 'nuxeo'],
                                    [$class: 'PerBuildTag'],
                                    [$class: 'WipeWorkspace'],
                                    [$class: 'CloneOption', depth: 1, noTags: false, reference: '', shallow: false, timeout: 60],
                                    [$class: 'CheckoutOption', timeout: 60]
                            ],
                            userRemoteConfigs: [[url: 'git@github.com:nuxeo/nuxeo.git']]
                    ])
                    step([
                            $class: 'CopyArtifact',
                            filter: 'release-nuxeo.log',
                            fingerprintArtifacts: true,
                            projectName: releaseBuild.projectName,
                            selector: [$class: 'SpecificBuildSelector', buildNumber: releaseBuild.buildNumber]
                    ])
                    sh('curl -n -H "Accept: application/vnd.github.v3.raw" -o packages.ini $MARKETPLACE_INI?ref=' +
                            GithubUtils.checkForBranch(repository.owner, repository.name, params.BRANCH, env.GITHUB_TOKEN, env.GITHUB_PASSWD, 'master'))
                }
                stage('clone packages') {
                    dir('nuxeo') {
                        sh """#!/bin/bash -ex
                    ./scripts/release_mp.py clone -m file://$WORKSPACE/packages.ini -d $WORKSPACE/release-nuxeo.log
                    """
                    }
                }
                stage('prepare packages') {
                    dir('nuxeo/marketplace') {
                        sh """#!/bin/bash -ex
                    ../scripts/release_mp.py prepare
                    """
                    }
                }
                stage('check') {
                    dir('nuxeo/marketplace') {
                        sh """#!/bin/bash -ex
                    . ../scripts/gitfunctions.sh
                    gitf show -s --pretty=format:'%h%d'
                    for release in release-*; do echo \$release: ; cat \$release ; echo ; done
                    grep -C5 'skip = Failed' release.ini || true
                    grep uploaded release.ini"""
                    }
                }

                stash name: 'prepared_sources', includes: 'nuxeo/marketplace/**/*', useDefaultExcludes: false
                stash name: 'packages_ini', includes: 'packages.ini'
                stash name: 'release_log', includes: 'release-nuxeo.log, nuxeo/marketplace/release*'
            }
        }
        checkpoint 'prepared'
        stage('perform') {
            def doPerform = input message: 'Do you want to Perform Marketplace Packages ?', parameters: [
                    [$class: 'ChoiceParameterDefinition', choices: '''No
                Yes''', name: 'DO_PERFORM']
            ]

            if('Yes' == doPerform.trim()) {
                node(nodeLabel) {
                    checkout([
                            $class: 'GitSCM',
                            branches: [[name: GithubUtils.checkForBranch('nuxeo', 'nuxeo', params.BRANCH, env.GITHUB_TOKEN, env.GITHUB_PASSWD, 'master')]],
                            browser: [$class: 'GithubWeb', repoUrl: 'https://github.com/nuxeo/nuxeo'],
                            extensions: [
                                    [$class: 'RelativeTargetDirectory', relativeTargetDir: 'nuxeo'],
                                    [$class: 'PerBuildTag'],
                                    [$class: 'WipeWorkspace'],
                                    [$class: 'CloneOption', depth: 1, noTags: false, reference: '', shallow: false, timeout: 60],
                                    [$class: 'CheckoutOption', timeout: 60]
                            ],
                            userRemoteConfigs: [[url: 'git@github.com:nuxeo/nuxeo.git']]
                    ])

                    unstash 'prepared_sources'
                    unstash 'packages_ini'
                    unstash 'release_log'

                    dir('nuxeo/marketplace') {
                        sh """#!/bin/bash -ex
                            ../scripts/release_mp.py perform
                            grep -C5 'Fail' release.ini || true
                            grep uploaded release.ini
                            """
                    }
                }
            }
        }
    }
}
