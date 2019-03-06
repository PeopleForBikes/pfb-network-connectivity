#!groovy
node {

  properties([disableConcurrentBuilds()])
  
  try {
    // Checkout the proper revision into the workspace.
    stage('checkout') {
      checkout scm
    }

    env.AWS_PROFILE = 'pfb'
    env.GIT_COMMIT = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
    // Use dummy values for now, these resources don't actually exist
    env.PFB_AWS_BATCH_ANALYSIS_JOB_QUEUE_NAME = 'dummy-test-pfb-analysis-job-queue'
    env.PFB_AWS_BATCH_ANALYSIS_JOB_DEFINITION_NAME_REVISION = 'dummy-test-pfb-analysis-run-job:1'

    // Execute `setup` wrapped within a plugin that translates
    // ANSI color codes to something that renders inside the Jenkins
    // console.
    stage('setup') {
      wrap([$class: 'AnsiColorBuildWrapper']) {
        sh 'scripts/update'
      }
    }

    stage('cibuild') {
      wrap([$class: 'AnsiColorBuildWrapper']) {
        sh 'scripts/cibuild'
      }
    }

    if (env.BRANCH_NAME == 'develop' || env.BRANCH_NAME.startsWith('release/') || env.BRANCH_NAME.startsWith('test/')) {
      env.AWS_DEFAULT_REGION = 'us-east-1'
      env.PFB_SETTINGS_BUCKET = 'staging-pfb-config-us-east-1'
      env.PFB_S3STORAGE_BUCKET = 'staging-pfb-static-us-east-1'

      // Publish container images built and tested during `cibuild`
      // to the private Amazon Container Registry tagged with the
      // first seven characters of the revision SHA.
      stage('cipublish') {
        // Decode the `AWS_ECR_ENDPOINT` credential stored within
        // Jenkins. In includes the Amazon ECR registry endpoint.
        withCredentials([[$class: 'StringBinding',
                          credentialsId: 'PFB_AWS_ECR_ENDPOINT',
                          variable: 'PFB_AWS_ECR_ENDPOINT']]) {
          wrap([$class: 'AnsiColorBuildWrapper']) {
            sh './scripts/cipublish'
          }
        }
      }

      // Plan and apply the current state of the instracture as
      //
      // Also, use the container image revision referenced above to
      // cycle in the newest version of the application into Amazon
      // ECS.
      stage('infra') {
        // Use `git` to get the primary repository's current commmit SHA and
        // set it as the value of the `GIT_COMMIT` environment variable.
        withCredentials([[$class: 'StringBinding',
                          credentialsId: 'PFB_AWS_ECR_ENDPOINT',
                          variable: 'PFB_AWS_ECR_ENDPOINT']]) {
          wrap([$class: 'AnsiColorBuildWrapper']) {
            sh './scripts/infra plan'
            sh './scripts/infra apply'
          }
        }
      }
    }
  } catch (err) {
    // Some exception was raised in the `try` block above. Assemble
    // an appropirate error message for Slack.

    def slackMessage = ":jenkins-angry: *pfb-network-connectivity (${env.BRANCH_NAME}) #${env.BUILD_NUMBER}*"
    if (env.CHANGE_TITLE) {
      slackMessage += "\n${env.CHANGE_TITLE} - ${env.CHANGE_AUTHOR}"
    }
    slackMessage += "\n<${env.BUILD_URL}|View Build>"
    slackSend color: 'danger', channel: '#people-for-bikes', message: slackMessage

    // Re-raise the exception so that the failure is propagated to
    // Jenkins.
    throw err
  } finally {
    // Pass or fail, ensure that the services and networks
    // created by Docker Compose are torn down.
    sh 'docker-compose down -v'
  }
}

