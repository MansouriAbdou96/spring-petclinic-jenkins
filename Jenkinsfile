pipeline {
    agent {
        label "docker-spring"
    } 

    stages {
        stage ('Build') {
            steps {
                sh "./gradlew build --refresh-dependencies"
            }
        }

        stage ('Test') {
            steps {
                sh "./gradlew test"
            }
            
            post {
                always {
                     junit "build/test-results/**/*.xml"
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv() {
                    sh "./gradlew sonar"
                }
            }
        }
    }
}
