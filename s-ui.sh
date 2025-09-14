#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}

[[ $EUID -ne 0 ]] && LOGE "错误：您必须以 root 身份运行此脚本! \n" && exit 1

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "系统OS检查失败，请联系作者!" >&2
    exit 1
fi

echo "操作系统版本是: $release"

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Default$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Restart the ${1} service" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}按 Enter 键返回主菜单: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/xxf185/s-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "此功能将强制重新安装最新版本，数据不会丢失。是否继续?" "n"
    if [[ $? != 0 ]]; then
        LOGE "Cancelled"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/xxf185/s-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "更新完成，面板已自动重启 "
        exit 0
    fi
}

custom_version() {
    echo "输入面板版本 (例如 0.0.1):"
    read panel_version

    if [ -z "$panel_version" ]; then
        echo "面板版本不能为空"
    exit 1
    fi

    download_link="https://raw.githubusercontent.com/xxf185/s-ui/master/install.sh"

    install_command="bash <(curl -Ls $download_link) $panel_version"

    echo "下载并安装面板版本 $panel_version..."
    eval $install_command
}

uninstall() {
    confirm "您确定要卸载该面板吗?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop s-ui
    systemctl disable s-ui
    rm /etc/systemd/system/s-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/s-ui/ -rf
    rm /usr/local/s-ui/ -rf

    echo ""
    echo -e "卸载成功，如果要删除此脚本，请在退出脚本后运行${green}rm /usr/local/s-ui -f${plain} 删除它."
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_admin() {
    echo "不建议将用户名密码设置为默认!"
    confirm "您确定要将用户名密码重置为默认值吗 ?" "n"
    if [[ $? == 0 ]]; then
        /usr/local/s-ui/sui admin -reset
    fi
    before_show_menu
}

set_admin() {
    echo "不建议将用户名密码设置为复杂的文本."
    read -p "请设置您的用户名:" config_account
    read -p "请设置您的密码:" config_password
    /usr/local/s-ui/sui admin -username ${config_account} -password ${config_password}
    before_show_menu
}

view_admin() {
    /usr/local/s-ui/sui admin -show
    before_show_menu
}

reset_setting() {
    confirm "您确定要将设置重置为默认设置吗 ?" "n"
    if [[ $? == 0 ]]; then
        /usr/local/s-ui/sui setting -reset
    fi
    before_show_menu
}

set_setting() {
    echo -e "请输入 ${yellow}面板端口${plain} (回车默认):"
    read config_port
    echo -e "请输入 ${yellow}面板路径${plain} (回车默认):"
    read config_path

    echo -e "请输入 ${yellow}订阅端口${plain} (回车默认):"
    read config_subPort
    echo -e "请输入 ${yellow}订阅路径${plain} (回车默认):" 
    read config_subPath

    echo -e "${yellow}正在初始化，请等待...${plain}"
    params=""
    [ -z "$config_port" ] || params="$params -port $config_port"
    [ -z "$config_path" ] || params="$params -path $config_path"
    [ -z "$config_subPort" ] || params="$params -subPort $config_subPort"
    [ -z "$config_subPath" ] || params="$params -subPath $config_subPath"
    /usr/local/s-ui/sui setting ${params}
    before_show_menu
}

view_setting() {
    /usr/local/s-ui/sui setting -show
    view_uri
    before_show_menu
}

view_uri() {
    info=$(/usr/local/s-ui/sui uri)
    if [[ $? != 0 ]]; then
        LOGE "获取当前 uri 错误"
        before_show_menu
    fi
    LOGI "您可以通过以下方式访问面板:"
    echo -e "${green}${info}${plain}"
}

start() {
    check_status $1
    if [[ $? == 0 ]]; then
        echo ""
        LOGI -e "${1} 正在运行，无需再次启动，如需重启，请选择重启"
    else
        systemctl start $1
        sleep 2
        check_status $1
        if [[ $? == 0 ]]; then
            LOGI "${1} 启动成功"
        else
            LOGE "启动失败 ${1}, 可能是因为启动时间超过两秒，请稍后查看日志信息"
        fi
    fi

    if [[ $# == 1 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status $1
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "${1} 已停止!"
    else
        systemctl stop $1
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "${1} 成功停止"
        else
            LOGE "停止失败 ${1}, 可能是因为停止时间超过两秒，请稍后查看日志信息"
        fi
    fi

    if [[ $# == 1 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart $1
    sleep 2
    check_status $1
    if [[ $? == 0 ]]; then
        LOGI "${1} 重启成功"
    else
        LOGE "重启失败 ${1},可能是因为启动时间超过两秒，请稍后查看日志信息"
    fi
    if [[ $# == 1 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status s-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable $1
    if [[ $? == 0 ]]; then
        LOGI " ${1} 设置开机自启"
    else
        LOGE " ${1} 设置开机自启失败"
    fi

    if [[ $# == 1 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable $1
    if [[ $? == 0 ]]; then
        LOGI " ${1}设置开机自启取消"
    else
        LOGE " ${1}设置开机自启取消失败"
    fi

    if [[ $# == 1 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u $1.service -e --no-pager -f
    if [[ $# == 1 ]]; then
        before_show_menu
    fi
}

update_shell() {
    wget -O /usr/bin/s-ui -N --no-check-certificate https://github.com/xxf185/s-ui/raw/master/s-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "下载脚本失败，请检查机器是否可以连接Github"
        before_show_menu
    else
        chmod +x /usr/bin/s-ui
        LOGI "升级脚本成功，请重新运行脚本" && exit 0
    fi
}

check_status() {
    if [[ ! -f "/etc/systemd/system/$1.service" ]]; then
        return 2
    fi
    temp=$(systemctl status "$1" | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled $1)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status s-ui
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "面板已安装"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status s-ui
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "请先安装面板"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status $1
    case $? in
    0)
        echo -e "${1} 状态: ${green}运行中${plain}"
        show_enable_status $1
        ;;
    1)
        echo -e "${1} 状态: ${yellow}未运行${plain}"
        show_enable_status $1
        ;;
    2)
        echo -e "${1} 状态: ${red}未安装${plain}"
        ;;
    esac
}

show_enable_status() {
    check_enabled $1
    if [[ $? == 0 ]]; then
        echo -e " ${1} 开机自启: ${green}Yes${plain}"
    else
        echo -e " ${1} 开机自启: ${red}No${plain}"
    fi
}

check_s-ui_status() {
    count=$(ps -ef | grep "sui" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_s-ui_status() {
    check_s-ui_status
    if [[ $? == 0 ]]; then
        echo -e "s-ui 状态: ${green}运行中${plain}"
    else
        echo -e "s-ui 状态: ${red}未运行${plain}"
    fi
}

bbr_menu() {
    echo -e "${green}\t1.${plain} 启用BBR"
    echo -e "${green}\t2.${plain} 禁用BBR"
    echo -e "${green}\t0.${plain} 返回主菜单"
    read -p "请选择: " choice
    case "$choice" in
    0)
        show_menu
        ;;
    1)
        enable_bbr
        ;;
    2)
        disable_bbr
        ;;
    *) echo "选择错误" ;;
    esac
}

disable_bbr() {
    if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf || ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        echo -e "${yellow}BBR is not currently enabled.${plain}"
        exit 0
    fi
    sed -i 's/net.core.default_qdisc=fq/net.core.default_qdisc=pfifo_fast/' /etc/sysctl.conf
    sed -i 's/net.ipv4.tcp_congestion_control=bbr/net.ipv4.tcp_congestion_control=cubic/' /etc/sysctl.conf
    sysctl -p
    if [[ $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}') == "cubic" ]]; then
        echo -e "${green}BBR已成功替换为CUBIC.${plain}"
    else
        echo -e "${red}无法用 CUBIC 替换 BBR。请检查您的系统配置.${plain}"
    fi
}

enable_bbr() {
    if grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf && grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        echo -e "${green}BBR已启用!${plain}"
        exit 0
    fi
    case "${release}" in
    ubuntu | debian | armbian)
        apt-get update && apt-get install -yqq --no-install-recommends ca-certificates
        ;;
    centos | almalinux | rocky | oracle)
        yum -y update && yum -y install ca-certificates
        ;;
    fedora)
        dnf -y update && dnf -y install ca-certificates
        ;;
    arch | manjaro | parch)
        pacman -Sy --noconfirm ca-certificates
        ;;
    *)
        echo -e "${red}不支持的操作系统。请检查脚本并手动安装必要的软件包.${plain}\n"
        exit 1
        ;;
    esac
    echo "net.core.default_qdisc=fq" | tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" | tee -a /etc/sysctl.conf
    sysctl -p
    if [[ $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}') == "bbr" ]]; then
        echo -e "${green}BBR已成功启用.${plain}"
    else
        echo -e "${red}无法启用 BBR。请检查您的系统配置.${plain}"
    fi
}

install_acme() {
    cd ~
    LOGI "安装 acme..."
    curl https://get.acme.sh | sh
    if [ $? -ne 0 ]; then
        LOGE "安装 acme 失败"
        return 1
    else
        LOGI "安装 acme 成功"
    fi
    return 0
}

ssl_cert_issue_main() {
    echo -e "${green}\t1.${plain} 获取证书"
    echo -e "${green}\t2.${plain} 撤销证书"
    echo -e "${green}\t3.${plain} 更新证书"
    echo -e "${green}\t4.${plain} 自签名证书"
    read -p "请选择: " choice
    case "$choice" in
        1) ssl_cert_issue ;;
        2) 
            local domain=""
            read -p "请输入您的域名以撤销证书: " domain
            ~/.acme.sh/acme.sh --revoke -d ${domain}
            LOGI "证书已撤销"
            ;;
        3)
            local domain=""
            read -p "请输入域名以强制更新证书: " domain
            ~/.acme.sh/acme.sh --renew -d ${domain} --force ;;
        4)
            generate_self_signed_cert
            ;;
        *) echo "选择错误" ;;
    esac
}

