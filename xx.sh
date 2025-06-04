#!/bin/bash

# 强制设置工作目录为脚本所在目录
cd "$(dirname "$(readlink -f "$0")")" || cd "/usr/local/xx" || exit 1

# 确保正确加载模块
SCRIPT_DIR="$(pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 全局IP地址变量
PUBLIC_IPV4=""
PUBLIC_IPV6=""
LOCAL_IPV4=""
LOCAL_IPV6=""

# 引入模块文件
source "${SCRIPT_DIR}/proxy_bbr.sh"
source "${SCRIPT_DIR}/cert_dns.sh"
source "${SCRIPT_DIR}/system_tools.sh"
source "${SCRIPT_DIR}/firewall.sh"

# 获取IP地址的函数
get_ip_addresses() {
    # 获取本地IP地址
    LOCAL_IPV4=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -1)
    LOCAL_IPV6=$(ip -6 addr show | grep -oP '(?<=inet6\s)[\da-f:]+' | grep -v "::1" | grep -v "fe80" | head -1)
    
    # 使用本地IP作为公网IP（如果无法获取公网IP）
    PUBLIC_IPV4=$LOCAL_IPV4
    PUBLIC_IPV6=$LOCAL_IPV6
    
    # 尝试获取公网IP（只使用一个服务，减少超时时间）
    TEMP_IPV4=$(curl -s -m 1 https://api.ipify.org 2>/dev/null)
    if [ ! -z "$TEMP_IPV4" ]; then
        PUBLIC_IPV4=$TEMP_IPV4
    fi
    
    TEMP_IPV6=$(curl -s -m 1 https://api6.ipify.org 2>/dev/null)
    if [ ! -z "$TEMP_IPV6" ]; then
        PUBLIC_IPV6=$TEMP_IPV6
    fi
}

# 更新主安装日志
update_main_install_log() {
    local component=$1
    local log_file="/root/.sb_logs/main_install.log"
    
    # 创建日志目录和文件（如果不存在）
    mkdir -p /root/.sb_logs
    touch $log_file
    
    # 添加安装记录
    echo "$component:$(date "+%Y-%m-%d %H:%M:%S")" >> $log_file
}

# 获取BBR状态的函数
get_bbr_status() {
    local bbr_status=""
    local congestion_control=""
    
    # 尝试获取当前的拥塞控制算法
    if command -v sysctl &>/dev/null; then
        congestion_control=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    fi
    
    # 检查本地安装记录
    if [ -f "/root/.sb_logs/bbr_installed.log" ]; then
        if grep -q "BBRplus" "/root/.sb_logs/bbr_installed.log"; then
            # 如果本地记录显示安装了BBRplus
            if [ "$congestion_control" = "bbrplus" ]; then
                bbr_status="已启用BBRplus"
            else
                bbr_status="已安装BBRplus但未启用"
            fi
        elif grep -q "BBR" "/root/.sb_logs/bbr_installed.log"; then
            # 如果本地记录显示安装了BBR
            if [ "$congestion_control" = "bbr" ]; then
                bbr_status="已启用BBR"
            else
                bbr_status="已安装BBR但未启用"
            fi
        fi
    fi
    
    # 如果没有从安装记录获取到信息，则根据当前拥塞控制算法判断
    if [ -z "$bbr_status" ]; then
        case "$congestion_control" in
            bbr)
                bbr_status="已启用BBR"
                ;;
            bbrplus)
                bbr_status="已启用BBRplus"
                ;;
            cubic)
                bbr_status="未启用加速 (cubic)"
                ;;
            reno)
                bbr_status="未启用加速 (reno)"
                ;;
            *)
                if [ -z "$congestion_control" ]; then
                    bbr_status="未检测到拥塞控制算法"
                else
                    bbr_status="使用 $congestion_control"
                fi
                ;;
        esac
    fi
    
    echo "$bbr_status"
}

