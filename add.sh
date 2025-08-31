#!/bin/bash
set -e

UUID="11112222-3333-4444-aaaa-bbbbccccdddd"
XRAY_BIN="/usr/local/bin/xray"
CONFIG_DIR="/etc/xray"

show_step() {
  echo -e "\n[步骤] $1 ..."
  sleep 1
}

# 卸载功能
if [ "$1" = "uninstall" ]; then
  show_step "停止 Xray 服务"
  systemctl stop xray 2>/dev/null || true
  show_step "删除文件"
  rm -rf $XRAY_BIN $CONFIG_DIR /etc/systemd/system/xray.service
  systemctl daemon-reload
  echo "✅ Xray 已卸载完成"
  exit 0
fi

# 选择协议
echo "请选择协议类型："
echo "1) vless"
echo "2) vmess"
read -p "输入数字 (默认 1): " PROTO_OPT
case "$PROTO_OPT" in
  2) PROTO="vmess" ;;
  *) PROTO="vless" ;;
esac

# 输入端口
read -p "请输入服务端口 [默认 443]：" PORT
PORT=${PORT:-443}

# 是否启用 TLS
echo "是否启用 TLS？"
echo "1) 启用 (自签证书)"
echo "2) 不启用"
read -p "输入数字 (默认 2): " TLS_OPT
case "$TLS_OPT" in
  1) USE_TLS=1 ;;
  *) USE_TLS=0 ;;
esac

# 安装依赖
show_step "安装依赖 (curl unzip openssl)"
if command -v apt >/dev/null 2>&1; then
  apt update && apt install -y curl unzip openssl
elif command -v yum >/dev/null 2>&1; then
  yum install -y curl unzip openssl
elif command -v apk >/dev/null 2>&1; then
  apk add --no-cache curl unzip openssl
else
  echo "未知的包管理器，请手动安装 curl unzip openssl"
  exit 1
fi

# 获取最新版本
show_step "获取 Xray 最新版本"
VER=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep tag_name | cut -d '"' -f4)
echo "最新版本: $VER"

# 下载并安装
show_step "下载并安装 Xray"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="64" ;;
  aarch64) ARCH="arm64-v8a" ;;
  armv7l) ARCH="arm32-v7a" ;;
  *) echo "不支持的架构: $ARCH" && exit 1 ;;
esac

cd /tmp
curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/download/$VER/Xray-linux-$ARCH.zip
unzip -o xray.zip
install -m 755 xray $XRAY_BIN

# 配置目录
show_step "生成配置文件"
mkdir -p $CONFIG_DIR

TLS_JSON=""
if [ "$USE_TLS" -eq 1 ]; then
  mkdir -p $CONFIG_DIR/certs
  openssl req -new -x509 -days 3650 -nodes -subj "/CN=xray.local" \
    -out $CONFIG_DIR/certs/cert.pem -keyout $CONFIG_DIR/certs/key.pem
  TLS_JSON=$(cat <<EOF
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "tlsSettings": {
        "certificates": [
          {
            "certificateFile": "$CONFIG_DIR/certs/cert.pem",
            "keyFile": "$CONFIG_DIR/certs/key.pem"
          }
        ]
      },
      "wsSettings": {
        "path": "/"
      }
    }
EOF
)
else
  TLS_JSON=$(cat <<EOF
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "/"
      }
    }
EOF
)
fi

cat >$CONFIG_DIR/config.json <<EOF
{
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "$PROTO",
      "settings": {
        "clients": [
          { "id": "$UUID" }
        ]
      },
      $TLS_JSON
    }
  ],
  "outbounds": [
    { "protocol": "freedom" }
  ]
}
EOF

# systemd 服务
show_step "创建 systemd 服务"
cat >/etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=$XRAY_BIN -config $CONFIG_DIR/config.json
Restart=on-failure
User=root
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
show_step "启动 Xray 服务"
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

echo -e "\n✅ Xray $VER 安装完成！"
echo "协议：$PROTO + WS"
echo "端口：$PORT"
echo "UUID：$UUID"
if [ "$USE_TLS" -eq 1 ]; then
  echo "TLS：启用 (自签证书)"
else
  echo "TLS：未启用"
fi
echo "配置文件位置：$CONFIG_DIR/config.json"
echo "卸载请执行：bash $0 uninstall"
