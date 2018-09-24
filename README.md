# integration-scripts

Scripts to manage tools used for integration automation.

---

# `download.sh`

## Usage

Utility script for downloading a distribution.

Other related scripts:
- `upload.sh` used by /Deploy/IT-nuxeo-master-tests-cap-tomcat

## QA

Used in jobs like:
- /Deploy/IT-nuxeo-master-tests-cap-tomcat
- /Deploy/IT-nuxeo-master-tests-cap-tomcat-sqlserver
- /Deploy/IT-nuxeo-master-tests-cap-tomcat-postgresql
- /Deploy/IT-nuxeo-master-tests-cap-tomcat-mysql
- /Deploy/IT-nuxeo-master-tests-cap-tomcat-jre
- /Deploy/IT-nuxeo-master-tests-cap-tomcat-sqlserver2014
- /Deploy/IT-nuxeo-master-tests-cap-tomcat-mariadb
- /Deploy/IT-release-on-demand-tests-cap-tomcat
- /Deploy/IT-nuxeo-master-tests-cap-tomcat-mongodb
- /Deploy/IT-nuxeo-master-tests-cap-tomcat-oracle12

---

# `fix_zip.sh`

## Usage

Refines the released distribution: repackage, fix details, finalize for easy-use out of the box.

## QA

/Deploy/IT-release-on-demand-build
/Deploy/IT-release-nuxeo.io
/Deploy/IT-nuxeo-9.10-build
/Deploy/IT-nuxeo-10.1-build
/Deploy/IT-nuxeo-master-build

---

# `git-branches-cleanup.sh`

## Usage

