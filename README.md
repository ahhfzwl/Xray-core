bash <(curl -Ls https://raw.githubusercontent.com/ahhfzwl/Xray-core/refs/heads/main/install.sh) install

bash <(curl -Ls https://raw.githubusercontent.com/ahhfzwl/Xray-core/refs/heads/main/add.sh)

手动安装：
```
cd /tmp
curl -LO https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip Xray-linux-64.zip
mv xray /usr/local/bin/
```

XHTTP：
```
cat > /etc/xray/config.json << 'EOF'
{
  "inbounds": [
    {
      "port": 10808,
      "protocol": "vless",
      "settings": {
        "clients": [
          {"id": "11112222-3333-4444-aaaa-bbbbccccdddd"}
        ],
        "decryption": "none"
      },
      "streamSettings": {"network": "xhttp"}
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
```
REALITY：
```
cat > /etc/xray/config.json << 'EOF'
{
  "inbounds": [
    {
      "port": 10808,
      "protocol": "vless",
      "settings": {
        "clients": [
          {"id": "11112222-3333-4444-aaaa-bbbbccccdddd"}
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "www.microsoft.com:443",
          "serverNames": ["www.microsoft.com"],
          "privateKey": "cGuXEVMQtZ6x7fXPtK9_ZqXC7KWvFN8j0Km7VizEDVU",
          "shortIds": [""]
        }
      }
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
```
openrc
```
cat > /etc/init.d/xray << 'EOF'
#!/sbin/openrc-run
name="xray"
command="/usr/local/bin/xray"
command_args="-config /etc/xray/config.json"
command_background=true
pidfile="/var/run/xray.pid"
respawn="yes"
respawn_delay="5"
EOF
chmod +x /etc/init.d/xray
rc-update add xray default
/etc/init.d/xray start
/etc/init.d/xray status
```
systemd
```
cat > /etc/systemd/system/xray.service << 'EOF'
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json

Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable xray
systemctl start xray
systemctl status xray
```
修改端口：
```
sed -i 's/"port": 10808,/"port": 443,/' "/etc/xray/config.json"
```
