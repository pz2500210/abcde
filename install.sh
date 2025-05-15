#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}服务器管理系统安装程序${NC}"
echo -e "${BLUE}=================================================${NC}"

# 检查是否为root用户，如果不是则提供切换选项
if [ "$(id -u)" != "0" ]; then
    echo -e "${YELLOW}当前不是以root用户运行脚本${NC}"
    echo -e "${YELLOW}您有以下选择:${NC}"
    echo -e "1) 使用sudo临时获取root权限继续安装"
    echo -e "2) 切换到root账户并设置密码"
    echo -e "3) 退出安装"
    
    read -p "请选择 [1-3]: " ROOT_OPTION
    
    case $ROOT_OPTION in
        1)
            echo -e "${YELLOW}尝试使用sudo继续安装...${NC}"
            if command -v sudo &> /dev/null; then
                exec sudo bash "$0" "$@"
            else
                echo -e "${RED}sudo命令不可用，无法继续${NC}"
                echo -e "${YELLOW}请选择切换到root账户或退出安装${NC}"
                echo -e "1) 切换到root账户并设置密码"
                echo -e "2) 退出安装"
                read -p "请选择 [1-2]: " SUB_OPTION
                if [ "$SUB_OPTION" = "1" ]; then
                    # 尝试切换到root用户
                    echo -e "${YELLOW}尝试切换到root账户...${NC}"
                else
                    echo -e "${RED}安装已取消${NC}"
                    exit 1
                fi
            fi
            ;;
        2)
            # 尝试切换到root用户并设置密码
            echo -e "${YELLOW}尝试切换到root账户...${NC}"
            ;;
        3)
            echo -e "${RED}安装已取消${NC}"
            exit 1
            ;;
        *)
            echo -e "${RED}无效选项，安装已取消${NC}"
            exit 1
            ;;
    esac
    
    # 如果选择了切换到root用户
    if [ "$ROOT_OPTION" = "2" ] || ([ "$ROOT_OPTION" = "1" ] && [ "$SUB_OPTION" = "1" ]); then
        echo -e "${YELLOW}是否需要为root账户设置密码? (y/n)${NC}"
        read -p "选择 [y/n]: " SET_ROOT_PASS
        
        if [[ $SET_ROOT_PASS =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}请设置root账户密码:${NC}"
            if command -v sudo &> /dev/null; then
                sudo passwd root
            else
                echo -e "${RED}无法设置root密码，sudo命令不可用${NC}"
                echo -e "${RED}请联系服务器管理员或使用root账户重新运行此脚本${NC}"
                exit 1
            fi
        fi
        
        # 尝试切换到root账户
        echo -e "${YELLOW}正在切换到root账户...${NC}"
        if command -v sudo &> /dev/null; then
            exec sudo su -c "bash $0 $@"
        else
            echo -e "${RED}无法切换到root账户，sudo命令不可用${NC}"
            echo -e "${RED}请联系服务器管理员或使用root账户重新运行此脚本${NC}"
            exit 1
        fi
    fi
    
    # 如果代码执行到这里，说明切换失败
    echo -e "${RED}无法以root权限运行，安装已取消${NC}"
    exit 1
fi

# SSH服务检查（添加到此处）
if ! command -v sshd &> /dev/null && ! command -v ssh &> /dev/null; then
    echo -e "${YELLOW}SSH服务未安装，正在安装...${NC}"
    apt-get update && apt-get install -y openssh-server || yum install -y openssh-server
    systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null
    systemctl start ssh 2>/dev/null || systemctl start sshd 2>/dev/null
fi

# 自动检测GitHub仓库URL
echo -e "${YELLOW}检测GitHub仓库URL...${NC}"
SCRIPT_URL=$(curl -s -I https://raw.githubusercontent.com/pz2500210/abcd/main/xx.sh | grep -i "location" | cut -d' ' -f2 | tr -d '\r')
if [[ -n "$SCRIPT_URL" && "$SCRIPT_URL" == *"refs/heads"* ]]; then
    REPO_URL="https://raw.githubusercontent.com/pz2500210/abcd/refs/heads/main"
    echo -e "${YELLOW}使用URL: ${REPO_URL}${NC}"
else
    REPO_URL="https://raw.githubusercontent.com/pz2500210/abcd/main"
    echo -e "${YELLOW}使用URL: ${REPO_URL}${NC}"
fi

# 检查curl命令是否可用
if ! command -v curl &> /dev/null; then
    echo -e "${RED}curl命令不可用，正在安装...${NC}"
    apt-get update && apt-get install -y curl || yum install -y curl
fi

# 测试GitHub连接
echo -e "${YELLOW}测试GitHub连接...${NC}"
if ! curl -s -I https://raw.githubusercontent.com &> /dev/null; then
    echo -e "${RED}无法访问GitHub，请检查网络连接${NC}"
    exit 1
fi

# 修改SSH配置之前先检查文件是否存在
if [ -f "/etc/ssh/sshd_config" ]; then
    echo -e "${YELLOW}修改SSH配置...${NC}"
    # 备份原始SSH配置
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    # 自动修改SSH配置
    sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

    # 重启SSH服务
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
    echo -e "${GREEN}SSH配置已修改完成${NC}"
else
    echo -e "${YELLOW}未找到SSH配置文件，跳过SSH配置...${NC}"
fi

# 下载所有文件
echo -e "${YELLOW}正在下载必要文件，请稍候...${NC}"

# 创建临时目录
rm -rf /tmp/server-setup
mkdir -p /tmp/server-setup
cd /tmp/server-setup

# 下载文件
echo -e "${YELLOW}下载server_init.sh...${NC}"
curl -s -o server_init.sh ${REPO_URL}/server_init.sh
echo "server_init.sh 大小: $(du -b server_init.sh | cut -f1) 字节"

echo -e "${YELLOW}下载cleanup.sh...${NC}"
curl -s -o cleanup.sh ${REPO_URL}/cleanup.sh
echo "cleanup.sh 大小: $(du -b cleanup.sh | cut -f1) 字节"

echo -e "${YELLOW}下载xx.sh...${NC}"
curl -s -o xx.sh ${REPO_URL}/xx.sh
echo "xx.sh 大小: $(du -b xx.sh | cut -f1) 字节"

echo -e "${YELLOW}下载proxy_bbr.sh...${NC}"
curl -s -o proxy_bbr.sh ${REPO_URL}/proxy_bbr.sh
echo "proxy_bbr.sh 大小: $(du -b proxy_bbr.sh | cut -f1) 字节"

echo -e "${YELLOW}下载cert_dns.sh...${NC}"
curl -s -o cert_dns.sh ${REPO_URL}/cert_dns.sh
echo "cert_dns.sh 大小: $(du -b cert_dns.sh | cut -f1) 字节"

echo -e "${YELLOW}下载system_tools.sh...${NC}"
curl -s -o system_tools.sh ${REPO_URL}/system_tools.sh
echo "system_tools.sh 大小: $(du -b system_tools.sh | cut -f1) 字节"

echo -e "${YELLOW}下载firewall.sh...${NC}"
curl -s -o firewall.sh ${REPO_URL}/firewall.sh
echo "firewall.sh 大小: $(du -b firewall.sh | cut -f1) 字节"

# 检查文件是否下载成功
if [ ! -s server_init.sh ] || [ ! -s cleanup.sh ] || [ ! -s xx.sh ] || [ ! -s proxy_bbr.sh ] || [ ! -s cert_dns.sh ] || [ ! -s system_tools.sh ] || [ ! -s firewall.sh ]; then
    echo -e "${RED}文件下载失败，尝试备用URL...${NC}"
    
    # 尝试备用URL
    if [[ "$REPO_URL" == *"refs/heads"* ]]; then
        REPO_URL="https://raw.githubusercontent.com/pz2500210/abcd/main"
    else
        REPO_URL="https://raw.githubusercontent.com/pz2500210/abcd/refs/heads/main"
    fi
    
    echo -e "${YELLOW}使用备用URL: ${REPO_URL}${NC}"
    
    curl -s -o server_init.sh ${REPO_URL}/server_init.sh
    curl -s -o cleanup.sh ${REPO_URL}/cleanup.sh
    curl -s -o xx.sh ${REPO_URL}/xx.sh
    curl -s -o proxy_bbr.sh ${REPO_URL}/proxy_bbr.sh
    curl -s -o cert_dns.sh ${REPO_URL}/cert_dns.sh
    curl -s -o system_tools.sh ${REPO_URL}/system_tools.sh
    curl -s -o firewall.sh ${REPO_URL}/firewall.sh
    
    # 再次检查
    if [ ! -s server_init.sh ] || [ ! -s cleanup.sh ] || [ ! -s xx.sh ] || [ ! -s proxy_bbr.sh ] || [ ! -s cert_dns.sh ] || [ ! -s system_tools.sh ] || [ ! -s firewall.sh ]; then
        echo -e "${RED}文件下载失败，请检查网络连接或仓库地址${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}文件下载成功!${NC}"

# 创建统一的脚本目录
echo -e "${YELLOW}创建脚本目录...${NC}"
mkdir -p /usr/local/xx

# 复制文件到正确位置
echo -e "${YELLOW}复制文件到系统...${NC}"
cp -f server_init.sh /usr/local/xx/
cp -f cleanup.sh /usr/local/xx/
cp -f xx.sh /usr/local/xx/
cp -f proxy_bbr.sh /usr/local/xx/
cp -f cert_dns.sh /usr/local/xx/
cp -f system_tools.sh /usr/local/xx/
cp -f firewall.sh /usr/local/xx/

# 设置执行权限
echo -e "${YELLOW}设置执行权限...${NC}"
chmod +x /usr/local/xx/proxy_bbr.sh
chmod +x /usr/local/xx/cert_dns.sh
chmod +x /usr/local/xx/system_tools.sh
chmod +x /usr/local/xx/firewall.sh
chmod +x /usr/local/xx/server_init.sh
chmod +x /usr/local/xx/cleanup.sh
chmod +x /usr/local/xx/xx.sh

# 创建服务器管理面板脚本
echo -e "${YELLOW}创建服务器管理面板脚本...${NC}"
echo -e "${YELLOW}创建快捷命令 'xx'...${NC}"
ln -sf /usr/local/xx/xx.sh /usr/local/bin/xx
chmod +x /usr/local/bin/xx

# 创建日志目录
mkdir -p /root/.sb_logs
touch /root/.sb_logs/main_install.log

# 清理临时文件
cd ~
rm -rf /tmp/server-setup

echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}安装完成！请记录以下重要信息：${NC}"
echo -e "${BLUE}=================================================${NC}"

# 显示SSH登录信息
SSH_PORT=$(grep "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
[ -z "$SSH_PORT" ] && SSH_PORT=22

echo -e "${YELLOW}【SSH登录信息】${NC}"
echo -e "用户名: ${GREEN}root${NC}"
echo -e "密码: ${GREEN}您在安装过程中设置的密码${NC}"
echo -e "SSH端口: ${GREEN}${SSH_PORT}${NC}"
echo -e "服务器IP: ${GREEN}$(curl -s ifconfig.me || curl -s ip.sb || curl -s ipinfo.io/ip || hostname -I | awk '{print $1}')${NC}"

echo -e "\n${RED}警告: 请立即将以上信息保存到安全的地方！${NC}"
echo -e "${RED}如果忘记密码，您可能需要重置服务器。${NC}"
echo -e "${YELLOW}注意: Linux系统中无法直接查询已设置的密码。${NC}"

# 提示用户确认
echo -e "\n${BLUE}=================================================${NC}"
echo -e "${GREEN}服务器管理面板安装完成!${NC}"
echo -e "${YELLOW}使用方法:${NC}"
echo -e "  输入 ${GREEN}xx${NC} 命令启动管理面板"
echo -e "${BLUE}=================================================${NC}"

# 自动运行系统初始化配置，不再询问
echo -e "${YELLOW}正在执行系统初始化配置...${NC}"
bash /usr/local/xx/server_init.sh
echo -e "${GREEN}系统初始化完成，现在启动管理面板...${NC}"

read -p "按回车键继续并启动服务器管理面板..." temp
echo -e "${GREEN}正在启动服务器管理面板...${NC}"

# 直接启动XX面板，使用绝对路径
/usr/local/bin/xx