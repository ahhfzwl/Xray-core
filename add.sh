#!/bin/sh

# PVE LXC Alpine Xray 安装脚本
# 使用 vless+ws 协议
# UUID: 11112222-3333-4444-aaaa-bbbbccccdddd

# 定义变量
UUID="11112222-3333-4444-aaaa-bbbbccccdddd"
PORT=443
TLS_ENABLED=false
CERT_PATH="/etc/xray/cert.pem"
KEY_PATH="/etc/xray/key.pem"
XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/v1.8.3/Xray-linux-64.zip"

# 函数：显示菜单
show_menu() {
    echo "请选择操作:"
    echo "1. 安装 Xray"
    echo "2. 更新 Xray"
    echo "3. 卸载 Xray"
    echo "4. 退出"
}

# 函数：安装 Xray
install_xray() {
    echo "开始安装 Xray..."
    apk update
    apk add --no-cache unzip openrc

    # 下载并解压 Xray
    mkdir -p /usr/local/bin
    curl -L $XRAY_URL -o /tmp/xray.zip
    unzip /tmp/xray.zip -d /usr/local/bin/

    # 创建配置文件目录
    mkdir -p /etc/xray

    # 创建 Xray 配置文件
    cat <<EOF > /etc/xray/config.json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": $PORT,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "$CERT_PATH",
              "keyFile": "$KEY_PATH"
            }
          ]
        },
        "wsSettings": {
          "path": "/vless"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

    # 生成自签证书
    if $TLS_ENABLED; then
        mkdir -p /etc/xray
        openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/CN=your_domain" -keyout $KEY_PATH -out $CERT_PATH
    fi

    # 创建 openrc 服务文件
    mkdir -p /etc/init.d
    cat <<EOF > /etc/init.d/xray
#!/sbin/runscript

start() {
    ebegin "Starting Xray"
    /usr/local/bin/xray -config /etc/xray/config.json
    eend $?
}

stop() {
    ebegin "Stopping Xray"
    pkill xray
    eend $?
}
EOF
    chmod +x /etc/init.d/xray

    # 启动并启用 Xray 服务
    rc-update add xray default
    rc-service xray start

    echo "Xray 安装完成，端口: $PORT, UUID: $UUID"
}

# 函数：更新 Xray
update_xray() {
    echo "开始更新 Xray..."
    apk update
    apk upgrade --no-cache unzip

    # 下载并解压最新的 Xray
    mkdir -p /usr/local/bin
    curl -Ls $XRAY_URL -o /tmp/xray.zip
    unzip /tmp/xray.zip -d /usr/local/bin/

    # 重启 Xray 服务
    rc-service xray restart

    echo "Xray 更新完成"
}

# 函数：卸载 Xray
uninstall_xray() {
    echo "开始卸载 Xray..."
    rc-service xray stop
    rc-update del xray default
    rm -rf /usr/local/bin/xray
    rm -rf /etc/xray
    rm -rf /etc/init.d/xray

    echo "Xray 卸载完成"
}

# 主程序
while true; do
    show_menu
    read -p "请输入选项 (1-4): " choice
    case $choice in
        1)
            install_xray
            ;;
        2)
            update_xray
            ;;
        3)
            uninstall_xray
            ;;
        4)
            echo "退出脚本"
            exit 0
            ;;
        *)
            echo "无效选项，请重新输入"
            ;;
    esac
done