[QA/System/git-branches-cleanup](https://qa.nuxeo.org/jenkins/job/System/job/git-branches-cleanup/) job runs
`git-branches-cleanup.sh` following [CORG/Git Usage](https://doc.nuxeo.com/corg/git-usage/#main-rules-and-good-practices).

The principle is to delete Git branches older than 3 months and which JIRA ticket is resolved or closed, and with no `backport-*` tag.
In case of doubt, the branch is kept forever.

## QA

https://qa.nuxeo.org/jenkins/job/System/job/git-branches-cleanup/

## Resources (Documentation and other links)

https://jira.nuxeo.com/browse/NXBT-736?jql=text%20~%20%22git-branches-cleanup%22%20and%20project%20%3D%20NXBT%20and%20component%20%3D%20%22Nuxeo%20Scripts%22

---

# `integration-lib.sh`, `integration-dblib.sh`, `package-all-distributions.sh`

## Usage

DEPRECATED. Server management and related CI tooling.

---

# `jenkins_workspace_cleanup.sh`

## Usage

Various WS cleanup tricks.

https://jira.nuxeo.com/browse/NXBT-1915

---

# `marketplace.ini`

## Usage

Platform repositories consolidation: lists the repositories to be assembled along with the Platform, in completion to the main structure and the addons.
Those repositories contain code for building a Nuxeo Package or a Nuxeo Plugin (= package + addon).

It is mainly used by the Git and release tooling.

---

# `nexus-sync.sh`

## Usage

Synchronizes local caches for network optimization.

## QA

https://qa.nuxeo.org/jenkins/job/Deploy/job/nexus-sync-snapshots/
https://qa.nuxeo.org/jenkins/job/Deploy/job/nexus-sync-releases/

---

# `ondemand-testandpush-metrics.py`

## Usage

Used by T&P jobs to generate metrics.

## QA

https://qa.nuxeo.org/jenkins/job/System/job/ondemand-testandpush-metrics/

---

# `upgrade_homebrew.sh`

TODO

---

# `qa-ovh-maintenance`

```qa-ovh-maintenance/
├── qa.groovy                           // Development [QA](https://qa.nuxeo.org/jenkins/)
├── qa2.groovy                          // Maintenance [QA2](https://qa2.nuxeo.org/jenkins/)
├── update_static_slaves.groovy         // main update script
├── common
│   ├── jenkins_workspace_cleanup.sh
│   ├── kill_remote.sh
│   └── pull_images.sh
├── qa-ovh01                            // Host qa-ovh01
│   ├── manual                          // Legacy local maintenance scripts
│   ├── start_remote_priv.sh
│   └── start_remote.sh
├── qa-ovh02                            // Host qa-ovh02
│   ├── manual                          // Legacy local maintenance scripts
│   ├── start_remote_priv.sh
│   └── start_remote.sh
└── qa-ovh03                            // Host qa-ovh03
    ├── manual                          // Legacy local maintenance scripts
    ├── start_remote_priv.sh
    └── start_remote.sh
```

## Workspace cleanup

`jenkins_workspace_cleanup.sh` Cleanup Jenkins hosts, Docker and workspaces:
- Prune stopped images
- Prune stopped volumes
- Delete "exited" containers
- Delete T&P jobs older than 3 days
- Delete Nuxeo server ZIP files and unzipped folders older than 3 days
- Remove Git repositories parent folders older than 5 days
- Remove Git repositories parent folders older than 2 days and bigger than 100M
- Remove files that the Workspace Cleanup plugin has no permission to delete (NXBT-2205, JENKINS-24824)

## Static slave maintenance

[/System/update_static_slaves](https://qa.nuxeo.org/jenkins/job/System/job/update_static_slaves/) is triggered by [/System/build-slave-images](https://qa.nuxeo.org/jenkins/job/System/job/build-slave-images/) and co

Fetch "static" slaves list by label from Jenkins masters [QA](https://qa.nuxeo.org/jenkins/), [QA2](https://qa2.nuxeo.org/jenkins/).

Works on *idle* and *online* slaves labelled *`STATIC`*.

`update_static_slaves.groovy` will `pull_images.sh` and `kill_remotes.sh` static slaves then `start_remote.sh` and `start_remote_priv`.

See [getLabelsBySlaves.groovy](https://qa.nuxeo.org/jenkins/scriptler/runScript?id=getLabelsBySlaves.groovy) for the extraction of existing labels.

## List of static Slaves

Naming convention is not yet enforced but tends to pattern like `prefix[n]-<host>[-<ID>]` to interprete as:
- `[n]`: if dedicated to `qa<n>.nuxeo.org` instead of default `qa.nuxeo.org`
- `<host>`: the Docker host within the Docker swarm, ie `qa-ovh01.nuxeo.com`, `qa-ovh02.nuxeo.com`...
- `[-<ID>]`: increment when there are multiple instance with the same name

```
$ docker -H tcp://swarm-qa.nuxeo.org:4000 ps -a --format "table {{.Names}}\t{{.Ports}}\t{{.Image}}"|sort
NAMES                                  PORTS                          IMAGE
qa-ovh01/itslave01           51.254.42.78:2301->22/tcp      dockerpriv.nuxeo.com:443/nuxeo/jenkins-it
qa-ovh01/itslavepriv01       51.254.42.78:3401->22/tcp      dockerpriv.nuxeo.com:443/nuxeo/jenkins-itpriv
qa-ovh01/matrix01            51.254.42.78:2302->22/tcp      dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave
qa-ovh01/priv-01-1           51.254.42.78:3311->22/tcp      dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
qa-ovh01/priv-01-2           51.254.42.78:3312->22/tcp      dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
qa-ovh01/priv2-01-1          51.254.42.78:4401->22/tcp      dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
qa-ovh01/static01            51.254.42.78:2201->22/tcp      dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave

qa-ovh02/itslave710          51.254.197.210:2301->22/tcp    dockerpriv.nuxeo.com:443/nuxeo/jenkins-it-7.10
qa-ovh02/itslave810          51.254.197.210:2303->22/tcp    dockerpriv.nuxeo.com:443/nuxeo/jenkins-it-8.10
qa-ovh02/itslave910          51.254.197.210:2304->22/tcp    dockerpriv.nuxeo.com:443/nuxeo/jenkins-it-9.10
qa-ovh02/matrix02            51.254.197.210:2302->22/tcp    dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave
qa-ovh02/priv-02-1           51.254.197.210:3301->22/tcp    dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
qa-ovh02/priv-02-2           51.254.197.210:3302->22/tcp    dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
qa-ovh02/priv2-02-1          51.254.197.210:4401->22/tcp    dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
qa-ovh02/slavepriv2-710-1    51.254.197.210:5501->22/tcp    dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv-7.10
qa-ovh02/slavepriv2-810-1    51.254.197.210:5601->22/tcp    dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv-8.10
qa-ovh02/slavepriv2-910-1    51.254.197.210:5701->22/tcp    dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv-9.10
qa-ovh02/static710           51.254.197.210:2201->22/tcp    dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave-7.10
qa-ovh02/static810           51.254.197.210:2202->22/tcp    dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave-8.10
qa-ovh02/static910           51.254.197.210:2203->22/tcp    dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave-9.10

qa-ovh03/itslave03           151.80.31.37:2301->22/tcp      dockerpriv.nuxeo.com:443/nuxeo/jenkins-it
qa-ovh03/itslavepriv03       151.80.31.37:3401->22/tcp      dockerpriv.nuxeo.com:443/nuxeo/jenkins-itpriv
qa-ovh03/matrix03            151.80.31.37:2302->22/tcp      dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave
qa-ovh03/priv-03-1           151.80.31.37:3301->22/tcp      dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
qa-ovh03/priv-03-2           151.80.31.37:3302->22/tcp      dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
qa-ovh03/priv2-03-1          151.80.31.37:4401->22/tcp      dockerpriv.nuxeo.com:443/nuxeo/jenkins-slavepriv
qa-ovh03/static03            151.80.31.37:2201->22/tcp      dockerpriv.nuxeo.com:443/nuxeo/jenkins-slave
```

---

# `Jenkinsfiles/IT-release-on-demand-packages.groovy`

TODO

---

# `Jenkinsfiles/windb-cleanup.groovy`

TODO

---

# Release tooling

```release/
├── jenkins_perform.sh
├── jenkins_release.sh
└── post-release-new-jobs.sh
```

TODO

---
---

# `script`

## Usage

## QA

## Resources (Documentation and other links)

---

# DOC TODO

bower_deploy

build-and-bench, build-and-test

---
---

# Contributing / Reporting issues

https://jira.nuxeo.com/browse/NXBT/component/11326
https://jira.nuxeo.com/secure/CreateIssue!default.jspa?project=NXBT

# License

[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)

# About Nuxeo

The [Nuxeo Platform](http://www.nuxeo.com/products/content-management-platform/) is an open source customizable and extensible content management platform for building business applications. It provides the foundation for developing [document management](http://www.nuxeo.com/solutions/document-management/), [digital asset management](http://www.nuxeo.com/solutions/digital-asset-management/), [case management application](http://www.nuxeo.com/solutions/case-management/) and [knowledge management](http://www.nuxeo.com/solutions/advanced-knowledge-base/). You can easily add features using ready-to-use addons or by extending the platform using its extension point system.

The Nuxeo Platform is developed and supported by Nuxeo, with contributions from the community.

Nuxeo dramatically improves how content-based applications are built, managed and deployed, making customers more agile, innovative and successful. Nuxeo provides a next generation, enterprise ready platform for building traditional and cutting-edge content oriented applications. Combining a powerful application development environment with
SaaS-based tools and a modular architecture, the Nuxeo Platform and Products provide clear business value to some of the most recognizable brands including Verizon, Electronic Arts, Sharp, FICO, the U.S. Navy, and Boeing. Nuxeo is headquartered in New York and Paris.
More information is available at [www.nuxeo.com](http://www.nuxeo.com).
