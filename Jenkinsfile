#!/usr/bin/env groovy
import com.mulesoft.AdminManager
import groovy.json.JsonSlurper

// artifactsNames   = ['cloudhub-ui', 'mozart-ui', 'anypoint-navbar', 'anypoint-icons', 'anypoint-styles', 'analytics-kpi-web', 'marketing-assets']
artifactEnvs    = ['stgx']
releaseEnvs     = ['stgx', 'prod']

supportedEnvs   = artifactEnvs + releaseEnvs

String getNexusRepository(environment) {
  return !environment || environment in artifactEnvs ? 'artifacts' : 'releases'
}

properties([
  parameters([
    choice(name: 'Environment', description: 'Target environment', choices: releaseEnvs.join('\n')),
    string(name: 'Version', description: 'Artifact version to deploy', defaultValue: '')
  ]),
  pipelineTriggers([])
])

currentBuild.displayName = "${env.Version} - (${env.Environment})"

node('dev-slave') {  
  def environment = env.Environment && env.Environment in supportedEnvs ? env.Environment : ''
  def srcDevDocs = 'dev-docs-jenkins-stgx'
  withCredentials([[ $class: 'UsernamePasswordMultiBinding', credentialsId: srcDevDocs, usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY' ]]) {
        wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'XTerm']) {

          def s3bucket    = "mulesoft-dev-docs-stgx"
          def artifact    = "docs-build"
          def version     = env.Version
          // def environment = env.Environment && env.Environment in supportedEnvs ? env.Environment : ''

          echo "Starting job to upload in environment '$environment' the artifact '$artifact', version '$version', located in s3 bucket '$s3bucket'"
          
          def filename = "${artifact}-${version}.tar.gz"
          def credentials = "${env.NEXUS_USERNAME}:${env.NEXUS_PASSWORD}"
      
          def uncompress_cmd = "tar -xvf ${filename} -C ${artifact} ;"
          // def download_cmd = "curl -u '${credentials}' --output ${filename} ${url};"
          def download_cmd = "aws --region us-east-1 s3api get-object --bucket ${s3bucket} --key buildarchive/${filename} ${filename}"
          def showfile_cmd = "ls -lh ${filename}; file ${filename};"
          def checkfile_cmd = "if grep \"404 - Not Found\" ${filename}; then echo \"Artifact does not exist !\"; exit 1; fi;"


          stage('Download from s3') {
            echo "Downloading from S3 ${env.AWS_ACCESS_KEY_ID}"
            sh "${download_cmd}"
            echo "Downloaded file size/type:"
            sh "${showfile_cmd}"
            echo "Checking downloaded file"
            sh "${checkfile_cmd}"
          }    
      
          stage('Uncompressing artifact') {
            echo "Removing old artifact folder $artifact"
            sh "rm -rf ${artifact}; mkdir -v ${artifact}"
            echo "Uncompressing filename $filename in artifact $artifact"
            sh "${uncompress_cmd}"
          }
    }          
  }
}

node('dev-slave') {
  def environment = env.Environment && env.Environment in supportedEnvs ? env.Environment : ''
  def targetDevDocs = "dev-docs-jenkins-${env.Environment}"
  withCredentials([[ $class: 'UsernamePasswordMultiBinding', credentialsId: targetDevDocs, usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY' ]]) {
    wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'XTerm']) {
      def artifact    = "docs-build"
      //def targetS3bucket = "dev-docs-cdn-${environment}.mulesoft.com"
      def targetS3bucket = "mulesoft-dev-docs-${environment}"

      //def upload_cmd = "aws --region us-east-1 --color on s3 cp --recursive --acl public-read --cache-control public,max-age=1209600 ${artifact} s3://${targetS3bucket}/current/"
      def upload_cmd = "aws --region us-east-1 --color on s3 sync --acl public-read --cache-control public,max-age=1209600 --delete ${artifact} s3://${targetS3bucket}/current/"

      def cf_origindomain = "dev-docs-cdn.${environment}.mulesoft.com"
      if(environment == "prod") {
        cf_origindomain = "dev-docs-cdn.mulesoft.com"
      }
      def cf_listdist = "aws --region us-east-1 cloudfront list-distributions"
      def preview_cloudfront_cmd = "aws configure set preview.cloudfront true"

      def cf_dist_id = null

      stage('Deploying into environment') {
        echo "Deploying into environment ${environment}"
  
        //manager = new AdminManager()
        //prefix = ":cloudfront: uploading <${env.BUILD_URL}|${currentBuild.displayName}>"
        //admin = manager.getAdmin(environment)
        //manager.prompt(environment, prefix, true)
        sh "${upload_cmd}"
      }

      stage("enable cloudfront preview") {
        // We have to enable this as cli commands don't allow cloudfront commands by default
        echo "Enabling cloudfront preview cli"
        sh "${preview_cloudfront_cmd}"
      }

      stage("Get CloudFront distribution id") {
        // We need to get the id of the cloudfront distribution based on the name of the domain origin
        echo "Get the cloudfront distribution id"
        CFDIST = sh (script: "${cf_listdist}", returnStdout: true).trim()
        echo "${CFDIST}"
        def jsonSlurper = new JsonSlurper()
        def cfDistMap = jsonSlurper.parseText("${CFDIST}")
        def distributions = cfDistMap['DistributionList']['Items']
        //echo "${distributions}"
        //assert distributions instanceof Map
        for (i = 0; i < distributions.size() && cf_dist_id == null; i++) {
          def distribution = distributions[i]
          echo "${distribution}"
          def originsList = distribution['Origins']['Items']
          for(j = 0; j < originsList.size() && cf_dist_id == null; j++) {
            def originMap = originsList[j]
            echo "${originMap}"
            if (originMap['DomainName'] == cf_origindomain) {
              echo "Have found origin domain name"
              cf_dist_id = distribution['Id']
            }
          }
        }
      }

      stage('Purge cloudfront') {
        echo "Purging cloudfront with ID ${cf_dist_id}" 
        echo "/*"
        def purge_cloudfront_cmd = "aws --region us-east-1 cloudfront create-invalidation --distribution-id ${cf_dist_id} --paths '/*'"
        echo "${purge_cloudfront_cmd}"
        sh "${purge_cloudfront_cmd}"
        echo "Invalidation has started"
      }
          
      stage('clean-up') {
        sh "rm -rf ${artifact}*"
      }

    }
  }
}
