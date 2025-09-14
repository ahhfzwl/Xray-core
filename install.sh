#!/bin/bash

case "$1" in
install)
    echo "[+] 安装依赖..."
    apt-get update -y
    apt-get install -y wget unzip

    echo "[+] 下载 Xray..."
    tmpdir=$(mktemp -d)
    wget -O "$tmpdir/xray.zip" "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
    unzip "$tmpdir/xray.zip" -d "$tmpdir"
    install -m 755 "$tmpdir/xray" /usr/local/bin/xray
    rm -rf "$tmpdir"

    echo "[+] 创建配置文件..."
    mkdir -p /etc/xray
    cat > /etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": 1080,
      "listen": "127.0.0.1",
      "protocol": "socks"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

    echo "[+] 创建 systemd 服务..."
    cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray -c /etc/xray/config.json
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable xray
    systemctl start xray
    echo "[+] 安装完成！用 systemctl start|stop|restart xray 控制"
    ;;
uninstall)
    echo "[+] 停止服务..."
    systemctl stop xray 2>/dev/null || true
    systemctl disable xray 2>/dev/null || true

    echo "[+] 删除 systemd 服务文件..."
    rm -f /etc/systemd/system/xray.service
    systemctl daemon-reload

    echo "[+] 删除二进制和配置..."
    rm -f /usr/local/bin/xray
    rm -rf /etc/xray

    echo "[+] 卸载完成"
    ;;
*)
    echo "Usage: $0 {install|uninstall}"
    exit 1
    ;;
esac
