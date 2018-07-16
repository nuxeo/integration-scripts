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
qa-ovh-maintenance
├── Jenkinsfile_qa
├── Jenkinsfile_qa2
├── qa-ovh01
│   ├── kill_remote.sh
│   ├── pull_images.sh
│   ├── start_remote_priv.sh
│   └── start_remote.sh
├── qa-ovh02
│   ├── jenkins_workspace_cleanup.sh
│   ├── kill_privslaves.sh
│   ├── kill_remote.sh
│   ├── kill_slaves.sh
│   ├── pull_images.sh
│   ├── start_priv_slaves.sh
│   ├── start_remote_priv.sh
│   ├── start_remote.sh
│   └── start_slaves.sh
└── qa-ovh03
    ├── jenkins_workspace_cleanup.sh
    ├── kill_privslaves.sh
    ├── kill_remote.sh
    ├── kill_slaves.sh
    ├── pull_images.sh
    ├── start_priv_slaves.sh
    ├── start_remote_priv.sh
    ├── start_remote.sh
    └── start_slaves.sh

Retrieve static slaves by label on jenkins masters and verify that they are idling and online.
It then runs `pull_images.sh` to retrieve latest slaves docker images, match the previous slaves we
got by label against the static slaves running on jenkins masters and kill them one by one
with `kill_remotes.sh` script. `start_remote.sh` and `start_remote_priv.sh` are then launched to
instantiate the new docker images.
```

TODO

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
