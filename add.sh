#!/bin/sh
set -e

UUID="11112222-3333-4444-aaaa-bbbbccccdddd"

menu() {
  echo "=========================="
  echo " Xray 管理脚本"
  echo "=========================="
  echo "1) 安装/更新 Xray"
  echo "2) 卸载 Xray"
  echo "=========================="
  read -p "请选择 [1-2]: " OPT
}

detect_pkg_mgr() {
  if command -v apk >/dev/null 2>&1; then
    PKG="apk add --no-cache"
  elif command -v apt-get >/dev/null 2>&1; then
    PKG="apt-get update && apt-get install -y"
  elif command -v yum >/dev/null 2>&1; then
    PKG="yum install -y"
  else
    echo "❌ 未检测到可用的包管理器"
    exit 1
  fi
}

detect_arch() {
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)   ARCH_TAG="64" ;;
    aarch64)  ARCH_TAG="arm64-v8a" ;;
    armv7l)   ARCH_TAG="arm32-v7a" ;;
    i386|i686) ARCH_TAG="32" ;;
    *) echo "❌ 不支持的架构: $ARCH"; exit 1 ;;
  esac
}

install_xray() {
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
  read -p "请输入服务端监听端口 [默认: 443]：" PORT
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
  detect_pkg_mgr
  $PKG curl unzip openssl >/dev/null 2>&1 || true

  # 获取最新版号
  VER=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep tag_name | cut -d '"' -f4)

  # 检测架构
  detect_arch

  # 下载并安装 Xray
  cd /tmp
  curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/download/$VER/Xray-linux-$ARCH_TAG.zip
  unzip -o xray.zip xray -d /usr/local/bin/
  chmod +x /usr/local/bin/xray

  # 配置目录
  mkdir -p /etc/xray

  # TLS 证书
  TLS_JSON=""
  if [ "$USE_TLS" -eq 1 ]; then
    mkdir -p /etc/xray/certs
    openssl req -new -x509 -days 3650 -nodes -subj "/CN=xray.local" \
      -out /etc/xray/certs/cert.pem -keyout /etc/xray/certs/key.pem
    TLS_JSON=$(cat <<EOF
,
      "tlsSettings": {
        "certificates": [
          {
            "certificateFile": "/etc/xray/certs/cert.pem",
            "keyFile": "/etc/xray/certs/key.pem"
          }
        ]
      }
EOF
)
  fi

  # 写配置文件
  cat >/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "info"
  },
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "$PROTO",
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/"
        }$TLS_JSON
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    },
    {
      "protocol": "blackhole"
    }
  ]
}
EOF

  # 判断 init 系统 (systemd / openrc)
  if command -v systemctl >/dev/null 2>&1; then
    # systemd
    cat >/etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray -config /etc/xray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable xray
    systemctl restart xray
  else
    # openrc
    cat >/etc/init.d/xray <<'EOF'
#!/sbin/openrc-run
command="/usr/local/bin/xray"
command_args="-config /etc/xray/config.json"
pidfile="/run/xray.pid"
command_background="yes"

depend() {
    need net
}
EOF
    chmod +x /etc/init.d/xray
    rc-update add xray default
    rc-service xray restart
  fi

  # 输出信息
  echo "✅ Xray $VER 已安装并设置开机自启"
  echo "协议：$PROTO + WS"
  if [ "$USE_TLS" -eq 1 ]; then
    echo "TLS：启用 (自签证书 /etc/xray/certs/)"
  else
    echo "TLS：未启用"
  fi
  echo "端口：$PORT"
  echo "UUID：$UUID"
}

uninstall_xray() {
  echo "⏳ 正在卸载 Xray ..."
  if command -v systemctl >/dev/null 2>&1; then
    systemctl stop xray || true
    systemctl disable xray || true
    rm -f /etc/systemd/system/xray.service
    systemctl daemon-reload
  else
    rc-service xray stop || true
    rc-update del xray || true
    rm -f /etc/init.d/xray
  fi
  rm -f /usr/local/bin/xray
  rm -rf /etc/xray
  echo "✅ Xray 已卸载完成"
}

# 主菜单
menu
if [ "$OPT" = "1" ]; then
  install_xray
elif [ "$OPT" = "2" ]; then
  uninstall_xray
else
  echo "❌ 输入错误，退出。"
  exit 1
fi
