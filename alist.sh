#!/bin/bash
###############################################################################
#
# Alist Manager Script (Alpine Linux 适配版)
#
# 修改说明：
# 1. 移除 systemd 依赖，适配 OpenRC
# 2. 默认使用 musl-libc 版本
# 3. 优化 Alpine 下的路径检测
#
# 适用系统：Alpine Linux 3.21.2+ (x86_64)
#
###############################################################################

# 错误处理函数
handle_error() {
    local exit_code=$1
    local error_msg=$2
    echo -e "${RED_COLOR}错误：${error_msg}${RES}"
    exit ${exit_code}
}

# 检测必要命令
for cmd in curl tar wget; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo -e "${YELLOW_COLOR}警告：未找到 $cmd，正在尝试安装...${RES}"
        apk add --no-cache $cmd || handle_error 1 "安装 $cmd 失败"
    fi
done

# 配置部分
GH_DOWNLOAD_URL="https://github.com/alist-org/alist/releases/latest/download"
ALIST_BIN_NAME="alist-linux-musl-amd64.tar.gz"  # 强制使用 musl 版本

# 颜色配置
RED_COLOR='\e[1;31m'
GREEN_COLOR='\e[1;32m'
YELLOW_COLOR='\e[1;33m'
RES='\e[0m'

# 获取已安装路径（适配 Alpine）
GET_INSTALLED_PATH() {
    # 检测是否通过 OpenRC 安装
    if [ -f "/etc/init.d/alist" ]; then
        installed_path=$(grep "command=" /etc/init.d/alist | cut -d'"' -f2 | xargs dirname)
        if [ -f "$installed_path/alist" ]; then
            echo "$installed_path"
            return 0
        fi
    fi
    
    # 默认路径
    echo "/opt/alist"
}

# 设置安装路径
INSTALL_PATH=$(GET_INSTALLED_PATH)  # 默认使用已安装路径或 /opt/alist

# 安装函数
INSTALL() {
    echo -e "${GREEN_COLOR}下载 Alist (musl 版本)...${RES}"
    if ! wget -O /tmp/alist.tar.gz "$GH_DOWNLOAD_URL/$ALIST_BIN_NAME"; then
        handle_error 1 "下载失败！请检查网络或代理"
    fi

    echo -e "${GREEN_COLOR}解压文件...${RES}"
    mkdir -p "$INSTALL_PATH"
    tar zxf /tmp/alist.tar.gz -C "$INSTALL_PATH" || handle_error 1 "解压失败"
    chmod +x "$INSTALL_PATH/alist"

    # 获取管理员账号
    cd "$INSTALL_PATH"
    ADMIN_INFO=$("./alist" admin random 2>&1)
    ADMIN_USER=$(echo "$ADMIN_INFO" | grep -oP "username:\s*\K\S+")
    ADMIN_PASS=$(echo "$ADMIN_INFO" | grep -oP "password:\s*\K\S+")
    cd - >/dev/null

    echo -e "${GREEN_COLOR}安装完成！${RES}"
}

# 创建 OpenRC 服务
CREATE_OPENRC_SERVICE() {
    cat > /etc/init.d/alist <<EOF
#!/sbin/openrc-run
name="Alist"
description="Alist file storage"
command="$INSTALL_PATH/alist"
command_args="server"
command_background=true
pidfile="/var/run/alist.pid"

depend() {
    need net
}
EOF

    chmod +x /etc/init.d/alist
    rc-update add alist default
    rc-service alist start
}

# 卸载函数
UNINSTALL() {
    rc-service alist stop
    rc-update del alist
    rm -f /etc/init.d/alist
    rm -rf "$INSTALL_PATH"
    echo -e "${GREEN_COLOR}卸载完成！${RES}"
}

# 主菜单
MENU() {
    clear
    echo -e "\n${GREEN_COLOR}Alist 管理脚本 (Alpine 适配版)${RES}"
    echo -e "----------------------------------------"
    echo -e "1. 安装 Alist"
    echo -e "2. 创建 OpenRC 服务"
    echo -e "3. 卸载 Alist"
    echo -e "4. 启动 Alist"
    echo -e "5. 停止 Alist"
    echo -e "6. 重置管理员密码"
    echo -e "0. 退出"
    echo -e "----------------------------------------"
    read -p "请输入选项 [0-6]: " choice

    case "$choice" in
        1) INSTALL ;;
        2) CREATE_OPENRC_SERVICE ;;
        3) UNINSTALL ;;
        4) rc-service alist start ;;
        5) rc-service alist stop ;;
        6) "$INSTALL_PATH/alist" admin random ;;
        0) exit 0 ;;
        *) echo -e "${RED_COLOR}无效选项！${RES}" ;;
    esac
}

# 执行主菜单
while true; do
    MENU
    read -p "按回车键继续..."
done
