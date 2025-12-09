pipeline {
  agent any

  environment {
    DOCKERHUB_USER = "${DOCKERHUB_USERNAME ?: 'shreeshasn'}"
    IMAGE_BASE = "${DOCKERHUB_USER}/devops-quizmaster"
  }

  options {
    timeout(time: 60, unit: 'MINUTES')
    // timestamps() removed for compatibility with your Jenkins instance
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Clean workspace artifacts') {
      steps {
        script {
          sh '''
            echo "Cleaning workspace common artifacts..."
            rm -rf node_modules package-lock.json .vite .cache dist build || true
            echo "Clean done."
            ls -la || true
          '''
        }
      }
    }

    stage('Install & Build') {
      steps {
        script {
          sh '''
            echo "Node: $(node -v || echo missing)"
            echo "NPM: $(npm -v || echo missing)"
            if [ ! -f package.json ]; then
              echo "ERROR: package.json not found in repo root"; exit 2
            fi
            npm ci || npm install
            npm run build
          '''
        }
      }
    }

    stage('Prepare dist for Docker') {
      steps {
        script {
          sh '''
            if [ ! -d dist ]; then
              echo "ERROR: dist/ not found after build"; ls -la || true; exit 3
            fi
            rm -rf dist_tmp || true
            cp -r dist dist_tmp || true
            rm -rf dist || true
            mv dist_tmp dist || true
            ls -la dist || true
          '''
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          def shortHash = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          env.IMAGE_TAG = "${IMAGE_BASE}:${shortHash}"
          sh """
            echo "Building image ${env.IMAGE_TAG}"
            docker build -t ${env.IMAGE_TAG} .
            docker tag ${env.IMAGE_TAG} ${IMAGE_BASE}:latest || true
          """
        }
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          script {
            sh '''
              echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
              docker push ${IMAGE_TAG}
              docker push ${IMAGE_BASE}:latest || true
              docker logout || true
            '''
          }
        }
      }
    }

    stage('Slack Notification') {
      steps {
        withCredentials([string(credentialsId: 'slack-webhook', variable: 'SLACK_WEBHOOK')]) {
          script {
            sh '''
              PAYLOAD=$(printf '{"text":"Jenkins Build Complete: %s - image: %s"}' "$(hostname)-${BUILD_NUMBER}" "${IMAGE_TAG}")
              HTTP_CODE=$(curl -s -o /tmp/slack_resp -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$SLACK_WEBHOOK" || echo "000")
              echo "Slack HTTP status: $HTTP_CODE"
              cat /tmp/slack_resp || true
              if [ "$HTTP_CODE" = "000" ] || [ "$HTTP_CODE" -ge 400 ]; then
                echo "Warning: Slack notify returned $HTTP_CODE"
              else
                echo "Slack notified OK."
              fi
            '''
          }
        }
      }
    }
  }

  post {
    success {
      echo "SUCCESS: Build + push completed: ${IMAGE_TAG}"
    }
    failure {
      echo "FAILURE: Check console output for errors."
    }
    always {
      echo "Post: cleanup hint - delete workspace in Jenkins UI if desired."
    }
  }
}
