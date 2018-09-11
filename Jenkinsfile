pipeline {
  agent any
  stages {
    stage('Clone') {
      steps {
        git url: 'git@github.com:mulesoft/docs-site-antora',
            branch: 'master',
            credentialsId: 'mule-docs-agent-ssh-key',
            changelog: false,
            poll: false
      }
    }
    stage('Install') {
      steps {
        parallel(
          ui: {
            withCredentials([string(credentialsId: 'mule-docs-agent-github-token', variable: 'GITHUB_TOKEN')]) {
              sh './download-ui-bundle.sh'
              sh 'zip -T build/ui-bundle.zip'
            }
          },
          node_modules: {
            nodejs('node8') {
              //sh 'BUILD_ONLY=true yarn'
              sh 'yarn'
            }
          }
        )
      }
    }
    stage('Build') {
      environment {
        LD_LIBRARY_PATH='usr/lib/x86_64-linux-gnu'
      }
      steps {
        sshagent(['mule-docs-agent-ssh-key']) {
          nodejs('node8') {
            sh 'curl -sO http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu/pool/main/g/gcc-8/libstdc++6_8.1.0-5ubuntu1~14.04_amd64.deb'
            sh 'ar p libstdc++6_8.1.0-5ubuntu1~14.04_amd64.deb data.tar.xz | tar xJ'
            sh '$(npm bin)/antora --clean --pull --stacktrace antora-production-playbook.yml'
          }
        }
      }
    }
    stage('Publish') {
      steps {
        s3Upload profileName: 'dev-docs-jenkins-qax',
            entries: [[
              bucket: 'mulesoft-dev-docs-qax',
              selectedRegion: 'us-east-1',
              storageClass: 'STANDARD',
              sourceFile: 'build/site/**',
              excludedFile: '',
              flatten: false,
              gzipFiles: false,
              keepForever: true,
              managedArtifacts: false,
              noUploadOnFailure: true,
              showDirectlyInBrowser: false,
              uploadFromSlave: true,
              useServerSideEncryption: false
            ]],
            dontWaitForConcurrentBuildCompletion: false,
            consoleLogLevel: 'WARNING',
            pluginFailureResultConstraint: 'FAILURE',
            userMetadata: []
      }
    }
    stage('Invalidate Cache') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'dev-docs-jenkins-qax', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
          //sh 'aws --output text cloudfront create-invalidation --distribution-id E2EXZ06TFQNQ5B --paths "/*"'
        }
      }
    }
  }
  post { 
    always { 
      deleteDir()
    }
  }
}
