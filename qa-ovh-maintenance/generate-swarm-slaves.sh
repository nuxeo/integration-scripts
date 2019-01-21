#!/bin/bash

#opts="-e JENKINS_API_TOKEN=token -e JENKINS_USERNAME=username"
username=$1
token=$2

launch() {
    local host=$1; shift
    local image=dockerpriv.nuxeo.com:443/nuxeo/jenkins-$1; shift
    local name=$1; shift
    local  labels=$1; shift
    local opts="$opts -H $host run --restart always --privileged -itd -e JENKINS_USERNAME=$username -e JENKINS_API_TOKEN=$token"
    for label in $labels; do
        opts="$opts -l $label";
    done
    version=$(docker -H $host inspect $image --format {{.ContainerConfig.Labels.version}})
    name=${version}-${name}
    opts="$opts --name ${name}"
    opts="$opts -e JENKINS_NAME=${name}"
    opts="$opts -e JENKINS_LABELS='${labels}'"
    opts="$opts -e JENKINS_MASTER=https://qa.nuxeo.org/jenkins"
    opts="$opts -w /opt/jenkins"
    opts="$opts -v /var/run/docker.sock:/var/run/docker.sock:rw -v /opt/jenkins/workspace:/opt/jenkins/workspace:rw"
    echo docker $opts $image
}

for i in 0 1 2 3 4 5 6 7 8 9; do 
    #launch tcp://qa-ovh-tools.nuxeo.com:4000 slave-swarm  swarm-multidb-$i "swarm MULTIDB_LINUX" $opts
    launch tcp://swarm-qa.nuxeo.org:4000 slave-swarm swarm-pub-$i "swarm SLAVE DYNAMIC" $opts
    #launch tcp://swarm-qa.nuxeo.org:4000 slavepriv-swarm swarm-priv-$i "swarm SLAVEPRIV DYNAMIC" $opts
done
