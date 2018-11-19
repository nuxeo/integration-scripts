/*
 * (C) Copyright 2018 Nuxeo (http://nuxeo.com/) and others.
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
 * - atimic
 * - jcarsique
 *
 * QA OVH
 */

node('master') {
  checkout scm
  def externalMethod = load("qa-ovh-maintenance/update_static_slaves.groovy")
  externalMethod.update_static_slaves()

  withCredentials([string(credentialsId: 'update_static_slaves', variable: 'QA2_TOKEN')]) {
    sh """
      curl -I -X POST "https://qa2.nuxeo.org/jenkins/job/System/job/update_static_slaves/build?token=${QA2_TOKEN}"
    """
  }
}