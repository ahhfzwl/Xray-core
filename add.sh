#!/bin/bash
set -e

UUID="11112222-3333-4444-aaaa-bbbbccccdddd"
XRAY_BIN="/usr/local/bin/xray"
CONFIG_DIR="/etc/xray"
LOG_DIR="/var/log/xray"

show_step() {
  echo -e "\n[步骤] $1 ..."
  sleep 1
}

# 卸载功能
if [ "$1" = "uninstall" ]; then
  show_step "停止 Xray 服务"
  rc-service xray stop 2>/dev/null || true
  
  show_step "删除文件"
  rm -rf $XRAY_BIN $CONFIG_DIR $LOG_DIR /etc/init.d/xray
  rc-update del xray 2>/dev/null || true
  
  echo "✅ Xray 已卸载完成"
  exit 0
fi

# 协议选择
echo "请选择协议类型："
echo "1) vless"
echo "2) vmess"
read -p "输入数字 (默认 1): " PROTO_OPT
case "$PROTO_OPT" in
  2) PROTO="vmess" ;;
  *) PROTO="vless" ;;
esac

# 端口设置
read -p "请输入服务端口 [默认 443]：" PORT
PORT=${PORT:-443}

# TLS 选项
echo "是否启用 TLS？"
echo "1) 启用 (自签证书)"
echo "2) 不启用"
read -p "输入数字 (默认 2): " TLS_OPT
case "$TLS_OPT" in
  1) USE_TLS=1 ;;
  *) USE_TLS=0 ;;
esac

# 安装依赖
show_step "安装依赖"
apk add --no-cache curl unzip openssl libc6-compat
mkdir -p /run/xray $LOG_DIR

# 获取最新版本
show_step "获取 Xray 最新版本"
VER=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep tag_name | cut -d '"' -f4)
echo "最新版本: $VER"

# 下载安装 (使用 musl 静态编译版)
show_step "下载并安装 Xray"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="64" ;;
  aarch64) ARCH="arm64-v8a" ;;
  armv7l) ARCH="arm32-v7a" ;;
  *) echo "不支持的架构: $ARCH" && exit 1 ;;
esac

cd /tmp
curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/download/$VER/Xray-linux-$ARCH-musl.zip
unzip -o xray.zip
install -m 755 xray $XRAY_BIN

# 生成配置文件
show_step "生成配置文件"
mkdir -p $CONFIG_DIR

if [ "$USE_TLS" -eq 1 ]; then
  mkdir -p $CONFIG_DIR/certs
  openssl req -new -x509 -days 3650 -nodes -subj "/CN=xray.local" \
    -out $CONFIG_DIR/certs/cert.pem -keyout $CONFIG_DIR/certs/key.pem
    
  TLS_JSON='{
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "tlsSettings": {
        "certificates": [
          {
            "certificateFile": "'$CONFIG_DIR'/certs/cert.pem",
            "keyFile": "'$CONFIG_DIR'/certs/key.pem"
          }
        ]
      },
      "wsSettings": {
        "path": "/"
      }
    }
  }'
else
  TLS_JSON='{
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "/"
      }
    }
  }'
fi

cat >$CONFIG_DIR/config.json <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "$LOG_DIR/access.log",
    "error": "$LOG_DIR/error.log"
  },
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

# OpenRC 服务配置
show_step "创建 OpenRC 服务"
cat >/etc/init.d/xray <<EOF
#!/sbin/openrc-run
name="Xray Service"
description="Xray Proxy Service"

command="$XRAY_BIN"
command_args="-config $CONFIG_DIR/config.json"
command_user="root"

pidfile="/run/xray.pid"
logfile="$LOG_DIR/service.log"

depend() {
  need net
  use dns
}

start_pre() {
  checkpath -f -m 0644 -o \$command_user \$logfile
}

start() {
  ebegin "Starting \$name"
  start-stop-daemon --start \\
    --exec \$command \\
    --user \$command_user \\
    --background \\
    --make-pidfile \\
    --pidfile \$pidfile \\
    -- \\
    \$command_args >> \$logfile 2>&1
  eend \$?
}

stop() {
  ebegin "Stopping \$name"
  start-stop-daemon --stop \\
    --exec \$command \\
    --pidfile \$pidfile
  eend \$?
}
EOF

chmod +x /etc/init.d/xray
rc-update add xray default
rc-service xray start

# 显示结果
echo -e "\n✅ Xray $VER 安装完成！"
echo "协议：$PROTO + WS"
echo "端口：$PORT"
echo "UUID：$UUID"
[ "$USE_TLS" -eq 1 ] && echo "TLS：启用 (自签证书)" || echo "TLS：未启用"
echo "配置文件：$CONFIG_DIR/config.json"
echo "日志文件：$LOG_DIR/{access,error}.log"
echo -e "\n管理命令："
echo "启动服务: rc-service xray start"
echo "停止服务: rc-service xray stop"
echo "查看状态: rc-service xray status"
echo "卸载命令: $0 uninstall"
