
pipeline {

    agent {
        label 'docker'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 180, unit: 'MINUTES')
        buildDiscarder(logRotator(
            numToKeepStr: '10',
            artifactNumToKeepStr: '10'
        ))
    }

    parameters {

        string(
            name: 'GIT_REF',
            defaultValue: '9.4.0.0-343',
            description: 'Kettle Git Tag / Branch'
        )

        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: true,
            description: '跳过单元测试'
        )
    }

    environment {

        KETTLE_REPO =
            'https://github.com/pentaho/pentaho-kettle.git'

        BUILDER_IMAGE =
            'local/kettle-builder:9.4'

        MAVEN_VOLUME =
            'kettle-m2-9.4'

        KETTLE_CONTAINER =
            "kettle94-${BUILD_NUMBER}"
    }

    stages {

        // 1. 检查构建环境
        stage('Preflight') {

            steps {

                sh '''
                    set -eu

                    echo "Checking Docker..."

                    docker version

                    echo "Checking Git..."

                    git --version

                    echo "Checking workspace..."

                    df -h .
                '''

                script {
                    if (!(params.GIT_REF ==~
                        /[A-Za-z0-9._\\/-]+/)) {
                        error('Invalid GIT_REF')
                    }
                }
            }
        }

        // 2. 下载 Kettle 源码
        stage('Checkout Kettle') {

            steps {

                sh '''
                    set -eu

                    rm -rf src

                    git clone \
                        --depth 1 \
                        --branch "$GIT_REF" \
                        "$KETTLE_REPO" \
                        src

                    echo "Source revision:"

                    cd src

                    git log -1 --oneline

                    echo "Checking pom.xml..."

                    test -f pom.xml
                '''
            }
        }

        // 3. 构建专用 Docker 镜像
        stage('Build Builder Image') {

            steps {

                sh '''
                    set -eu

                    docker build \
                        --pull \
                        -t "$BUILDER_IMAGE" \
                        .
                '''
            }
        }

        // 4. Maven 编译及打包
        stage('Compile Kettle') {

            steps {

                withCredentials([
                    file(
                        credentialsId:
                            'pentaho-maven-settings',
                        variable:
                            'MAVEN_SETTINGS_FILE'
                    )
                ]) {

                    sh '''
                        set -eu

                        echo "Creating Maven cache volume..."

                        docker volume create \
                            "$MAVEN_VOLUME" \
                            >/dev/null

                        echo "Cleaning previous container..."

                        docker rm -f \
                            "$KETTLE_CONTAINER" \
                            >/dev/null 2>&1 || true

                        echo "Creating builder container..."

                        docker create \
                            --name "$KETTLE_CONTAINER" \
                            --entrypoint /bin/bash \
                            -v "$MAVEN_VOLUME:/root/.m2" \
                            -w /workspace/src \
                            "$BUILDER_IMAGE" \
                            -lc 'mkdir -p /workspace/src && sleep infinity'

                        docker start "$KETTLE_CONTAINER"

                        echo "Copying source code..."

                        docker cp \
                            src/. \
                            "$KETTLE_CONTAINER:/workspace/src/"

                        echo "Copying Maven settings..."

                        docker cp \
                            "$MAVEN_SETTINGS_FILE" \
                            "$KETTLE_CONTAINER:/tmp/settings.xml"

                        echo "Starting Maven build..."

                        if [ "$SKIP_TESTS" = "true" ]; then

                            docker exec \
                                -e MAVEN_OPTS="-Xms512m -Xmx3g -Dfile.encoding=UTF-8" \
                                "$KETTLE_CONTAINER" \
                                bash -lc \
                                'mvn -B -ntp clean package -DskipTests -s /tmp/settings.xml'

                        else

                            docker exec \
                                -e MAVEN_OPTS="-Xms512m -Xmx3g -Dfile.encoding=UTF-8" \
                                "$KETTLE_CONTAINER" \
                                bash -lc \
                                'mvn -B -ntp clean package -s /tmp/settings.xml'

                        fi

                        echo "Checking build output..."

                        docker exec \
                            "$KETTLE_CONTAINER" \
                            bash -lc \
                            'find assemblies/client/target -maxdepth 1 -type f -name "pdi-ce-*.zip" -print -quit | grep -q .'

                        echo "Build completed."
                    '''
                }
            }
        }

        // 5. 提取构建产物
        stage('Collect Artifacts') {

            steps {

                sh '''
                    set -eu

                    mkdir -p dist

                    docker cp \
                        "$KETTLE_CONTAINER:/workspace/src/assemblies/client/target/." \
                        dist/

                    echo "Checking ZIP files..."

                    FOUND=0

                    for f in dist/pdi-ce-*.zip; do

                        [ -f "$f" ] || continue

                        unzip -t "$f" >/dev/null

                        FOUND=1

                        echo "Validated: $f"

                    done

                    if [ "$FOUND" -ne 1 ]; then
                        echo "No valid Kettle ZIP found!"
                        exit 1
                    fi

                    cd dist

                    sha256sum pdi-ce-*.zip > SHA256SUMS

                    echo "Final artifacts:"

                    ls -lh
                '''
            }
        }

        // 6. Jenkins 归档
        stage('Archive') {

            steps {

                archiveArtifacts(
                    artifacts: 'dist/*',
                    fingerprint: true,
                    allowEmptyArchive: false
                )
            }
        }
    }

    post {

        success {

            echo '''
            ====================================
            KETTLE BUILD SUCCESS
            ====================================
            '''
        }

        failure {

            echo '''
            ====================================
            KETTLE BUILD FAILED
            Please check Maven build logs.
            ====================================
            '''
        }

        always {

            sh '''
                docker rm -f \
                    "$KETTLE_CONTAINER" \
                    >/dev/null 2>&1 || true
            '''

            echo 'Builder container cleaned.'
        }
    }
}
