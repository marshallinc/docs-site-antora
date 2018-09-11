pipeline {
  //agent any
  agent {
    label 'dev-docs-slave'
  }
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
              //sh './download-ui-bundle.sh'
              sh 'curl -s -o build/ui-bundle.zip --create-dirs https://s3.amazonaws.com/mulesoft-dev-docs-qax/bin/ui-bundle.zip'
              //sh 'zip -T build/ui-bundle.zip'
              sh 'file -i build/ui-bundle.zip'
            }
          },
          node_modules: {
            nodejs('node8') {
              //sh 'BUILD_ONLY=true yarn'
              sh 'yarn'
            }
          },
          //libs: {
          //  sh 'curl -sO http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu/pool/main/g/gcc-8/libstdc++6_8.1.0-5ubuntu1~14.04_amd64.deb'
          //  sh 'ar p libstdc++6_8.1.0-5ubuntu1~14.04_amd64.deb data.tar.xz | tar xJ'
          //}
        )
      }
    }
    stage('Build') {
      environment {
        //LD_LIBRARY_PATH='usr/lib/x86_64-linux-gnu'
        NODE_OPTIONS='--max-old-space-size=4096'
      }
      steps {
        sshagent(['mule-docs-agent-ssh-key']) {
          nodejs('node8') {
            sh '$(npm bin)/antora --clean --pull --stacktrace antora-production-playbook.yml > build/build.log 2>&1'
            sh 'cat build/build.log'
          }
        }
      }
    }
    stage('Publish') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'dev-docs-jenkins-qax', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
          sh 'aws s3 cp build/site/ s3://mulesoft-dev-docs-qax/ --recursive --only-show-errors --acl=public-read'
        }
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
