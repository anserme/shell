#!/bin/bash

# Configuration file path
CONFIG_FILE="/etc/tcping_config"

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "请以root权限运行此脚本惹！" >&2
    exit 1
fi

# Install function
install() {
    echo "开始安装相关软件..."
    apt update && apt install -y wget curl cron tcping

    wget https://github.com/pouriyajamshidi/tcping/releases/latest/download/tcping_amd64.deb -O /tmp/tcping.deb
    apt install -y /tmp/tcping.deb

    read -p "请输入更换IP的URL（例如：https://example.com/vdschangeip.php?utoken=xxxx&htoken=xxxx）： " change_url
    echo "URL配置为：$change_url"
    echo "CHANGE_URL=\"$change_url\"" > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"

    script_path=$(realpath "$0")
    cron_job="*/5 * * * * $script_path check"
    (crontab -l 2>/dev/null | grep -v "$script_path check"; echo "$cron_job") | crontab -

    echo "安装完成惹！配置文件存储在：$CONFIG_FILE"
}

# Check function
check() {
    echo "正在执行TCPing测试惹..."
    tcping_output=$(tcping itdog.cn 80 -c 10 | sed -r "s/\x1B\[[0-9;]*[mK]//g" | tr -d '\r')

    # Display raw output for debugging
    echo "$tcping_output"

    # Extract the "received" count
    received_count=$(echo "$tcping_output" | grep -Eo '[0-9]+ received' | awk '{print $1}')

    # Debugging output
    echo "接收包数为：$received_count"

    # Validate and decide based on received count
    if [ "$received_count" -eq 0 ]; then
        echo "检测到 0 received，执行change函数惹..."
        change
    else
        echo "探测成功，无需执行change函数。"
    fi
}

# Change function
change() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo "正在执行IP更换请求惹，目标URL为：$CHANGE_URL"
        curl "$CHANGE_URL"
        echo "IP更换请求已完成。"
    else
        echo "配置文件不存在，无法执行change操作！请重新运行install设置URL。"
    fi
}

# Main logic
case "$1" in
    install)
        install
        ;;
    check)
        check
        ;;
    change)
        change
        ;;
    *)
        echo "使用方法：$0 {install|check|change}"
        ;;
esac
