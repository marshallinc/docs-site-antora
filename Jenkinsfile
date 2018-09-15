def gitUrl = 'git@github.com:mulesoft/docs-site-antora'
def gitBranch = 'master'
def gitCredentialsId = 'mule-docs-agent-ssh-key'
def githubCredentialsId = 'mule-docs-agent-github-token'
def awsCredentialsId = 'dev-docs-jenkins-qax'
def s3Bucket = 'mulesoft-dev-docs-qax'
def cfDistributionId = 'E2EXZ06TFQNQ5B'

pipeline {
  agent {
    label 'ubuntu-14.04'
  }
  stages {
    stage('Clone') {
      steps {
        // NOTE this job is configured such that the branch is already checked out at this stage
        //checkout scm:
        //    [
        //      $class: 'GitSCM',
        //      userRemoteConfigs: [[credentialsId: gitCredentialsId, url: gitUrl]],
        //      branches: [[name: "refs/heads/${gitBranch}"]],
        //      extensions: [[$class: 'CloneOption', depth: 1, honorRefspec: true, noTags: true, shallow: true]]
        //    ],
        //    changelog: false,
        //    poll: false
        script {
          if (sh(script: 'git log -1 --pretty=tformat:%s | grep -qP "\\[skip .+?\\]"', returnStatus: true) == 0) {
            env.SKIP_CI = 'true'
          }
        }
      }
    }
    stage('Install') {
      when { allOf { environment name: 'GIT_BRANCH', value: 'master'; not { environment name: 'SKIP_CI', value: 'true' } } }
      steps {
        parallel(
          ui: {
            withCredentials([string(credentialsId: githubCredentialsId, variable: 'GITHUB_TOKEN')]) {
              nodejs('node8') {
                sh './download-ui-bundle.sh'
              }
              sh 'file -i build/ui-bundle.zip'
            }
          },
          node_modules: {
            nodejs('node8') {
              sh 'yarn'
            }
          },
          libs: {
            sh 'curl -sO http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu/pool/main/g/gcc-8/libstdc++6_8.1.0-5ubuntu1~14.04_amd64.deb'
            sh 'ar p libstdc++6_8.1.0-5ubuntu1~14.04_amd64.deb data.tar.xz | tar xJ'
          }
        )
      }
    }
    stage('Build') {
      when { allOf { environment name: 'GIT_BRANCH', value: 'master'; not { environment name: 'SKIP_CI', value: 'true' } } }
      environment {
        LD_LIBRARY_PATH='usr/lib/x86_64-linux-gnu'
        NODE_OPTIONS='--max-old-space-size=4096'
      }
      steps {
        sshagent(['mule-docs-agent-ssh-key']) {
          nodejs('node8') {
            script {
              try {
                sh '$(npm bin)/antora --clean --pull --stacktrace --html-url-extension-style=drop antora-production-playbook.yml > build/build.log 2>&1'
              } finally {
                sh 'cat build/build.log'
              }
            }
          }
        }
      }
    }
    stage('Publish') {
      when { allOf { environment name: 'GIT_BRANCH', value: 'master'; not { environment name: 'SKIP_CI', value: 'true' } } }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: awsCredentialsId, accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
          sh "aws s3 sync build/site/ s3://${s3Bucket}/ --delete --acl public-read --cache-control 'public,max-age=0,must-revalidate' --metadata-directive REPLACE --only-show-errors"
          sh "aws s3 cp build/site/_/font/ s3://${s3Bucket}/_/font/ --recursive --include '*.woff' --acl public-read --cache-control 'public,max-age=604800' --metadata-directive REPLACE --only-show-errors"
          sh "aws s3 cp etc/nginx/includes/rewrites.conf s3://${s3Bucket}/.rewrites.conf --only-show-errors"
        }
      }
    }
    stage('Invalidate Cache') {
      when { allOf { environment name: 'GIT_BRANCH', value: 'master'; not { environment name: 'SKIP_CI', value: 'true' } } }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: awsCredentialsId, accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
          sh "aws --output text cloudfront create-invalidation --distribution-id ${cfDistributionId} --paths '/*'"
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
