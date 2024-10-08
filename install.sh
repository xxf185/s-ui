#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 请以 root 权限运行此脚本 \n " && exit 1

# Check OS and set release variable
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
echo "OS is: $release"

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${green}不支持的 CPU 架构 ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}

echo "CPU 架构: $(arch)"

os_version=""
os_version=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)

if [[ "${release}" == "arch" ]]; then
    echo "OS is Arch Linux"
elif [[ "${release}" == "parch" ]]; then
    echo "OS is Parch linux"
elif [[ "${release}" == "manjaro" ]]; then
    echo "OS is Manjaro"
elif [[ "${release}" == "armbian" ]]; then
    echo "OS is Armbian"
elif [[ "${release}" == "opensuse-tumbleweed" ]]; then
    echo "OS is OpenSUSE Tumbleweed"
elif [[ "${release}" == "centos" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red} 请使用 CentOS 8 或更高版本 ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "ubuntu" ]]; then
    if [[ ${os_version} -lt 20 ]]; then
        echo -e "${red} 请使用Ubuntu 20或更高版本!${plain}\n" && exit 1
    fi
elif [[ "${release}" == "fedora" ]]; then
    if [[ ${os_version} -lt 36 ]]; then
        echo -e "${red} 请使用 Fedora 36 或更高版本!${plain}\n" && exit 1
    fi
elif [[ "${release}" == "debian" ]]; then
    if [[ ${os_version} -lt 10 ]]; then
        echo -e "${red} 请使用 Debian 10 或更高版本 ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "almalinux" ]]; then
    if [[ ${os_version} -lt 9 ]]; then
        echo -e "${red} 请使用 AlmaLinux 9 或更高版本 ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "rocky" ]]; then
    if [[ ${os_version} -lt 9 ]]; then
        echo -e "${red} 请使用 Rocky Linux 9 或更高版本 ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "oracle" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red} 请使用 Oracle Linux 8 或更高版本 ${plain}\n" && exit 1
    fi
else
    echo -e "${red}该脚本不支持您的操作系统。${plain}\n"
    echo "下面支持的操作系统有:"
    echo "- Ubuntu 20.04+"
    echo "- Debian 11+"
    echo "- CentOS 8+"
    echo "- Fedora 36+"
    echo "- Arch Linux"
    echo "- Parch Linux"
    echo "- Manjaro"
    echo "- Armbian"
    echo "- AlmaLinux 9+"
    echo "- Rocky Linux 9+"
    echo "- Oracle Linux 8+"
    echo "- OpenSUSE Tumbleweed"
    exit 1
fi


install_base() {
    case "${release}" in
    centos | almalinux | rocky | oracle)
        yum -y update && yum install -y -q wget curl tar tzdata
        ;;
    fedora)
        dnf -y update && dnf install -y -q wget curl tar tzdata
        ;;
    arch | manjaro | parch)
        pacman -Syu && pacman -Syu --noconfirm wget curl tar tzdata
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone
        ;;
    *)
        apt-get update && apt-get install -y -q wget curl tar tzdata
        ;;
    esac
}

config_after_install() {
    echo -e "${yellow}配置中... ${plain}"
    /usr/local/s-ui/sui migrate
    
    echo -e "${yellow}安装/更新已完成！为了安全起见，建议修改面板设置 ${plain}"
    read -p "是否要继续修改 [y/n] ": config_confirm
    if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
        echo -e "请设置${yellow}面板端口${plain} (回车默认):"
        read config_port
        echo -e "请设置${yellow}面板路径${plain} (回车默认):"
        read config_path

        # Sub configuration
        echo -e "请设置${yellow}订阅端口${plain} (回车默认):"
        read config_subPort
        echo -e "请设置${yellow}订阅路径${plain} (回车默认):" 
        read config_subPath

        # Set configs
        echo -e "${yellow}正在初始化，请等待...${plain}"
        params=""
        [ -z "$config_port" ] || params="$params -port $config_port"
        [ -z "$config_path" ] || params="$params -path $config_path"
        [ -z "$config_subPort" ] || params="$params -subPort $config_subPort"
        [ -z "$config_subPath" ] || params="$params -subPath $config_subPath"
        /usr/local/s-ui/sui setting ${params}

        read -p "Do you want to change admin credentials [y/n]? ": admin_confirm
        if [[ "${admin_confirm}" == "y" || "${admin_confirm}" == "Y" ]]; then
            # First admin credentials
            read -p "请设置您的用户名:" config_account
            read -p "请设置您的密码:" config_password

            # Set credentials
            echo -e "${yellow}正在初始化，请等待...${plain}"
            /usr/local/s-ui/sui admin -username ${config_account} -password ${config_password}
        else
            echo -e "${yellow}您当前的管理员信息: ${plain}"
            /usr/local/s-ui/sui admin -show
        fi
    else
        echo -e "${red}cancel...${plain}"
        if [[ ! -f "/usr/local/s-ui/db/s-ui.db" ]]; then
            local usernameTemp=$(head -c 6 /dev/urandom | base64)
            local passwordTemp=$(head -c 6 /dev/urandom | base64)
            echo -e "这是全新安装，出于安全考虑将生成随机登录信息:"
            echo -e "###############################################"
            echo -e "${green}用户名:${usernameTemp}${plain}"
            echo -e "${green}密码:${passwordTemp}${plain}"
            echo -e "###############################################"
            echo -e "${red}如果你忘记了登录信息，你可以输入${green}s-ui${red} 用于管理菜单${plain}"
            /usr/local/s-ui/sui admin -username ${usernameTemp} -password ${passwordTemp}
        else
            echo -e "${red} 升级后旧设置不变，如果您忘记了登录信息，您可以输入 ${green}s-ui${red} 用于管理菜单${plain}"
        fi
    fi
}

install_s-ui() {
    cd /tmp/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/xxf185/s-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}获取s-ui版本失败${plain}"
            exit 1
        fi
        echo -e "已获取 s-ui 最新版本: ${last_version}, 开始安装..."
        wget -N --no-check-certificate -O /tmp/s-ui-linux-$(arch).tar.gz https://github.com/xxf185/s-ui/releases/download/${last_version}/s-ui-linux-$(arch).tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载s-ui失败，请确保你的服务器可以访问Github ${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/xxf185/s-ui/releases/download/${last_version}/s-ui-linux-$(arch).tar.gz"
        echo -e "开始安装 s-ui v$1"
        wget -N --no-check-certificate -O /tmp/s-ui-linux-$(arch).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载s-ui v$1 失败${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/s-ui/ ]]; then
        systemctl stop s-ui
        systemctl stop sing-box
    fi

    tar zxvf s-ui-linux-$(arch).tar.gz
    rm s-ui-linux-$(arch).tar.gz -f

    wget --no-check-certificate -O /usr/bin/s-ui https://raw.githubusercontent.com/xxf185/s-ui/master/s-ui.sh

    chmod +x s-ui/sui s-ui/bin/sing-box s-ui/bin/runSingbox.sh /usr/bin/s-ui
    cp -rf s-ui /usr/local/
    cp -f s-ui/*.service /etc/systemd/system/
    rm -rf s-ui

    config_after_install

    systemctl daemon-reload
    systemctl enable s-ui  --now
    systemctl enable sing-box --now

    echo -e "${green}s-ui v${last_version}${plain} 安装完成"
    echo -e ""
    s-ui help
}

echo -e "${green}准备安装...${plain}"
install_base
install_s-ui $1
