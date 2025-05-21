#!/bin/sh
###############################################################################
# Alist Manager Script - Alpine Compatible
# Based on v3.sh, modified for Alpine Linux 3.21.2 x86_64
# Author: Troray + ChatGPT Alpine Patch
###############################################################################

# ANSI color config
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# Check if running on Alpine
is_alpine() {
  [ -f /etc/alpine-release ]
}

# Detect architecture
ARCH="UNKNOWN"
platform=$(uname -m)
[ "$platform" = "x86_64" ] && ARCH=amd64
[ "$platform" = "aarch64" ] && ARCH=arm64

if [ "$ARCH" = "UNKNOWN" ]; then
  echo "${RED}不支持的架构: $platform${RESET}"
  exit 1
fi

# Check essential tools
REQUIRED_CMDS="curl tar"
if is_alpine; then
  REQUIRED_CMDS="$REQUIRED_CMDS ip"
fi
for cmd in $REQUIRED_CMDS; do
  if ! command -v $cmd >/dev/null 2>&1; then
    echo "${YELLOW}警告: 未找到 $cmd，请运行 'apk add $cmd' 安装${RESET}"
  fi
done

# Set default install path
INSTALL_PATH="/opt/alist"

# Proxy setting
GH_PROXY=""
read -p "请输入 GitHub 代理地址（可选，例如 https://ghproxy.com/ ）: " GH_PROXY
GH_DOWNLOAD_URL="${GH_PROXY}https://github.com/alist-org/alist/releases/latest/download"

# Download alist binary
echo "${GREEN}下载 Alist...${RESET}"
curl -L "${GH_DOWNLOAD_URL}/alist-linux-musl-${ARCH}.tar.gz" -o /tmp/alist.tar.gz || {
  echo "${RED}下载失败${RESET}"; exit 1;
}

mkdir -p "$INSTALL_PATH"
tar -zxf /tmp/alist.tar.gz -C "$INSTALL_PATH" || {
  echo "${RED}解压失败${RESET}"; exit 1;
}
chmod +x "$INSTALL_PATH/alist"

# Setup service
if is_alpine; then
  echo "${GREEN}创建 OpenRC 服务...${RESET}"
  cat <<EOF > /etc/init.d/alist
#!/sbin/openrc-run
command=\"$INSTALL_PATH/alist\"
command_args=\"server\"
command_background=true
directory=\"$INSTALL_PATH\"
pidfile=/var/run/alist.pid
EOF
  chmod +x /etc/init.d/alist
  rc-update add alist default
else
  echo "${GREEN}创建 systemd 服务...${RESET}"
  cat <<EOF > /etc/systemd/system/alist.service
[Unit]
Description=Alist
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_PATH/alist server
WorkingDirectory=$INSTALL_PATH
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable alist
fi

# Start service
if is_alpine; then
  rc-service alist start
else
  systemctl start alist
fi

# Get credentials
echo "${GREEN}初始化账号...${RESET}"
ACCOUNT_OUTPUT=$("$INSTALL_PATH/alist" admin random 2>&1)
echo "$ACCOUNT_OUTPUT"

# Show IP info
LOCAL_IP=$(ip addr show | grep -w inet | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -n1)
PUBLIC_IP=$(curl -s4 ip.sb || echo "获取失败")

echo "\n访问地址："
echo "局域网：http://${LOCAL_IP}:5244/"
echo "公网：  http://${PUBLIC_IP}:5244/"
echo "安装完成。"
