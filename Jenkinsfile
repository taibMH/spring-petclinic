pipeline {
    agent any
    
    tools {
        jdk 'JDK-25'
        maven 'M2_HOME'
    }
    
    environment {
        DOCKER_IMAGE = "taibMH/spring-petclinic:${BUILD_NUMBER}"
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
                sh './mvnw test'
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
        
        stage('Archive') {
            steps {
                archiveArtifacts artifacts: '**/target/*.jar', fingerprint: true
            }
        }
    }
    
    post {
        success {
            echo 'Build completed successfully! Docker image: ${DOCKER_IMAGE}'
        }
        failure {
            echo 'Build failed!'
        }
    }
}

