pipeline {
  agent any

  environment {
    IMAGE = "${DOCKERHUB_USERNAME}/devops-quizmaster"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Find package dir & Install') {
      steps {
        script {
          // find first top-level directory that contains package.json
          def pkgDir = sh(script: 'for d in */ ; do if [ -f "$d/package.json" ]; then printf "%s" "$d"; break; fi; done', returnStdout: true).trim()
          if (!pkgDir) {
            error "package.json not found in any top-level folder"
          }
          // remove trailing slash for later use
          pkgDir = pkgDir.replaceAll(/\/$/, '')
          echo "Using package directory: ${pkgDir}"

          // run npm inside that directory
          dir(pkgDir) {
            sh '''
              echo "Node: $(node -v || echo missing)"
              echo "NPM: $(npm -v || echo missing)"
              npm install
            '''
          }

          // build inside same folder
          dir(pkgDir) {
            sh 'npm run build'
          }

          // copy build output to repo root (docker build context)
          sh """
            rm -rf dist || true
            cp -r "${pkgDir}/dist" ./dist
            ls -la ./dist || true
          """
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          def shortCommit = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          env.IMAGE_TAG = "${IMAGE}:${shortCommit}"
          sh """
            docker build -t ${IMAGE_TAG} .
            docker tag ${IMAGE_TAG} ${IMAGE}:latest
          """
        }
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh '''
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
            docker push ${IMAGE_TAG}
            docker push ${IMAGE}:latest
            docker logout
          '''
        }
      }
    }

stage('Slack Notification') {
  steps {
    withCredentials([string(credentialsId: 'slack-webhook', variable: 'SLACK_WEBHOOK')]) {
      script {
        try {
          // run curl and capture http code + response
          sh '''
            PAYLOAD=$(printf '{"text":"Jenkins Build Complete: %s"}' "${IMAGE_TAG}")
            echo "Payload: $PAYLOAD"
            HTTP_CODE=$(curl -s -o /tmp/slack_resp -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$SLACK_WEBHOOK" || echo "000")
            echo "Slack HTTP status: $HTTP_CODE"
            echo "Slack body:"
            cat /tmp/slack_resp || true
            if [ "$HTTP_CODE" -ge 400 ] || [ "$HTTP_CODE" = "000" ]; then
              echo "Warning: Slack notify failed (status $HTTP_CODE)"
            else
              echo "Slack notified successfully."
            fi
          '''
        } catch (err) {
          echo "Slack stage caught exception: ${err}"
          // don't fail the entire build just because Slack failed
        }
      }
    }
  }
}


  post {
    success { echo "Build and Push Completed Successfully." }
    failure { echo "Build Failed. Check logs." }
  }
}
