def emailNotification(stageName){

    emailext    body: "The ${stageName} has failed. Please check the build log for details.",
                subject: "${stageName} Failed",
                to: "$MY_EMAIL"
}

pipeline {
    agent {
        label "docker-spring"
    } 

    stages {
        stage ('Build') {
            when {
                branch 'dev'
            }
            
            steps {
                sh "./gradlew build"
            }

            post {
                failure {
                    emailNotification('Build')
                }
            }
        }

        stage ('Test') {
            when {
                branch 'dev'
            }
            
            steps {
                sh "./gradlew test"
            }
            
            post {
                always {
                     junit "build/test-results/**/*.xml"
                }

                failure {
                    emailNotification("Test")
                }
            } 
        }

        stage('SonarQube Analysis') {
            when {
                branch 'dev'
            }
            
            steps {
                withSonarQubeEnv("sonarqube-petclinic") {
                    sh "./gradlew sonar"
                }
            }
            post {
                failure {
                    emailNotification("SonarQube Analysis")
                }
            }
        }
        
        stage('Create Infrastructure'){
            when {
                branch 'main'
            }
            
            steps {
                withCredentials([[
                  $class: 'AmazonWebServicesCredentialsBinding',
                  credentialsId: 'my-aws-creds',
                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh "aws configure set aws_session_token '$AWS_SESSION_TOKEN'"
                    
                    dir('IaC/terraform/app-server'){
                        sh''' 
                            terraform init 
                            terraform validate
                            terraform appy -auto-approve
                        '''

                        sh''' 
                            terraform output -raw petclinic-ip >> ../ansible/inventory.txt
                        '''
                    }
                }
                
                archiveArtifacts artifacts: 'IaC/ansible/inventory.txt'
            }

            post {
                failure {
                    emailNotification("Create Infrastructure")
                }
            }
        }
        
        stage('Configure Infrastructure') {
            when {
                branch 'main'
            }
            
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'petclinic-key-pair', keyFileVariable: 'PRIVATE_KEY_FILE')]){
                    dir('IaC/ansible'){
                    sh''' 
                        cat inventory.txt
                    '''
                    sh "ansibe-playbook -i inventory.txt config-server.yml --private-key=$PRIVATE_KEY_FILE"
                    }
                } 
            }

            post {
                failure{
                    emailNotification("Configure Infrastructure")
                }
            }
            
        }
        
        stage('Deploy App') {
            when {
                branch 'main'
            }
            steps {
                sh "./gradlew clean build -DMYSQL_URL=${MYSQL_URL}"
                
                sh "tar -C build -czvf artifact.tar.gz ."
                
                withCredentials([sshUserPrivateKey(credentialsId: 'petclinic-key-pair', keyFileVariable: 'PRIVATE_KEY_FILE')]){
                    dir('IaC/ansible'){
                        sh "cat inventory.txt"
                        sh "ansibe-playbook -i inventory.txt deploy-app.yml --private-key=$PRIVATE_KEY_FILE"
                    }
                } 
            }
            post {
                failure {
                    emailNotification("Deploy App")
                }
            }
        }
    }
}
