class ReleaseBuild implements Serializable {
    def projectName
    def buildNumber

    ReleaseBuild(def releaseBuild) {
        projectName = releaseBuild.project.fullName
        buildNumber = releaseBuild.number as String
    }
}

@NonCPS
String checkForBranch(String owner, String repository, String branch, String fallback = 'master') {
    withCredentials([usernamePassword(credentialsId: 'eea4e470-2c5e-468f-ab3a-e6c81fde94c0', passwordVariable: 'GITHUB_PASSWD', usernameVariable: 'GITHUB_TOKEN')]) {
        def connection = (HttpURLConnection) "https://api.github.com/repos/${owner}/${repository}/branches/${branch}".toURL().openConnection()
        connection.setRequestProperty('Authorization', "${env.GITHUB_TOKEN}:${env.GITHUB_PASSWD}")

        switch(connection.responseCode) {
            case HttpURLConnection.HTTP_OK:
                return branch
            default:
                return fallback
        }
    }
}

timestamps {
    timeout(300) {
        def releaseJob = "Deploy/" + (params.RELEASE_TYPE == "release" ? "IT-release-on-demand-build" : "IT-nuxeo-master-build")

        node('SLAVE') {
            stage('clone') {
                def releaseBuild = new ReleaseBuild(input(message: 'Select the distribution to release against:', parameters: [
                        [$class: 'RunParameterDefinition', filter: 'SUCCESSFUL', name: 'RELEASE_BUILD', projectName: releaseJob]
                ]))
                checkout([
                        $class: 'GitSCM',
                        branches: [[name: checkForBranch('nuxeo', 'nuxeo', params.BRANCH, 'master')]],
                        browser: [$class: 'GithubWeb', repoUrl: 'https://github.com/nuxeo/nuxeo'],
                        extensions: [
                                [$class: 'RelativeTargetDirectory', relativeTargetDir: 'nuxeo'],
                                [$class: 'PerBuildTag'],
                                [$class: 'WipeWorkspace'],
                                [$class: 'CloneOption', depth: 0, noTags: false, reference: '', shallow: false, timeout: 60],
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
                        checkForBranch('nuxeo', 'nuxeo', params.BRANCH, 'master'))
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
        }
        checkpoint 'prepared'
        stage('perform') {
            def doPerform = input message: 'Do you want to Perform Marketplace Packages ?', parameters: [
                    [$class: 'ChoiceParameterDefinition', choices: '''No
                Yes''', name: 'DO_PERFORM']
            ]

            if('Yes' == doPerform.trim()) {
                node('SLAVE') {
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
