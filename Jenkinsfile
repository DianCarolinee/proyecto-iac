pipeline {
    agent any

    environment {
        TF_DIR = "iac"
        AWS_REGION = "us-east-2"
    }

    stages {
        stage('Clonar código') {
            steps {
                git branch: 'main', url: 'https://github.com/TU-USUARIO/TU-REPO.git'
            }
        }

        stage('Empaquetar Lambdas') {
            steps {
                sh '''
                cd auditoria && zip -r ../iac/bin/auditoria.zip . && cd ..
                cd empleado && zip -r ../iac/bin/empleado.zip . && cd ..
                cd nomina && zip -r ../iac/bin/nomina.zip . && cd ..
                cd process && zip -r ../iac/bin/process.zip . && cd ..
                '''
            }
        }

        stage('Terraform Init') {
            steps {
                dir("${TF_DIR}") {
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Plan & Apply') {
            steps {
                dir("${TF_DIR}") {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }
    }
}
