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
cat > /etc/xray/xhttp.json << 'EOF'
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
```
