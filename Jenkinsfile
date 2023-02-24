def destroyInfra() {
    withCredentials([[
                  $class: 'AmazonWebServicesCredentialsBinding',
                  credentialsId: 'my-aws-creds',
                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]){
                    sh "aws configure set aws_session_token '$AWS_SESSION_TOKEN'"
                    
                    dir("IaC/terraform/app-server"){
                        sh '''
                            terraform init
                            terraform destroy -var "buildID=${BUILD_ID}" -var "AMItoUse=ami-0557a15b87f6559cf" -auto-approve
                        '''
                    }
                }
}

pipeline {
    agent {
        label "docker-spring"
    } 

    stages {
        stage ('Build') {
            when { branch 'dev' }
            
            steps {
                sh "./gradlew build"
            }

            post {
                failure {
                    emailext body: "The Build has failed. Please check the build log for details.",
                             subject: "Build Failed",
                             to: "$MY_EMAIL"
                }
            }
        }

        stage ('Test') {
            when { branch 'dev' }
            
            steps {
                sh "./gradlew test"
            }
            
            post {
                always {
                     junit "build/test-results/**/*.xml"
                }

                failure {
                    emailext body: "The Test has failed. Please check the build log for details.",
                             subject: "Test Failed",
                             to: "$MY_EMAIL"
                }
            } 
        }

        stage('SonarQube Analysis') {
            when { branch 'dev' }
            
            steps {
                withSonarQubeEnv("sonarqube-petclinic") {
                    sh "./gradlew sonar"
                }
            }
            post {
                failure {
                    emailext body: "The SonarQube Analysis has failed. Please check the build log for details.",
                             subject: "SonarQube Analysis Failed",
                             to: "$MY_EMAIL"
                }
            }
        }
        
        stage('Create Infrastructure'){
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
                            terraform apply -var "buildID=${BUILD_ID}" -var "AMItoUse=ami-0557a15b87f6559cf" -auto-approve
                        '''

                        sh''' 
                            terraform output -raw petclinic-ip >> ../../ansible/inventory.txt
                        '''
                    }
                }
                
                archiveArtifacts artifacts: 'IaC/ansible/inventory.txt'
                archiveArtifacts artifacts: 'IaC/terraform/app-server/terraform.tfstate'
            }

            post {
                failure {
                    script {
                        destroyInfra()

                        emailext body: "The Create Infrastructure has failed. Please check the build log for details.",
                                subject: "Create Infrastructure Failed",
                                to: "$MY_EMAIL"
                    }
                }
            }
        }
        
        stage('Configure Infrastructure') {
            steps {
                sshagent(credentials: ['petclinic_key']) {
                    dir('IaC/ansible'){
                        sh "cat inventory.txt"
                        sh '''
                            ansible-playbook -i inventory.txt config-server.yml
                        '''
                    }
                }
            }

            post {
                failure{
                    script {
                        destroyInfra()
                    
                        emailext body: "The Configure Infrastructure has failed. Please check the build log for details.",
                                subject: "Configure Infrastructure Failed",
                                to: "$MY_EMAIL"
                    }
                }
            }
            
        }
        
        stage('Deploy App') {
            steps {
                sh ''' 
                    ./gradlew clean build -DMYSQL_URL=${MYSQL_URL}
                '''
                
                sh "tar -C build -czvf artifact.tar.gz ."
                
                sshagent(credentials: ['petclinic_key']) {
                    dir('IaC/ansible'){
                        sh "cat inventory.txt"
                        sh '''
                            ansible-playbook -i inventory.txt deploy-app.yml
                        '''
                    }
                } 
            }
            post {
                failure {
                    script {
                        destroyInfra()
                    
                        emailext body: "The Deploy App has failed. Please check the build log for details.",
                                subject: "Deploy App Failed",
                                to: "$MY_EMAIL"
                    }
                }
            }
        }
    }
}
