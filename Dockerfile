
# Kettle 9.4 专用编译环境
FROM maven:3.8.8-eclipse-temurin-11

LABEL maintainer="Jenkins"
LABEL description="Pentaho Kettle 9.4 Build Environment"

ENV TZ=UTC
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# 安装基础工具
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       git \
       unzip \
       zip \
       bash \
    && rm -rf /var/lib/apt/lists/*

# Maven 本地仓库
ENV MAVEN_CONFIG=/root/.m2

# 默认 JVM 参数
ENV MAVEN_OPTS="-Xms512m -Xmx3g -Dfile.encoding=UTF-8"

WORKDIR /workspace

CMD ["/bin/bash"]
