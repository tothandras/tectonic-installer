/* Tips
1. Keep stages focused on producing one artifact or achieving one goal. This makes stages easier to parallelize or re-structure later.
1. Stages should simply invoke a make target or a self-contained script. Do not write testing logic in this Jenkinsfile.
3. CoreOS does not ship with `make`, so Docker builds still have to use small scripts.
*/
pipeline {
  agent any
  options {
    timeout(time:35, unit:'MINUTES')
    buildDiscarder(logRotator(numToKeepStr:'20'))
  }

  stages {
    stage('TerraForm: Syntax Check') {
        agent {
            docker {
              image 'quay.io/coreos/tectonic-builder:v1.7'
              label 'worker'
            }
        }
      steps {
        sh """#!/bin/bash -ex
        make structure-check
        """
      }
    }

    stage('Installer: Build & Test') {
      agent {
          docker {
            image 'quay.io/dan_gillespie/tectonic-builder:v1'
            label 'worker'
          }
      }
      environment {
        GO_PROJECT = '/go/src/github.com/coreos/tectonic-installer'
      }
      steps {
        sh "mkdir -p ${WORKSPACE}/installer/bin/linux"
        sh "cp /go/installer/bin/linux/installer ${WORKSPACE}/installer/bin/linux/installer"
        stash name: 'installer', includes: 'installer/bin/linux/installer'
        }
      }
      stage("Smoke Tests") {
      agent none
      steps {
        parallel (
          "Bare Metal": {
            node('bare-metal') {
              withCredentials([file(credentialsId: 'tectonic-license', variable: 'TF_VAR_tectonic_pull_secret_path'),
                               file(credentialsId: 'tectonic-pull', variable: 'TF_VAR_tectonic_license_path')
                          ]) {
                checkout scm
                unstash 'installer'
                sh '''
                  #!/bin/bash -e

                  export PLATFORM=metal
                  export CLUSTER="tf-${PLATFORM}-${BRANCH_NAME}-${BUILD_ID}"
                  export INSTALLER_PATH=${WORKSPACE}/installer/bin/linux/installer

                  sed "s|<PATH_TO_INSTALLER>|$INSTALLER_PATH|g" terraformrc.example > .terraformrc
                  export TERRAFORM_CONFIG=${WORKSPACE}/.terraformrc

                  # Create local config
                  make localconfig

                  ln -sf ${WORKSPACE}/test/metal.tfvars ${WORKSPACE}/build/${CLUSTER}/terraform.tfvars

                  make plan

                  # lowercase cluster names
                  export TF_VAR_tectonic_cluster_name=$(echo ${CLUSTER} | awk '{print tolower($0)}')
                  cd installer

                  ./tests/scripts/bare-metal/up-down.sh
                '''
              }
            }
          }
        )
      }
    }
  }
}
