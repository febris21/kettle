pipeline {
    agent { label 'docker' }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {
        stage('Prepare Directories') {
            steps {
                sh '''
                    set -e

                    mkdir -p ~/compose/kettle-docker
                    cd ~/compose/kettle-docker

                    mkdir -p drivers

                    sudo mkdir -p /opt/kettle/jobs
                    sudo mkdir -p /opt/kettle/transformations
                    sudo mkdir -p /opt/kettle/logs
                    sudo mkdir -p /opt/kettle/drivers

                    sudo chown -R 1000:1000 /opt/kettle

                    echo "Directory preparation completed."
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                dir('kettle-docker') {
                    sh '''
                        set -e

                        docker build -t kettle:9.4 .

                        echo "========== Docker Images =========="

                        docker images kettle:9.4
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Kettle 9.4 Docker image built successfully.'
        }

        failure {
            echo 'Kettle 9.4 Docker build failed.'
        }
    }
}