# 显示横幅
show_banner() {
    clear
    # 不需要重新获取IP地址，使用全局变量
    
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}           服务器管理面板 v1.0                  ${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${YELLOW}系统信息:${NC}"
    echo -e "  主机名: $(hostname)"
    echo -e "  系统版本: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
    echo -e "  内核版本: $(uname -r)"
    echo -e "  架构: $(uname -m)"
    echo -e "  公网IPv4: ${PUBLIC_IPV4}"
    if [ ! -z "$PUBLIC_IPV6" ]; then
        echo -e "  公网IPv6: ${PUBLIC_IPV6}"
    elif [ ! -z "$LOCAL_IPV6" ]; then
        echo -e "  IPv6地址: ${LOCAL_IPV6}"
    fi
    echo -e "  内网IPv4: ${LOCAL_IPV4}"
    echo -e "  时区: $(timedatectl | grep 'Time zone' | awk '{print $3}')"
    echo -e "  BBR状态: $(get_bbr_status)"
    echo -e "${BLUE}=================================================${NC}"
}

# 显示主菜单
show_main_menu() {
    echo -e "${YELLOW}请选择操作:${NC}"
    echo -e "  ${GREEN}1.${NC} 安装Hysteria-2"
    echo -e "  ${GREEN}2.${NC} 安装3X-UI"
    echo -e "  ${GREEN}3.${NC} 安装Sing-box-yg"
    echo -e "  ${GREEN}4.${NC} 防火墙设置"
    echo -e "  ${GREEN}5.${NC} 安装SSL证书"
    echo -e "  ${GREEN}6.${NC} DNS认证管理"
    echo -e "  ${GREEN}7.${NC} 安装BBR加速"
    echo -e "  ${GREEN}8.${NC} 系统工具"
    echo -e "  ${GREEN}9.${NC} 卸载"
    echo -e "  ${GREEN}0.${NC} 退出"
    echo -e "${BLUE}=================================================${NC}"
}

# 创建xx命令快捷方式
create_xx_shortcut() {
    # 获取当前脚本的绝对路径
    local SCRIPT_ABSOLUTE_PATH=$(readlink -f "$0")
    local SCRIPT_ABSOLUTE_DIR=$(dirname "$SCRIPT_ABSOLUTE_PATH")
    
    if [ ! -f "/usr/local/bin/xx" ]; then
        echo '#!/bin/bash' > /usr/local/bin/xx
        # 直接在快捷方式中指定正确的模块文件路径
        echo "SCRIPT_MODULES_DIR=\"/usr/local/xx\"" > /usr/local/bin/xx
        echo "cd \"\$SCRIPT_MODULES_DIR\" && bash \"\$SCRIPT_MODULES_DIR/xx.sh\"" >> /usr/local/bin/xx
        chmod +x /usr/local/bin/xx
        echo -e "${GREEN}快捷命令 'xx' 已创建，指向固定目录 /usr/local/xx${NC}"
    fi
}

# 主函数
main() {
    # 检查必要的脚本文件是否存在
    local missing_files=false
    for file in "proxy_bbr.sh" "cert_dns.sh" "system_tools.sh" "firewall.sh"; do
        if [ ! -f "${SCRIPT_DIR}/$file" ]; then
            echo -e "${RED}错误：找不到必需的脚本文件 ${SCRIPT_DIR}/$file${NC}"
            missing_files=true
        fi
    done
    
    if [ "$missing_files" = true ]; then
        echo -e "${YELLOW}提示：确保所有必需的脚本文件与xx.sh位于同一目录中${NC}"
        read -p "按回车键退出..." temp
        exit 1
    fi
    
    # 在脚本开始时获取IP地址，确保所有函数都使用相同的值
    get_ip_addresses
    
    # 在脚本开始时调用
    create_xx_shortcut

    # 确保日志目录存在
    mkdir -p /root/.sb_logs
    
    while true; do
        show_banner
        show_main_menu
        
        read -p "请选择 [0-9]: " OPTION
        
        case $OPTION in
            1) hysteria2_management ;;
            2) xui_management ;;
            3) singbox_management ;;
            4) firewall_settings ;;
            5) certificate_management ;;
            6) dns_management ;;
            7) bbr_management ;;
            8) system_tools ;;
            9) uninstall ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效选项，请重试${NC}" ;;
        esac
    done
}

# 确保只调用main函数，不要调用其他函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 如果是直接执行此脚本，而不是被source
    main "$@"
fi