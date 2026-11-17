
FROM eclipse-temurin:11-jre-jammy

ENV PDI_HOME=/opt/kettle/data-integration \
    KETTLE_HOME=/opt/kettle/.kettle \
    TZ=Asia/Shanghai \
    PENTAHO_DI_JAVA_OPTIONS="-Xms512m -Xmx2048m -Duser.timezone=Asia/Shanghai"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      unzip \
      curl \
      ca-certificates \
      tzdata && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -g 1000 kettle && \
    useradd -m -u 1000 -g kettle -s /bin/bash kettle && \
    mkdir -p \
      /opt/kettle/.kettle \
      /opt/kettle/jobs \
      /opt/kettle/transformations \
      /opt/kettle/drivers \
      /opt/kettle/logs

COPY pdi-ce-9.4.0.0-343.zip /tmp/pdi.zip

RUN unzip -q /tmp/pdi.zip -d /opt/kettle && \
    test -f /opt/kettle/data-integration/carte.sh && \
    test -f /opt/kettle/data-integration/pan.sh && \
    test -f /opt/kettle/data-integration/kitchen.sh && \
    chmod +x /opt/kettle/data-integration/*.sh && \
    rm -f /tmp/pdi.zip

COPY carte-config.xml /opt/kettle/carte-config.xml
COPY kettle.properties /opt/kettle/.kettle/kettle.properties
COPY kettle.pwd /opt/kettle/.kettle/kettle.pwd
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# JDBC驱动目录中的JAR复制到PDI lib
COPY drivers/ /opt/kettle/data-integration/lib/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    chmod 600 /opt/kettle/.kettle/kettle.pwd && \
    chown -R kettle:kettle /opt/kettle && \
    chmod 755 /opt/kettle/data-integration/*.sh

ENV PATH="/opt/kettle/data-integration:${PATH}"

WORKDIR /opt/kettle/data-integration

EXPOSE 8080

USER kettle

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
