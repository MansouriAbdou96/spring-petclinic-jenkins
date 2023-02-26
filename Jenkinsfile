def destroyInfra() {
    withCredentials([[
                  $class: 'AmazonWebServicesCredentialsBinding',
                  credentialsId: 'my-aws-creds',
                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]){
                    sh '''
                        aws configure set aws_session_token '$AWS_SESSION_TOKEN'
                        aws configure set region us-east-1
                    '''
                    
                    dir("IaC/terraform/app-server"){
                        sh ''' 
                            aws s3 cp s3://petclinic-mybucket/petclinic-${BUILD_ID}/terraform.tfstate .
                        '''
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
                    sh '''
                        aws configure set aws_session_token '$AWS_SESSION_TOKEN'
                        aws configure set region us-east-1
                    '''
                    
                    dir('IaC/terraform/app-server'){
                        sh''' 
                            terraform init 
                            terraform validate
                            terraform apply -var "buildID=${BUILD_ID}" -var "AMItoUse=ami-0557a15b87f6559cf" -auto-approve
                        '''

                        sh''' 
                            terraform output -raw petclinic-ip >> ../../ansible/inventory.txt
                        '''

                        sh ''' 
                            aws s3api put-object --bucket petclinic-mybucket --key petclinic-${BUILD_ID}
                            aws s3 cp terraform.tfstate s3://petclinic-mybucket/petclinic-${BUILD_ID}/
                        '''
                    }
                }
                
                archiveArtifacts artifacts: 'IaC/ansible/inventory.txt'
                // archiveArtifacts artifacts: 'IaC/terraform/app-server/terraform.tfstate'
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
                        sh "cat inventory.txt && sleep 60"
                        sh '''
                            ansible-playbook -i inventory.txt config-server.yml
                        '''
                    }
                }
            }

            // post {
            //     failure{
            //         script {
            //             destroyInfra()
                    
            //             emailext body: "The Configure Infrastructure has failed. Please check the build log for details.",
            //                     subject: "Configure Infrastructure Failed",
            //                     to: "$MY_EMAIL"
            //         }
            //     }
            // }
            
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
            // post {
            //     failure {
            //         script {
            //             destroyInfra()
                    
            //             emailext body: "The Deploy App has failed. Please check the build log for details.",
            //                     subject: "Deploy App Failed",
            //                     to: "$MY_EMAIL"
            //         }
            //     }
            // }
        }

        stage('Smoke Test'){
            steps {
                dir('IaC/terraform/app-server'){
                    sh 'terraform init'

                    sh ''' 
                        export SERVER_IP=$(terraform output -raw petclinic-ip)

                        export URL="http://${SERVER_IP}:8080"
                        echo "${URL}"

                        # Set maximum number of retries
                        MAX_RETRIES=10
                        RETRY_COUNT=0

                        # Wait for API to be ready
                        while true; do
                            if curl -I "${URL}" | grep "HTTP/1.1 2.."; then
                                break
                            fi
                            RETRY_COUNT=$((RETRY_COUNT + 1))
                            if [ ${RETRY_COUNT} -eq ${MAX_RETRIES} ]; then
                                echo "Website URL is not ready after ${MAX_RETRIES} retries."
                                exit 1
                            fi
                            # Wait for 5 seconds before retrying
                            sleep 5
                        done
                    '''
                }
            }   

            post{
                // failure {
                //     script {
                //         destroyInfra() 

                //         emailext body: "The Smoke Test has failed. Please check the build log for details.",
                //                 subject: "Smoke Test Failed",
                //                 to: "$MY_EMAIL"
                //     }
                // }
                success {
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'my-aws-creds',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]){
                        sh '''
                            aws configure set aws_session_token '$AWS_SESSION_TOKEN'
                            aws configure set region us-east-1
                        '''
                        sh ''' 
                            if aws s3 ls s3://petclinic-mybucket/BuildID.txt | grep -q BuildID.txt; then
                                aws s3 cp s3://petclinic-mybucket/BuildID.txt ./prevBuildID.txt
                            else
                                echo "File not found in S3 bucket."
                            fi
                        '''
                        sh''' 
                            echo "$BUILD_ID" > BuildID.txt
                            aws s3 cp BuildID.txt s3://petclinic-mybucket/BuildID.txt
                        '''
                        archiveArtifacts artifacts: "prevBuildID.txt", allowEmptyArchive: true
                    }
                }
            }
        }

        stage('cleanup'){
            steps{
                withCredentials([[
                  $class: 'AmazonWebServicesCredentialsBinding',
                  credentialsId: 'my-aws-creds',
                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]){
                    sh '''
                        aws configure set aws_session_token '$AWS_SESSION_TOKEN'
                        aws configure set region us-east-1
                    '''

                    sh''' 
                        if [[ -f prevBuildID.txt ]]; then
                            cat prevBuildID.txt 2>/dev/null
                        else
                            echo "File not found"
                        fi
                    '''
                    
                    sh '''
                        export PREV_BUILD_ID=$(cat prevBuildID.txt)

                        cd IaC/terraform/app-server 

                        if aws s3 ls "s3://petclinic-mybucket/petclinic-${PREV_BUILD_ID}/" >/dev/null 2>&1; then
                            aws s3 cp "s3://petclinic-mybucket/petclinic-${PREV_BUILD_ID}/terraform.tfstate" .

                            terraform init 

                            terraform destroy -var "buildID=${PREV_BUILD_ID}" -var "AMItoUse=ami-0557a15b87f6559cf" -auto-approve
                        else
                            echo "File not found"
                        fi
                    '''
                }
            }

            post{
                success {
                    echo "The previous build is cleaned up successfully"
                }
            }
        }
    }
}
