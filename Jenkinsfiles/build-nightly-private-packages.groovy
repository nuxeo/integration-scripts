@Library('nuxeo')
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
        def repository, nodeLabel

        def releaseJob = Jenkins.instance.getItemByFullName("Deploy/IT-nuxeo-${params.BRANCH}-build") ?
                "Deploy/IT-nuxeo-${params.BRANCH}-build" : "Deploy/IT-nuxeo-master-build"

        withCredentials([usernamePassword(
                credentialsId: 'eea4e470-2c5e-468f-ab3a-e6c81fde94c0',
                passwordVariable: 'GITHUB_PASSWD',
                usernameVariable: 'GITHUB_TOKEN')]) {

            repository = GithubUtils.getRepositoryFromBlob(env.MARKETPLACE_INI, env.GITHUB_TOKEN, env.GITHUB_PASSWD)

            nodeLabel = repository.isPrivate?'IT_PRIV':'IT'

            node(nodeLabel) {
                env.JAVA_HOME="${tool 'java-8-oracle'}"
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
                                    [$class: 'WipeWorkspace'],
                                    [$class: 'CloneOption', depth: 1, noTags: false, reference: '', shallow: false, timeout: 60],
                                    [$class: 'CheckoutOption', timeout: 60]
                            ],
                            userRemoteConfigs: [[url: 'git@github.com:nuxeo/nuxeo.git']]
                    ])
                    step([
                            $class: 'CopyArtifact',
                            filter: 'nuxeo/marketplace/release.ini',
                            flatten: true,
                            fingerprintArtifacts: true,
                            projectName: releaseBuild.projectName,
                            selector: [$class: 'SpecificBuildSelector', buildNumber: releaseBuild.buildNumber]
                    ])
                    sh('curl -u $GITHUB_TOKEN:$GITHUB_PASSWD -H "Accept: application/vnd.github.v3.raw" -o packages.ini $MARKETPLACE_INI?ref=' +
                            GithubUtils.checkForBranch(repository.owner, repository.name, params.BRANCH, env.GITHUB_TOKEN, env.GITHUB_PASSWD, 'master'))
                }
                stage('clone packages') {
                    dir('nuxeo') {
                        sh """#!/bin/bash -ex
                            ./scripts/release_mp.py clone -m file://$WORKSPACE/packages.ini
                        """
                    }
                }
                stage('prepare packages') {
                    sh """#!/usr/bin/env python
import ConfigParser

print 'Input: ${env.WORKSPACE}/packages.ini'
print 'Input: ${env.WORKSPACE}/release.ini'
print 'Output: ${env.WORKSPACE}/merge.ini'

packages = ConfigParser.SafeConfigParser()
packages.read('${env.WORKSPACE}/packages.ini')

merge = ConfigParser.SafeConfigParser()
merge.read('${env.WORKSPACE}/packages.ini')

release = ConfigParser.SafeConfigParser()
release.read('${env.WORKSPACE}/release.ini')

with open('${env.WORKSPACE}/merge.ini', 'w') as dest_conf:
    for key, value in release.items('DEFAULT', True):
        value = packages.get('DEFAULT', key, True) if packages.has_option('DEFAULT', key) else value
        merge.set('DEFAULT', key, value)
    merge.write(dest_conf)

print 'Done'
                    """
                    withCredentials([file(credentialsId: 'NETRC_RELEASE', variable: 'NETRC_FILE')]) {
                        withEnv(["NETRC_FILE_BAK=.netrc.bak-${BUILD_TAG}"]) {
                            dir('nuxeo/marketplace') {
                                try {
                                    sh '''#!/bin/bash -ex
                                        mv ~/.netrc ~/"${NETRC_FILE_BAK}" || true
                                        mv ${NETRC_FILE} ~/.netrc
                                        ../scripts/release_mp.py prepare -m file://$WORKSPACE/merge.ini
                                    '''
                                } finally {
                                    sh '''#!/bin/bash -ex
                                        mv ~/"${NETRC_FILE_BAK}" ~/.netrc || rm ~/.netrc
                                    '''
                                }
                            }
                        }
                    }
                }
                stage('check') {
                    dir('nuxeo/marketplace') {
                        sh """#!/bin/bash -ex
                            . ../scripts/gitfunctions.sh
                            gitf show -s --pretty=format:'%h%d'
                            for release in release-*; do echo \$release: ; cat \$release ; echo ; done
                            grep -C5 'skip = Failed' release.ini || true
                            grep uploaded release.ini
                        """
                    }
                }

                stash name: 'prepared_sources', includes: 'nuxeo/marketplace/**/*', useDefaultExcludes: false
                stash name: 'packages_ini', includes: 'packages.ini, release.ini, merge.ini'
                stash name: 'release_log', includes: 'release-nuxeo.log, nuxeo/marketplace/release*'
            }
        }
        checkpoint 'prepared'
    }
}
