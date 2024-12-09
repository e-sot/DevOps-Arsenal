pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = credentials('docker-registry')
        KUBECONFIG = credentials('k8s-config')
        SONAR_TOKEN = credentials('sonar-token')
        VAULT_TOKEN = credentials('vault-token')
        APP_VERSION = sh(script: "awk '/version/ {print \$2}' releases.txt", returnStdout: true).trim()
    }

    stages {
        stage('Security Scan - Dependencies') {
            steps {
                sh '''
                    python -m pip install safety
                    safety check -r docker/eto-webapp/requirements.txt
                    python -m pip install bandit
                    bandit -r docker/eto-webapp -f json -o bandit-results.json
                '''
            }
        }

        stage('Quality Check') {
            steps {
                sh '''
                    python -m pip install pylint black mypy
                    python -m pylint docker/eto-webapp
                    python -m black --check docker/eto-webapp
                    python -m mypy docker/eto-webapp
                '''
            }
        }

        stage('Unit Tests') {
            steps {
                sh '''
                    python -m pytest tests/unit \
                        --junitxml=unit-tests.xml \
                        --cov=docker/eto-webapp \
                        --cov-report=xml:coverage.xml
                '''
            }
        }

        stage('Build') {
            steps {
                script {
                    docker.withRegistry(env.DOCKER_REGISTRY, 'docker-registry') {
                        sh """
                            docker build -t ${DOCKER_REGISTRY}/eto-webapp:${APP_VERSION} \
                                --build-arg VERSION=${APP_VERSION} \
                                --no-cache \
                                --security-opt seccomp=security/seccomp.json \
                                docker/eto-webapp
                        """
                    }
                }
            }
        }

        stage('Security Scan - Container') {
            steps {
                sh """
                    trivy image ${DOCKER_REGISTRY}/eto-webapp:${APP_VERSION} \
                        --severity HIGH,CRITICAL \
                        --exit-code 1
                """
            }
        }

        stage('Integration Tests') {
            steps {
                sh '''
                    docker-compose -f docker-compose.test.yml up -d
                    python -m pytest tests/integration --junitxml=integration-tests.xml
                    docker-compose -f docker-compose.test.yml down
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh """
                        sonar-scanner \
                            -Dsonar.projectKey=eto-webapp \
                            -Dsonar.sources=. \
                            -Dsonar.python.coverage.reportPaths=coverage.xml \
                            -Dsonar.python.xunit.reportPath=unit-tests.xml
                    """
                }
            }
        }

        stage('Push to Registry') {
            when { branch 'main' }
            steps {
                script {
                    docker.withRegistry(env.DOCKER_REGISTRY, 'docker-registry') {
                        sh """
                            docker push ${DOCKER_REGISTRY}/eto-webapp:${APP_VERSION}
                            docker tag ${DOCKER_REGISTRY}/eto-webapp:${APP_VERSION} \
                                ${DOCKER_REGISTRY}/eto-webapp:latest
                            docker push ${DOCKER_REGISTRY}/eto-webapp:latest
                        """
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            when { branch 'main' }
            steps {
                withKubeConfig([credentialsId: 'k8s-config']) {
                    sh """
                        kubectl apply -f k8s/namespace.yml
                        kubectl apply -f k8s/configmaps.yml
                        kubectl apply -f k8s/secrets.yml
                        kubectl apply -f k8s/
                        kubectl rollout status deployment/eto-webapp -n eto
                    """
                }
            }
        }
    }

    post {
        always {
            junit '**/unit-tests.xml, **/integration-tests.xml'
            cobertura coberturaReportFile: 'coverage.xml'
            recordIssues enabledForFailure: true, tools: [
                checkStyle(pattern: '**/pylint.xml'),
                bandit(pattern: '**/bandit-results.json')
            ]
            cleanWs()
        }
        success {
            slackSend(
                color: 'good',
                message: "Build Successful: ${env.JOB_NAME} ${env.BUILD_NUMBER}"
            )
        }
        failure {
            slackSend(
                color: 'danger',
                message: "Build Failed: ${env.JOB_NAME} ${env.BUILD_NUMBER}"
            )
        }
    }
}