ssl_cert_issue() {
    if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        echo "acme.sh未安装.我们将安装它"
        install_acme
        if [ $? -ne 0 ]; then
            LOGE "安装 acme 失败，请检查日志"
            exit 1
        fi
    fi
    case "${release}" in
    ubuntu | debian | armbian)
        apt update && apt install socat -y
        ;;
    centos | almalinux | rocky | oracle)
        yum -y update && yum -y install socat
        ;;
    fedora)
        dnf -y update && dnf -y install socat
        ;;
    arch | manjaro | parch)
        pacman -Sy --noconfirm socat
        ;;
    *)
        echo -e "${red}不支持的操作系统。请检查脚本并手动安装必要的软件包.${plain}\n"
        exit 1
        ;;
    esac
    if [ $? -ne 0 ]; then
        LOGE "安装socat失败，请检查日志"
        exit 1
    else
        LOGI "安装socat成功..."
    fi

    local domain=""
    read -p "请输入您的域名:" domain
    LOGD "您的域名:${domain},检查中..."
    local currentCert=$(~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}')

    if [ ${currentCert} == ${domain} ]; then
        local certInfo=$(~/.acme.sh/acme.sh --list)
        LOGE "系统此处已有证书，无法再次颁发，当前证书详情:"
        LOGI "$certInfo"
        exit 1
    else
        LOGI "您的域名现在可以颁发证书了..."
    fi

    certPath="/root/cert/${domain}"
    if [ ! -d "$certPath" ]; then
        mkdir -p "$certPath"
    else
        rm -rf "$certPath"
        mkdir -p "$certPath"
    fi

    local WebPort=80
    read -p "请选择您使用的端口，默认为 80 端口:" WebPort
    if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
        LOGE "您输入的 ${WebPort} 无效，将使用默认端口"
    fi
    LOGI "您使用的:${WebPort} 要颁发证书，请确保此端口已打开..."
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d ${domain} --standalone --httpport ${WebPort}
    if [ $? -ne 0 ]; then
        LOGE "颁发证书失败，请检查日志"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        LOGE "颁发证书成功，正在安装证书..."
    fi
    ~/.acme.sh/acme.sh --installcert -d ${domain} \
        --key-file /root/cert/${domain}/privkey.pem \
        --fullchain-file /root/cert/${domain}/fullchain.pem

    if [ $? -ne 0 ]; then
        LOGE "安装证书失败，退出"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        LOGI "安装证书成功，启用自动更新.."
    fi

    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        LOGE "自动续订失败，证书详细信息:"
        ls -lah cert/*
        chmod 755 $certPath/*
        exit 1
    else
        LOGI "自动续订成功，证书详细信息:"
        ls -lah cert/*
        chmod 755 $certPath/*
    fi
}

ssl_cert_issue_CF() {
    echo -E ""
    LOGD "******使用说明******"
    echo "1) Cloudflare 的新证书"
    echo "2) 强制更新现有证书"
    echo "3) 返回菜单"
    read -p "请选择 [1-3]: " choice

    certPath="/root/cert-CF"

    case $choice in
        1|2)
            force_flag=""
            if [ "$choice" -eq 2 ]; then
                force_flag="--force"
                echo "强制重新颁发 SSL 证书..."
            else
                echo "开始颁发 SSL 证书..."
            fi
            
            LOGD "******使用说明******"
            LOGI "该脚本将使用Acme脚本申请证书,使用时需保证:"
            LOGI "1.知晓Cloudflare 注册邮箱"
            LOGI "2.知晓Cloudflare Global API Key"
            LOGI "3.域名已通过Cloudflare进行解析到当前服务器"
            LOGI "4.该脚本申请证书默认安装路径为/root/cert目录 "
            confirm "我已确认以上内容?[y/n]" "y"
            if [ $? -eq 0 ]; then
                if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
                    echo "安装Acme脚本..."
                    install_acme
                    if [ $? -ne 0 ]; then
                        LOGE "安装acme脚本失败"
                        exit 1
                    fi
                fi

                CF_Domain=""
                if [ ! -d "$certPath" ]; then
                    mkdir -p $certPath
                else
                    rm -rf $certPath
                    mkdir -p $certPath
                fi

                LOGD "请设置域名:"
                read -p "Input your domain here: " CF_Domain
                LOGD "你的域名设置为: ${CF_Domain}"

                CF_GlobalKey=""
                CF_AccountEmail=""
                LOGD "请设置API密钥:"
                read -p "Input your key here: " CF_GlobalKey
                LOGD "你的API密钥为: ${CF_GlobalKey}"

                LOGD "请设置注册邮箱:"
                read -p "Input your email here: " CF_AccountEmail
                LOGD "你的注册邮箱为: ${CF_AccountEmail}"

                ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
                if [ $? -ne 0 ]; then
                    LOGE "修改默认CA为Lets'Encrypt失败,脚本退出..."
                    exit 1
                fi

                export CF_Key="${CF_GlobalKey}"
                export CF_Email="${CF_AccountEmail}"

                ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} $force_flag --log
                if [ $? -ne 0 ]; then
                    LOGE "证书颁发失败，脚本退出..."
                    exit 1
                else
                    LOGI "证书颁发成功，正在安装..."
                fi

                mkdir -p ${certPath}/${CF_Domain}
                if [ $? -ne 0 ]; then
                    LOGE "无法创建目录: ${certPath}/${CF_Domain}"
                    exit 1
                fi

                ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} \
                    --fullchain-file ${certPath}/${CF_Domain}/fullchain.pem \
                    --key-file ${certPath}/${CF_Domain}/privkey.pem

                if [ $? -ne 0 ]; then
                    LOGE "证书安装失败，脚本退出..."
                    exit 1
                else
                    LOGI "证书安装成功，正在开启自动更新..."
                fi

                ~/.acme.sh/acme.sh --upgrade --auto-upgrade
                if [ $? -ne 0 ]; then
                    LOGE "自动更新设置失败，脚本退出..."
                    exit 1
                else
                    LOGI "证书已安装，且自动续订功能已开启."
                    ls -lah ${certPath}/${CF_Domain}
                    chmod 755 ${certPath}/${CF_Domain}
                fi
            fi
            show_menu
            ;;
        3)
            echo "退出..."
            show_menu
            ;;
        *)
            echo "选择无效，请重新选择."
            show_menu
            ;;
    esac
}

generate_self_signed_cert() {
    cert_dir="/etc/sing-box"
    mkdir -p "$cert_dir"
    LOGI "选择证书类型:"
    echo -e "${green}\t1.${plain} Ed25519 (*recommended*)"
    echo -e "${green}\t2.${plain} RSA 2048"
    echo -e "${green}\t3.${plain} RSA 4096"
    echo -e "${green}\t4.${plain} ECDSA prime256v1"
    echo -e "${green}\t5.${plain} ECDSA secp384r1"
    read -p "请选择 [1-5, default 1]: " cert_type
    cert_type=${cert_type:-1}

    case "$cert_type" in
        1)
            algo="ed25519"
            key_opt="-newkey ed25519"
            ;;
        2)
            algo="rsa"
            key_opt="-newkey rsa:2048"
            ;;
        3)
            algo="rsa"
            key_opt="-newkey rsa:4096"
            ;;
        4)
            algo="ecdsa"
            key_opt="-newkey ec -pkeyopt ec_paramgen_curve:prime256v1"
            ;;
        5)
            algo="ecdsa"
            key_opt="-newkey ec -pkeyopt ec_paramgen_curve:secp384r1"
            ;;
        *)
            algo="ed25519"
            key_opt="-newkey ed25519"
            ;;
    esac

    LOGI "生成自签名证书 ($algo)..."
    sudo openssl req -x509 -nodes -days 3650 $key_opt \
        -keyout "${cert_dir}/self.key" \
        -out "${cert_dir}/self.crt" \
        -subj "/CN=myserver"
    if [[ $? -eq 0 ]]; then
        sudo chmod 600 "${cert_dir}/self."*
        LOGI "自签名证书生成成功!"
        LOGI "证书路径: ${cert_dir}/self.crt"
        LOGI "密钥路径: ${cert_dir}/self.key"
    else
        LOGE "无法生成自签名证书."
    fi
    before_show_menu
}

show_usage() {
    echo -e "S-UI 管理脚本使用方法"
    echo -e "------------------------------------------"
    echo -e "SUBCOMMANDS:" 
    echo -e "s-ui              - 显示管理菜单 (功能更多)"
    echo -e "s-ui start        - 启动 s-ui 面板"
    echo -e "s-ui stop         - 停止 s-ui 面板"
    echo -e "s-ui restart      - 重启 s-ui 面板"
    echo -e "s-ui status       - 查看 s-ui 状态"
    echo -e "s-ui enable       - 设置 s-ui 开机自启"
    echo -e "s-ui disable      - 取消 s-ui 开机自启"
    echo -e "s-ui log          - 查看 s-ui 日志"
    echo -e "s-ui update       - 更新 s-ui 面板"
    echo -e "s-ui install      - 安装 s-ui 面板"
    echo -e "s-ui uninstall    - 卸载 s-ui 面板"
    echo -e "s-ui help         - 控制菜单使用"
    echo -e "------------------------------------------"
}

show_menu() {
  echo -e "
  ${green}S-UI 面板管理脚本 ${plain}
————————————————————————————————
  ${green}0.${plain} 退出脚本
————————————————————————————————
  ${green}1.${plain} 安装 s-ui
  ${green}2.${plain} 更新 s-ui
  ${green}3.${plain} Custom Version
  ${green}4.${plain} 卸载 s-ui
————————————————————————————————
  ${green}5.${plain} 将用户名密码重置为默认值
  ${green}6.${plain} 设置用户名密码
  ${green}7.${plain} 查看用户名密码
————————————————————————————————
  ${green}8.${plain} 重置面板设置
  ${green}9.${plain} 设置面板设置
  ${green}10.${plain} 查看面板设置
————————————————————————————————
  ${green}11.${plain} 启动 x-ui
  ${green}12.${plain} 停止 x-ui
  ${green}13.${plain} 重启 x-ui
  ${green}14.${plain} 查看 x-ui 状态
  ${green}15.${plain} 查看 x-ui 日志
  ${green}16.${plain} 设置 x-ui 开机自启
  ${green}17.${plain} 取消 x-ui 开机自启
————————————————————————————————
  ${green}18.${plain} 启用&禁用 BBR
  ${green}19.${plain} SSL 证书管理
  ${green}20.${plain} 一键申请SSL证书(acme申请)
————————————————————————————————
 "
    show_status s-ui
    echo && read -p "请选择 [0-20]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && custom_version
        ;;
    4)
        check_install && uninstall
        ;;
    5)
        check_install && reset_admin
        ;;
    6)
        check_install && set_admin
        ;;
    7)
        check_install && view_admin
        ;;
    8)
        check_install && reset_setting
        ;;
    9)
        check_install && set_setting
        ;;
    10)
        check_install && view_setting
        ;;
    11)
        check_install && start s-ui
        ;;
    12)
        check_install && stop s-ui
        ;;
    13)
        check_install && restart s-ui
        ;;
    14)
        check_install && status s-ui
        ;;
    15)
        check_install && show_log s-ui
        ;;
    16)
        check_install && enable s-ui
        ;;
    17)
        check_install && disable s-ui
        ;;
    18)
        bbr_menu
        ;;
    19)
        ssl_cert_issue_main
        ;;
    20)
        ssl_cert_issue_CF
        ;;
    *)
        LOGE "请选择 [0-20]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start s-ui 0
        ;;
    "stop")
        check_install 0 && stop s-ui 0
        ;;
    "restart")
        check_install 0 && restart s-ui 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable s-ui 0
        ;;
    "disable")
        check_install 0 && disable s-ui 0
        ;;
    "log")
        check_install 0 && show_log s-ui 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
