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
    apk add --no-cache xray

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

    # 启动 Xray 服务
    rc-update add xray default
    rc-service xray start

    echo "Xray 安装完成，端口: $PORT, UUID: $UUID"
}

# 函数：更新 Xray
update_xray() {
    echo "开始更新 Xray..."
    apk update
    apk upgrade --no-cache xray

    echo "Xray 更新完成"
}

# 函数：卸载 Xray
uninstall_xray() {
    echo "开始卸载 Xray..."
    rc-service xray stop
    rc-update del xray default
    apk del xray

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
