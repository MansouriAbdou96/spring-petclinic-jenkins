pipeline {
    agent {
        label "docker-spring"
    } 

    stages {
        stage ('Build') {
            steps {
                sh "./gradlew build"
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
                success {
                     publishChecks qualityGate: [
                        [$class: 'ErrorCountCheck', threshold: 1],
                        [$class: 'FailedThresholdCheck', unstableThreshold: 1]
                     ]
                }
            }
        }
    }
}
