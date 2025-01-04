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
    tcping_output=$(tcping itdog.cn 80 -c 10)
    echo "$tcping_output"

    # Extract successful probes count
    successful_probes=$(echo "$tcping_output" | grep -Eo 'successful probes:\s+[0-9]+' | awk '{print $3}')

    # Debugging output
    echo "成功探测数为：${successful_probes:-未捕获}"

    # Handle empty or missing result
    if [ -z "$successful_probes" ]; then
        echo "未能捕获成功探测数，假设为 0。"
        successful_probes=0
    fi

    if [ "$successful_probes" -eq 0 ]; then
        echo "检测到所有探测失败，执行change函数惹..."
        change
    else
        echo "所有探测成功，无需执行change函数。"
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
