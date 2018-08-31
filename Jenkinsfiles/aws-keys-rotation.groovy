#!/usr/bin/env groovy

import com.cloudbees.jenkins.plugins.awscredentials.AWSCredentialsImpl;
import com.cloudbees.plugins.credentials.domains.*;

@NonCPS
def rotateKeys() {
    // Load all the AWSCredentials from Jenkins
    def creds = com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(
        com.cloudbees.jenkins.plugins.awscredentials.AWSCredentialsImpl.class,
        jenkins.model.Jenkins.instance
    )
    // Create a map of AccessKey to Credentials attached to this accessKeys
    def rotate = [:]
    // Building the map
    creds.each {
        if (!rotate[it.accessKey]) {
            rotate[it.accessKey] = []
        }
        rotate[it.accessKey].add(it)
    }
    // For each accessKey
    rotate.each {
       // Rotate the access key
        accessKey = it.value[0].accessKey
        secret = it.value[0].secretKey.getPlainText()
        withEnv(["AWS_ACCESS_KEY_ID=${accessKey}","AWS_SECRET_ACCESS_KEY=${secret}"]) {
            newKeyRaw = sh(returnStdout: true, script: "aws iam create-access-key").trim()
            newKey = readJSON(text: newKeyRaw)
            sh(script: "aws iam delete-access-key --access-key-id=${accessKey}")
            println("Rotate key ${accessKey} to ${newKey.AccessKey.AccessKeyId}")
        }
        // Now that the accessKey has been rotated on AWS, we need to update all credentials using it
        def credentials_store = jenkins.model.Jenkins.instance.getExtensionList(
            'com.cloudbees.plugins.credentials.SystemCredentialsProvider'
            )[0].getStore()
        it.value.each {
            cred = it
            domain = null
            // Search domain for this credentials : not optimal
            credentials_store.getDomains().each {
                curDomain = it
                credentials_store.getCredentials(it).each {
                    if (it == cred) {
                        domain = curDomain
                    }
                }
            }
            if (curDomain) {
                newIt = new AWSCredentialsImpl(it.scope, it.id, newKey.AccessKey.AccessKeyId, newKey.AccessKey.SecretAccessKey, it.description, it.iamRoleArn, it.iamMfaSerialNumber)
                credentials_store.updateCredentials(curDomain, it, newIt)
            } else {
                println("WARNING: key ${it.id} (${it.AccessKey} failed to be update with ${newKey.AccessKey.AccessKeyId}")
            }
        }
    }
}

node('SLAVE') {
    rotateKeys()
}
