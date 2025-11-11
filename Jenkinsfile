pipeline {
    agent any

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'prod'], description: 'Target environment')
    }
    
    tools {
        jdk 'JAVA_HOME'
	maven 'M2_HOME'
    }
    
    environment {
        DOCKER_IMAGE = "taibmh/spring-petclinic:${BUILD_NUMBER}"
        DOCKER_REGISTRY = "docker.io"
        K8S_NAMESPACE = "${params.ENVIRONMENT}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/taibMH/spring-petclinic.git',
                    credentialsId: 'f72b2e8b-21eb-4853-b050-32fd26cbb0d5'
            }
        }
        
        stage('Build') {
            steps {
                sh 'rm -rf .scannerwork'
                sh './mvnw clean compile'
            }
        }

        stage('OWASP Dependency-Check') {
            steps {
                withCredentials([string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')]) {
                    dependencyCheck(
                        odcInstallation: 'owasp-dependency',
                        additionalArguments: '--suppression suppression.xml --enableRetired --format HTML --format XML --scan . --nvdApiKey ${NVD_API_KEY}',
                        stopBuild: false,
                        skipOnScmChange: false
                    )
                }
            }
            post {
                always {
                    dependencyCheckPublisher(
                        pattern: 'dependency-check-report.xml',
                        canComputeNew: false,
                        mustRun: true,
                        overwritePrevious: true
                    )
                    archiveArtifacts artifacts: 'dependency-check-report.*', allowEmptyArchive: true
                }
            }
        }

        stage('Secrets Scan (Gitleaks)') {
            steps {
                sh 'gitleaks detect -s . --report-format=json --report-path=gitleaks-report.json'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true
                }
            }
        }

        
        stage('Test') {
            steps {
                sh './mvnw test -Dtest=!PostgresIntegrationTests'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    def scannerHome = tool 'SonarScanner'
                    withSonarQubeEnv('SonarQube') {
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=spring-petclinic \
                            -Dsonar.projectName='Spring PetClinic' \
                            -Dsonar.sources=src/main/java \
                            -Dsonar.tests=src/test/java \
                            -Dsonar.java.binaries=target/classes \
                            -Dsonar.java.test.binaries=target/test-classes \
                            -Dsonar.junit.reportPaths=target/surefire-reports \
                            -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
                            -Dsonar.java.source=17
                        """
                    }
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
                sh 'rm -rf .scannerwork'
            }
        }
        
        stage('Package') {
            steps {
                sh './mvnw package -DskipTests'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                sh 'docker build -t ${DOCKER_IMAGE} .'
            }
        }
        
        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                        docker tag ${DOCKER_IMAGE} taibmh/spring-petclinic:latest
                        docker push ${DOCKER_IMAGE}
                        docker push taibmh/spring-petclinic:latest
                        docker logout
                    '''
                }
            }
        }
        
        stage('Trivy Security Scan') {
            steps {
                sh '''
                    trivy image --severity HIGH,CRITICAL --format json --output trivy-report.json ${DOCKER_IMAGE}
                    trivy image --severity HIGH,CRITICAL --format table ${DOCKER_IMAGE}
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.json', fingerprint: true
                }
            }
        }

                    
        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                    kubectl apply -f k8s/${K8S_NAMESPACE}/ -n ${K8S_NAMESPACE}
                    kubectl delete replicaset --all -n ${K8S_NAMESPACE} || true
                    kubectl delete pod --field-selector=status.phase==Pending -n ${K8S_NAMESPACE} || true
                    sleep 10
                    sed -i "s|image: taibmh/spring-petclinic:.*|image: ${DOCKER_IMAGE}|g" k8s/${K8S_NAMESPACE}/petclinic.yml
                    kubectl apply -f k8s/${K8S_NAMESPACE}/petclinic.yml -n ${K8S_NAMESPACE}
                    kubectl rollout status deployment/petclinic -n ${K8S_NAMESPACE} --timeout=180s
                    kubectl get pods -l app=petclinic -n ${K8S_NAMESPACE}
                    kubectl get svc petclinic -n ${K8S_NAMESPACE}
                '''
            }
        }
        
        stage('Archive') {
            steps {
                archiveArtifacts artifacts: '**/target/*.jar', fingerprint: true
            }
        }
    }
    
    post {
        success {
            echo 'Full CI/CD pipeline completed!'
        }
        failure {
            echo 'Build failed!'
        }
    }
}
