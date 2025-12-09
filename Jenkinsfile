pipeline {
  agent any

  environment {
    // set default dockerhub username here if not supplied via Jenkins env
    DOCKERHUB_USER = "${DOCKERHUB_USERNAME ?: 'shreeshasn'}"
    IMAGE_BASE = "${DOCKERHUB_USER}/devops-quizmaster"
  }

  options {
    // keep a reasonable log timeout and allow timestamps
    timeout(time: 60, unit: 'MINUTES')
    timestamps()
  }

  stages {

    stage('Checkout') {
      steps {
        // pull Jenkinsfile + repo
        checkout scm
      }
    }

    stage('Clean workspace artifacts') {
      steps {
        script {
          // remove common noise so builds start fresh
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
          // run install and build from repo root
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
            # Ensure dist exists
            if [ ! -d dist ]; then
              echo "ERROR: dist/ not found after build"; ls -la || true; exit 3
            fi
            # make sure docker context will contain dist at repo root
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
        // requires credentials entry with id 'dockerhub-creds' (username/password)
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          script {
            sh '''
              echo "Logging into Docker Hub as $DH_USER"
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
        // requires credentials entry with id 'slack-webhook' (secret text)
        withCredentials([string(credentialsId: 'slack-webhook', variable: 'SLACK_WEBHOOK')]) {
          script {
            // Keep slack failures non-fatal (demo-friendly). We'll print response for debugging.
            sh '''
              PAYLOAD=$(printf '{"text":"Jenkins: Build %s - image: %s"}' "$(hostname)-${BUILD_NUMBER}" "${IMAGE_TAG}")
              echo "Payload: $PAYLOAD"
              HTTP_CODE=$(curl -s -o /tmp/slack_resp -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$SLACK_WEBHOOK" || echo "000")
              echo "Slack HTTP status: $HTTP_CODE"
              echo "Slack body:"
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
      script {
        // keep minimal housekeeping so post { always } is non-empty
        echo "Post: workspace cleanup hint - you can delete workspace in Jenkins UI if desired."
      }
    }
  }
}
