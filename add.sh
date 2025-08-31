#!/bin/sh
# Xray 一体化脚本 (Alpine LXC)
# 支持: 安装 / 更新 / 卸载
# 协议: VLESS + WS
# 默认端口: 443
# 默认UUID: 11112222-3333-4444-aaaa-bbbbccccdddd
# 可选 TLS，自签证书

set -e

XRAY_UUID="11112222-3333-4444-aaaa-bbbbccccdddd"
XRAY_PORT=443
ENABLE_TLS=1  # 1=启用TLS, 0=不启用
CONFIG_DIR="/etc/xray"
CONFIG_FILE="$CONFIG_DIR/config.json"
CERT_DIR="/etc/xray/cert"
SERVICE_FILE="/etc/init.d/xray"

print_info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
print_error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# 检查依赖
check_dependencies() {
    print_info "检查依赖..."
    apk update
    deps="curl wget tar unzip socat openssl"
    for pkg in $deps; do
        if ! apk info | grep -q "^$pkg"; then
            print_info "安装缺失依赖: $pkg"
            apk add --no-cache $pkg
        fi
    done
}

# 获取最新 Xray 版本并下载 .zip 文件
install_xray() {
    print_info "获取最新 Xray 版本..."
    # 获取 release 页面下载链接，只匹配 linux-64.zip
    XRAY_URL=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest \
        | grep browser_download_url \
        | grep 'Xray-linux-64.zip"' \
        | cut -d '"' -f 4)
    print_info "下载 Xray: $XRAY_URL"
    wget -O /tmp/xray.zip "$XRAY_URL"
    unzip -o /tmp/xray.zip -d /tmp/xray
    install -m 755 /tmp/xray/xray /usr/local/bin/xray
    mkdir -p "$CONFIG_DIR" "$CERT_DIR"
    print_info "Xray 安装完成"
}

# 生成自签证书
generate_cert() {
    print_info "生成自签证书..."
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout "$CERT_DIR/private.key" \
        -out "$CERT_DIR/cert.crt" \
        -subj "/CN=localhost"
}

# 写配置文件
write_config() {
    print_info "生成 Xray 配置文件..."
    if [ "$ENABLE_TLS" -eq 1 ]; then
        TLS_BLOCK="
      \"tls\": {
        \"certificates\": [
          {
            \"certificateFile\": \"$CERT_DIR/cert.crt\",
            \"keyFile\": \"$CERT_DIR/private.key\"
          }
        ]
      },"
    else
        TLS_BLOCK=""
    fi

    cat > "$CONFIG_FILE" <<EOF
{
  "log": {
    "loglevel": "info"
  },
  "inbounds": [
    {
      "port": $XRAY_PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$XRAY_UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        $TLS_BLOCK
        "wsSettings": {
          "path": "/"
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
}

# 创建 OpenRC 服务
create_service() {
    print_info "创建 Xray 服务..."
    cat > "$SERVICE_FILE" <<'EOF'
#!/sbin/openrc-run
name="xray"
command="/usr/local/bin/xray"
command_args="-config /etc/xray/config.json"
command_background=true
pidfile="/var/run/xray.pid"
EOF
    chmod +x "$SERVICE_FILE"
    rc-update add xray default
}

start_xray() {
    print_info "启动 Xray..."
    rc-service xray start || print_error "启动失败"
}

stop_xray() {
    print_info "停止 Xray..."
    rc-service xray stop || print_error "停止失败"
}

uninstall_xray() {
    print_info "卸载 Xray..."
    stop_xray
    rc-update del xray
    rm -f /usr/local/bin/xray
    rm -rf "$CONFIG_DIR" "$CERT_DIR" "$SERVICE_FILE"
    print_info "卸载完成"
}

update_xray() {
    print_info "更新 Xray..."
    stop_xray
    install_xray
    start_xray
}

show_menu() {
    echo "================ Xray Alpine 一体化脚本 ================"
    echo "1) 安装 Xray"
    echo "2) 更新 Xray"
    echo "3) 卸载 Xray"
    echo "4) 启动 Xray"
    echo "5) 停止 Xray"
    echo "6) 修改端口 (当前: $XRAY_PORT)"
    echo "7) 启用/禁用 TLS (当前: $( [ $ENABLE_TLS -eq 1 ] && echo 启用 || echo 禁用 ))"
    echo "0) 退出"
    echo "======================================================="
    read -p "请输入选项: " choice
    case $choice in
        1)
            check_dependencies
            install_xray
            [ $ENABLE_TLS -eq 1 ] && generate_cert
            write_config
            create_service
            start_xray
            ;;
        2) update_xray ;;
        3) uninstall_xray ;;
        4) start_xray ;;
        5) stop_xray ;;
        6) read -p "请输入新端口: " newport; XRAY_PORT=$newport; echo "端口已修改为 $XRAY_PORT" ;;
        7) ENABLE_TLS=$((1-ENABLE_TLS)); echo "TLS状态切换完成: $( [ $ENABLE_TLS -eq 1 ] && echo 启用 || echo 禁用 )" ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
}

while true; do
    show_menu
done
