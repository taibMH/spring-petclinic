pipeline {
    agent any
    
    tools {
        jdk 'JAVA_HOME'
	maven 'M2_HOME'
    }
    
    environment {
        DOCKER_IMAGE = "taibmh/spring-petclinic:${BUILD_NUMBER}"
        DOCKER_REGISTRY = "docker.io"
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
                sh './mvnw clean compile'
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
                        docker push ${DOCKER_IMAGE}
                        docker logout
                    '''
                }
            }
        }
        
        stage('Trivy Security Scan') {
            steps {
                sh '''
                    trivy image --severity HIGH,CRITICAL ${DOCKER_IMAGE} || true
                '''
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                    kubectl apply -f k8s/db.yml
                    kubectl get replicaset -l app=petclinic -o jsonpath='{.items[*].metadata.name}' | xargs -r kubectl delete replicaset || true
                    sleep 10
                    sed -i "s|image: taibmh/spring-petclinic:.*|image: ${DOCKER_IMAGE}|g" k8s/petclinic.yml
                    kubectl apply -f k8s/petclinic.yml
                    kubectl rollout status deployment/petclinic --timeout=120s
                    kubectl get pods -l app=petclinic
                    kubectl get svc petclinic
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
