#!groovy

def gitUrl = 'git@github.com:mulesoft/docs-site-antora'
def gitBranch = 'master'
def gitCredentialsId = 'mule-docs-agent-ssh-key'
def githubCredentialsId = 'mule-docs-agent-github-token'
// qax
//def awsCredentialsId = 'dev-docs-jenkins-qax'
//def awsCredentials = [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: awsCredentialsId, accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
//def s3Bucket = 'mulesoft-dev-docs-qax'
//def cfDistributionId = 'E2EXZ06TFQNQ5B'
// stgx
def awsCredentialsId = 'dev-docs-jenkins-stgx'
def awsCredentials = usernamePassword(credentialsId: awsCredentialsId, usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')
def s3Bucket = 'mulesoft-dev-docs-stgx'
def cfDistributionId = 'E16J12CGBH1F67'

pipeline {
  agent {
    label 'ubuntu-14.04'
  }
  triggers {
    cron('H 1-23 * * *')
  }
  stages {
    stage('Checkout') {
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
    stage('Clean') {
      when { allOf { environment name: 'GIT_BRANCH', value: 'master'; not { environment name: 'SKIP_CI', value: 'true' } } }
      steps {
        dir('build') {
          deleteDir()
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
              sh 'yarn --pure-lockfile'
            }
          },
          libs: {
            dir('build') {
              sh 'curl -sO http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu/pool/main/g/gcc-8/libstdc++6_8.1.0-5ubuntu1~14.04_amd64.deb'
              sh 'ar p libstdc++6_8.1.0-5ubuntu1~14.04_amd64.deb data.tar.xz | tar xJ'
            }
          }
        )
      }
    }
    stage('Build') {
      when { allOf { environment name: 'GIT_BRANCH', value: 'master'; not { environment name: 'SKIP_CI', value: 'true' } } }
      environment {
        LD_LIBRARY_PATH='build/usr/lib/x86_64-linux-gnu'
        NODE_OPTIONS='--max-old-space-size=8192'
      }
      steps {
        sshagent(['mule-docs-agent-ssh-key']) {
          nodejs('node8') {
            script {
              try {
                sh '$(npm bin)/antora --pull --stacktrace --generator=./generator/xref-validator antora-production-playbook.yml'
                sh '$(npm bin)/antora --stacktrace --html-url-extension-style=drop --redirect-facility=nginx antora-production-playbook.yml > build/build.log 2>&1'
                if (fileExists('build/site/.etc/nginx/rewrite.conf')) {
                  sh 'cat etc/nginx/includes/rewrites.conf build/site/.etc/nginx/rewrite.conf > build/rewrites.conf'
                } else {
                  sh 'cat etc/nginx/includes/rewrites.conf > build/rewrites.conf'
                }
                if (fileExists('build/site/.etc/nginx/legacy-wiki-rewrites.conf')) {
                  sh 'cat etc/nginx/includes/legacy-wiki-rewrites.conf build/site/.etc/nginx/legacy-wiki-rewrites.conf > build/legacy-wiki-rewrites.conf'
                } else {
                  sh 'cat etc/nginx/includes/legacy-wiki-rewrites.conf > build/legacy-wiki-rewrites.conf'
                }
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
        withCredentials([awsCredentials]) {
          // NOTE sync won't update the metadata unless the file is transferred
          sh "aws s3 sync build/site/ s3://${s3Bucket}/ --exclude '.etc/*' --delete --acl public-read --cache-control 'public,max-age=0,must-revalidate' --metadata-directive REPLACE --only-show-errors"
          //sh "aws s3 cp build/site/ s3://${s3Bucket}/ --recursive --exclude '.etc/*' --acl public-read --cache-control 'public,max-age=0,must-revalidate' --metadata-directive REPLACE"
          sh "aws s3 cp build/site/_/font/ s3://${s3Bucket}/_/font/ --recursive --include '*.woff' --acl public-read --cache-control 'public,max-age=604800' --metadata-directive REPLACE --only-show-errors"
          sh "aws s3 cp build/rewrites.conf s3://${s3Bucket}/.rewrites.conf --only-show-errors"
          sh "aws s3 cp build/legacy-wiki-rewrites.conf s3://${s3Bucket}/.legacy-wiki-rewrite.rewrites.conf --only-show-errors"
        }
      }
    }
    stage('Invalidate Cache') {
      when { allOf { environment name: 'GIT_BRANCH', value: 'master'; not { environment name: 'SKIP_CI', value: 'true' } } }
      steps {
        withCredentials([awsCredentials]) {
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
