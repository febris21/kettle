
pipeline {

    agent any

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
            description: 'Skip unit tests'
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

                script {

                    if (!params.GIT_REF.matches(
                        '[A-Za-z0-9._/-]+'
                    )) {
                        error(
                            'Invalid GIT_REF: ' +
                            params.GIT_REF
                        )
                    }

                }

                sh '''
                    set -eu

                    echo "Checking Docker..."

                    docker version

                    echo "Checking Git..."

                    git --version

                    echo "Checking workspace..."

                    df -h .

                    echo "Preflight completed."
                '''
            }
        }

        // 2. 下载 Kettle 源码
        stage('Checkout Kettle') {

            steps {

                sh '''
                    set -eu

                    rm -rf src

                    echo "Cloning Kettle source..."

                    git clone \
                        --depth 1 \
                        --branch "$GIT_REF" \
                        "$KETTLE_REPO" \
                        src

                    cd src

                    echo "Source revision:"

                    git log -1 --oneline

                    echo "Checking pom.xml..."

                    test -f pom.xml

                    echo "Checkout completed."
                '''
            }
        }

        // 3. 构建 Docker Builder 镜像
        stage('Build Builder Image') {

            steps {

                sh '''
                    set -eu

                    echo "Building Docker image..."

                    docker build \
                        --pull \
                        -t "$BUILDER_IMAGE" \
                        .

                    echo "Builder image ready."
                '''
            }
        }

        // 4. 创建 Maven 缓存
        stage('Prepare Maven Cache') {

            steps {

                sh '''
                    set -eu

                    echo "Creating Maven volume..."

                    docker volume create \
                        "$MAVEN_VOLUME"

                    echo "Maven cache ready."
                '''
            }
        }

        // 5. 创建编译容器
        stage('Create Builder Container') {

            steps {

                sh '''
                    set -eu

                    echo "Removing previous container..."

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

                    echo "Builder container started."
                '''
            }
        }

        // 6. 复制源码和 Maven 配置
        stage('Prepare Build Environment') {

            steps {

                withCredentials([
                    file(
                        credentialsId: 'pentaho-maven-settings',
                        variable: 'MAVEN_SETTINGS_FILE'
                    )
                ]) {

                    sh '''
                        set -eu

                        echo "Copying source code..."

                        docker cp \
                            src/. \
                            "$KETTLE_CONTAINER:/workspace/src/"

                        echo "Copying Maven settings..."

                        docker cp \
                            "$MAVEN_SETTINGS_FILE" \
                            "$KETTLE_CONTAINER:/tmp/settings.xml"

                        echo "Checking Java..."

                        docker exec \
                            "$KETTLE_CONTAINER" \
                            java -version

                        echo "Checking Maven..."

                        docker exec \
                            "$KETTLE_CONTAINER" \
                            mvn -version

                        echo "Build environment ready."
                    '''
                }
            }
        }

        // 7. 编译和打包
        stage('Compile Kettle') {

            steps {

                withCredentials([
                    file(
                        credentialsId: 'pentaho-maven-settings',
                        variable: 'MAVEN_SETTINGS_FILE'
                    )
                ]) {

                    script {

                        def testArgs = params.SKIP_TESTS
                            ? '-DskipTests'
                            : ''

                        withEnv([
                            "MAVEN_TEST_ARGS=${testArgs}"
                        ]) {

                            sh '''
                                set -eu

                                echo "Starting Kettle build..."

                                docker exec \
                                    -e MAVEN_OPTS="-Xms512m -Xmx3g -Dfile.encoding=UTF-8" \
                                    -e MAVEN_TEST_ARGS="$MAVEN_TEST_ARGS" \
                                    "$KETTLE_CONTAINER" \
                                    bash -lc '
                                        set -e

                                        mvn \
                                            -B \
                                            -ntp \
                                            clean \
                                            package \
                                            $MAVEN_TEST_ARGS \
                                            -s /tmp/settings.xml
                                    '

                                echo "Kettle build completed."
                            '''
                        }
                    }
                }
            }
        }

        // 8. 检查构建结果
        stage('Verify Build') {

            steps {

                sh '''
                    set -eu

                    echo "Checking Kettle package..."

                    docker exec \
                        "$KETTLE_CONTAINER" \
                        bash -lc '
                            find assemblies/client/target \
                                -maxdepth 1 \
                                -type f \
                                -name "pdi-ce-*.zip" \
                                -print \
                                -quit | grep -q .
                        '

                    echo "Kettle package found."
                '''
            }
        }

        // 9. 收集编译产物
        stage('Collect Artifacts') {

            steps {

                sh '''
                    set -eu

                    rm -rf dist

                    mkdir -p dist

                    echo "Copying build artifacts..."

                    docker cp \
                        "$KETTLE_CONTAINER:/workspace/src/assemblies/client/target/." \
                        dist/

                    FOUND=0

                    for f in dist/pdi-ce-*.zip; do

                        [ -f "$f" ] || continue

                        echo "Validating $f"

                        unzip -t "$f" >/dev/null

                        FOUND=1

                    done

                    if [ "$FOUND" -ne 1 ]; then

                        echo "ERROR: No valid Kettle ZIP found!"

                        exit 1

                    fi

                    cd dist

                    sha256sum pdi-ce-*.zip > SHA256SUMS

                    echo "Final artifacts:"

                    ls -lh

                    echo "Artifact collection completed."
                '''
            }
        }

        // 10. Jenkins 归档
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
            KETTLE 9.4 BUILD SUCCESS
            ====================================
            '''
        }

        failure {

            echo '''
            ====================================
            KETTLE 9.4 BUILD FAILED
            Please check Maven build logs.
            ====================================
            '''
        }

        always {
            script {
                if (currentBuild.currentResult == 'FAILURE') {
                    echo 'Build failed. Keeping diagnostic information.'

                    sh '''
                        echo "========== Docker Container =========="

                        docker ps -a \
                            --filter "name=$KETTLE_CONTAINER"

                        echo "========== Container Logs =========="

                        docker logs "$KETTLE_CONTAINER" 2>&1 || true

                        echo "========== Container Inspection =========="

                        docker inspect "$KETTLE_CONTAINER" \
                            --format '{{.State.Status}}'
                    '''
                } else {
                    sh '''
                        docker rm -f \
                            "$KETTLE_CONTAINER" \
                            >/dev/null 2>&1 || true
                    '''
                }
            }
        }
    }
}
