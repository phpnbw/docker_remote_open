#!/bin/bash

# 设置默认端口和参数
DEFAULT_PORT=2375
UPDATE_SYSTEM=false
PORT=$DEFAULT_PORT

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 获取系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
elif [ -f /etc/redhat-release ]; then
    OS="centos"
else
    echo "不支持的操作系统"
    exit 1
fi

# 处理参数
while getopts "u" opt; do
    case $opt in
        u)
            UPDATE_SYSTEM=true
            ;;
        *)
            echo "用法: $0 [-u] [端口号]"
            echo "  -u  更新系统"
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

# 如果有额外参数，设置为端口号
if [ $# -gt 0 ]; then
    if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; then
        PORT=$1
    else
        echo "错误：端口号必须是 1-65535 之间的数字"
        exit 1
    fi
fi

# 显示配置信息
echo "配置信息："
echo "- 端口: $PORT"
echo "- 系统更新: $UPDATE_SYSTEM"

# 更新系统
if [ "$UPDATE_SYSTEM" = true ]; then
    echo "正在更新系统..."
    case $OS in
        "debian"|"ubuntu")
            apt update && apt upgrade -y
            ;;
        "centos")
            yum update -y
            ;;
        *)
            echo "不支持的操作系统"
            exit 1
            ;;
    esac
fi

# 检查并安装curl
if ! command -v curl &> /dev/null; then
    echo "正在安装curl..."
    case $OS in
        "debian"|"ubuntu")
            apt install -y curl
            ;;
        "centos")
            yum install -y curl
            ;;
    esac
fi

# 检查Docker是否已安装
if ! command -v docker &> /dev/null; then
    echo "正在安装Docker..."
    curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
    
    # 启动Docker服务
    systemctl start docker
    systemctl enable docker
fi

# 配置Docker Remote API
echo "配置Docker Remote API 在端口 $PORT ..."

# 备份原有的 daemon.json
if [ -f /etc/docker/daemon.json ]; then
    cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
fi

# 创建或更新 daemon.json
mkdir -p /etc/docker
if [ -f /etc/docker/daemon.json ]; then
    # 如果文件存在，保留现有配置并添加 hosts
    tmp_config=$(mktemp)
    if ! command -v jq &> /dev/null; then
        echo "安装 jq..."
        case $OS in
            "debian"|"ubuntu")
                apt install -y jq
                ;;
            "centos")
                yum install -y jq
                ;;
        esac
    fi
    jq --arg port "$PORT" '. + {"hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:" + $port]}' /etc/docker/daemon.json > "$tmp_config"
    mv "$tmp_config" /etc/docker/daemon.json
else
    # 如果文件不存在，创建新配置
    cat > /etc/docker/daemon.json << EOF
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:$PORT"]
}
EOF
fi

# 删除可能存在的 systemd override 配置
rm -rf /etc/systemd/system/docker.service.d

# 修改 Docker 服务配置
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd
EOF

# 重启Docker服务
systemctl daemon-reload
systemctl restart docker

# 检查Docker是否成功重启
if ! systemctl is-active docker >/dev/null 2>&1; then
    echo "Docker启动失败，正在回滚配置..."
    # 恢复daemon.json
    if [ -f /etc/docker/daemon.json.bak ]; then
        mv /etc/docker/daemon.json.bak /etc/docker/daemon.json
    else
        rm -f /etc/docker/daemon.json
    fi
    
    systemctl daemon-reload
    systemctl restart docker
    
    echo "配置已回滚，请检查Docker日志以获取更多信息："
    echo "journalctl -xu docker.service"
    exit 1
fi

# 配置防火墙
echo "配置防火墙..."
case $OS in
    "debian"|"ubuntu")
        if command -v ufw &> /dev/null; then
            ufw allow $PORT/tcp
            ufw reload
        fi
        ;;
    "centos")
        if command -v firewall-cmd &> /dev/null; then
            firewall-cmd --zone=public --add-port=$PORT/tcp --permanent
            firewall-cmd --reload
        fi
        ;;
esac

# 验证Docker Remote API是否可访问
echo "验证Docker Remote API..."
curl http://localhost:$PORT/version &> /dev/null
if [ $? -eq 0 ]; then
    echo "Docker Remote API 配置成功！"
    echo "API 地址: http://YOUR_SERVER_IP:$PORT"
else
    echo "Docker Remote API 配置可能存在问题，请检查配置"
fi

# 输出安全警告
echo "警告：Docker Remote API 现在可以从外部访问，请确保配置适当的安全措施！" 
