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
              sh '''
                curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/mulesoft/docs-site-antora-ui/releases \
                | jq .[0].assets[0].id \
                | curl -s -L -o build/ui-bundle.zip --create-dirs -H "Accept: application/octet-stream" https://api.github.com/repos/mulesoft/docs-site-antora-ui/releases/assets/$(cat /dev/stdin)?access_token=$GITHUB_TOKEN
              '''
            }
          },
          node_modules: {
            nodejs('node8') {
              // BUILD_ONLY is required on Fedora to force nodegit to recompile
              sh 'BUILD_ONLY=true yarn'
            }
          }
        )
      }
    }
    stage('Build') {
      steps {
        sshagent(['mule-docs-agent-ssh-key']) {
          nodejs('node8') {
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
    //stage('Invalidate Cache') {
    //  steps {
    //    // requires CloudBees AWS CLI plugin
    //    withAwsCli(credentialsId: 'testing-aws', defaultRegion: 'us-east-1') {
    //      sh 'aws --output text cloudfront create-invalidation --distribution-id EZ24EZJWM93W9 --paths "/*"'
    //    }
    //  }
    //}
  }
  post { 
    always { 
      deleteDir()
    }
  }
}
