
#!/bin/bash
set -e

export PDI_HOME=/opt/kettle/data-integration
export KETTLE_HOME=/opt/kettle/.kettle

# JVM参数
export PENTAHO_DI_JAVA_OPTIONS="${PENTAHO_DI_JAVA_OPTIONS:--Xms512m -Xmx2048m -Duser.timezone=Asia/Shanghai}"

# 确认安装
if [ ! -f "$PDI_HOME/carte.sh" ]; then
    echo "ERROR: Kettle installation not found!"
    exit 1
fi

# 确认配置
if [ ! -f "/opt/kettle/carte-config.xml" ]; then
    echo "ERROR: Carte config not found!"
    exit 1
fi

echo "=================================="
echo "Pentaho Kettle 9.4"
echo "PDI_HOME=$PDI_HOME"
echo "KETTLE_HOME=$KETTLE_HOME"
echo "Starting Carte Server..."
echo "=================================="

cd "$PDI_HOME"

exec ./carte.sh /opt/kettle/carte-config.xml
