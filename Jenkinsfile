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
                withSonarQubeEnv("sonarqube-petclinic") {
                    sh "./gradlew sonar"
                }
            }
            post {
                failure {
                    emailext body: 'The SonarQube analysis has failed. Please check the build log for details.',
                         subject: 'SonarQube Analysis Failed',
                        to: "$MY_EMAIL"
                }
            }
        }
    }
}
