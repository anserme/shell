#!/bin/bash
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

# 默认设置开机自启动
isAutoStart="Y"

function check_sys() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        release="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    fi
    bit=$(uname -m)
    if test "$bit" != "x86_64"; then
        arch="arm64"
    else
        arch="amd64"
    fi
}

function Installation_dependency() {
    gzip_ver=$(gzip -V 2>/dev/null)
    if [[ -z ${gzip_ver} ]]; then
        if [[ ${release} == "centos" ]]; then
            yum update -y
            yum install -y gzip lsof
        else
            apt-get update -y
            apt-get install -y gzip lsof
        fi
    fi
}

function check_root() {
    if [[ $EUID != 0 ]]; then
        echo -e "${Error} 当前非ROOT账号（或没有ROOT权限），请切换为ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 后再运行。"
        exit 1
    fi
}

function check_file() {
    if [ -f /etc/xiandan/ehco ]; then
        chmod -R 777 /etc/xiandan/ehco
    fi
}

function check_nor_file() {
    rm -rf "$(pwd)"/ehco
    rm -rf "$(pwd)"/ehco.service
    rm -rf "$(pwd)"/config.json
    rm -rf /etc/xiandan/ehco
}

function Install_ct() {
    check_root
    check_nor_file
    Installation_dependency
    check_file
    check_sys
    if test "$bit" != "x86_64"; then
        wget --no-check-certificate -P /etc/xiandan/ehco http://sh.alhttdw.cn/xiandan/ehco/arm/ehco
    else
        wget --no-check-certificate -P /etc/xiandan/ehco http://sh.alhttdw.cn/xiandan/ehco/x86/ehco
    fi
    chmod -R 777 /etc/xiandan/ehco/ehco
}

function Uninstall_ct() {
    rm -rf /etc/xiandan/ehco
    echo "ehco已经成功删除"
}

function startehcoService() {
    # 参数说明：
    #   $1: 协议类型（如 none、mwss、ws、wss）
    #   $2: 本地监听端口（localPort）
    #   $3: 代理目标端口（port）
    #   $4: 远程代理节点地址（remoteHost）
    #   $5: secure参数（true/false）
    service xiandan${2}xiandan stop
    rm -f /etc/systemd/system/xiandan${2}xiandan.service
    cat <<EOF > /etc/systemd/system/xiandan${2}xiandan.service
[Unit]
Description=xiandan${2}xiandan
After=network.target
Wants=network.target

[Service]
Type=simple
StandardError=journal
User=root
LimitAS=infinity
LimitCORE=infinity
LimitNOFILE=102400
LimitNPROC=102400
#ExecStart=
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill \$MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    if [ "${5}" == "false" ]; then
        if [ "$1" == "none" ]; then
            sed -i "/#ExecStart/c\ExecStart=/etc/xiandan/ehco/ehco -l 0.0.0.0:${2} -r ${4}:${3} -ur ${4}:${3}" /etc/systemd/system/xiandan${2}xiandan.service
        elif [ "$1" == "mwss" ]; then
            sed -i "/#ExecStart/c\ExecStart=/etc/xiandan/ehco/ehco -l 0.0.0.0:${2} -ur ${4}:${3} -r wss://${4}:${3} -tt mwss" /etc/systemd/system/xiandan${2}xiandan.service
        elif [ "$1" == "ws" ]; then
            sed -i "/#ExecStart/c\ExecStart=/etc/xiandan/ehco/ehco -l 0.0.0.0:${2} -ur ${4}:${3} -r ws://${4}:${3} -tt ws" /etc/systemd/system/xiandan${2}xiandan.service
        elif [ "$1" == "wss" ]; then
            sed -i "/#ExecStart/c\ExecStart=/etc/xiandan/ehco/ehco -l 0.0.0.0:${2} -ur ${4}:${3} -r wss://${4}:${3} -tt wss" /etc/systemd/system/xiandan${2}xiandan.service
        fi
        sed -i '/flowRule.sh/d' /etc/systemd/system/xiandan${2}xiandan.service
    else
        if [ "$1" == "none" ]; then
            sed -i "/#ExecStart/c\ExecStart=/etc/xiandan/ehco/ehco -l 0.0.0.0:${2} -r ${4}:${3} -ur ${4}:${3}" /etc/systemd/system/xiandan${2}xiandan.service
        elif [ "$1" == "mwss" ]; then
            sed -i "/#ExecStart/c\ExecStart=/etc/xiandan/ehco/ehco -l 0.0.0.0:${2} -ur ${4}:${3} -lt mwss -r ${4}:${3}" /etc/systemd/system/xiandan${2}xiandan.service
        elif [ "$1" == "ws" ]; then
            sed -i "/#ExecStart/c\ExecStart=/etc/xiandan/ehco/ehco -l 0.0.0.0:${2} -ur ${4}:${3} -lt ws -r ${4}:${3}" /etc/systemd/system/xiandan${2}xiandan.service
        elif [ "$1" == "wss" ]; then
            sed -i "/#ExecStart/c\ExecStart=/etc/xiandan/ehco/ehco -l 0.0.0.0:${2} -ur ${4}:${3} -lt wss -r ${4}:${3}" /etc/systemd/system/xiandan${2}xiandan.service
        fi
    fi
    systemctl daemon-reload
    if [ ! -x "/etc/xiandan/ehco/ehco" ];then
        Install_ct
        mkdir /etc/xiandan/ehco/$localPort/
    fi
    service xiandan${2}xiandan start
    echo "已设置开机自启动！"
    systemctl enable xiandan${2}xiandan
    echo '指令发送成功！服务运行状态如下'
    echo ' '
    systemctl status xiandan${2}xiandan --no-pager
    exit 1
}

function stopehcoService() {
    service xiandan${1}xiandan stop
    systemctl disable xiandan${1}xiandan
    rm -f /etc/systemd/system/xiandan${1}xiandan.service
    systemctl daemon-reload
}

# 根据传入参数执行相应操作
if [ $# -gt 0 ]; then
  case "$1" in
    install)
      Install_ct
      ;;
    update)
      checknew   # 注意：checknew函数未在此脚本中定义，请补充实现或删除此分支
      ;;
    uninstall)
      Uninstall_ct
      ;;
    start)
      # 用法: start <protocol> <localPort> <port> <remoteHost> <secure>
      # 例如: ./script.sh start none 8080 80 1.2.3.4 false
      startehcoService "$2" "$3" "$4" "$5" "$6"
      ;;
    stop)
      # 用法: stop <localPort>
      stopehcoService "$2"
      ;;
    decrypt)
      # 用法: decrypt <protocol> <localPort> <secure> <remoteHost> <port>
      # 例如: ./script.sh decrypt none 8080 true 1.2.3.4 80
      protocol="$2"
      localPort="$3"
      secure="$4"
      remoteHost="${5:-127.0.0.1}"
      port="${6:-80}"
      isAutoStart="Y"
      startehcoService "$protocol" "$localPort" "$port" "$remoteHost" "$secure"
      ;;
    *)
      echo -e "${Error} 未知的参数: $1"
      ;;
  esac
fi
