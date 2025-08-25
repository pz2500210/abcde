#!/bin/bash

# 设置工作目录为脚本所在目录（如果是直接执行）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cd "$(dirname "$0")" || exit 1
    SCRIPT_DIR="$(pwd)"
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # 恢复默认颜色

# 初始化全局变量
IPV4=""
IPV6=""
LOCAL_IPV4=""
LOCAL_IPV6=""

# 获取IP地址函数
get_ip_addresses() {
    # 获取本地IPv4地址
    LOCAL_IPV4=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n 1)
    if [ -z "$LOCAL_IPV4" ]; then
        LOCAL_IPV4="未检测到IPv4地址"
    fi
    
    # 获取本地IPv6地址
    LOCAL_IPV6=$(ip -6 addr show | grep -oP '(?<=inet6\s)[\da-f:]+' | grep -v "::1" | grep -v "fe80" | head -n 1)
    if [ -z "$LOCAL_IPV6" ]; then
        LOCAL_IPV6="未检测到IPv6地址"
    fi
    
    # 获取公网IPv4地址
    IPV4=$(curl -s4 https://api.ipify.org)
    if [ -z "$IPV4" ]; then
        IPV4="未检测到公网IPv4地址"
    fi
    
    # 获取公网IPv6地址
    IPV6=$(curl -s6 https://api6.ipify.org)
    if [ -z "$IPV6" ]; then
        IPV6="未检测到公网IPv6地址"
    fi
}

# 系统工具主菜单
system_tools() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}系统工具:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请选择操作:${NC}"
    echo -e "  1) 查看系统信息"
    echo -e "  2) 网络测速"
    echo -e "  3) 端口管理"
    echo -e "  4) 系统更新"
    echo -e "  5) 卸载软件"
    echo -e "  6) 重启系统"
    echo -e "  7) 关机"
    echo -e "  0) 返回主菜单"
    
    read -p "请选择 [0-7]: " SYSTEM_OPTION
    
    case $SYSTEM_OPTION in
        1) view_system_info ;;
        2) network_speedtest ;;
        3) port_management ;;
        4) system_update ;;
        5) uninstall ;;
        6) reboot_system ;;
        7) shutdown_system ;;
        0) return ;;
        *) 
            echo -e "${RED}无效选项，请重试${NC}"
            sleep 2
            system_tools
            ;;
    esac
}

# 查看系统信息
view_system_info() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}系统信息:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 更新IP地址
    get_ip_addresses
    
    # 获取主机名
    HOSTNAME=$(hostname)
    
    # 获取操作系统信息
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS="${NAME} ${VERSION}"
    else
        OS="未知操作系统"
    fi
    
    # 获取内核版本
    KERNEL=$(uname -r)
    
    # 获取架构
    ARCH=$(uname -m)
    
    # 获取运行时间
    UPTIME=$(uptime -p)
    
    # 获取时区
    TIMEZONE=$(timedatectl | grep "Time zone" | awk '{print $3}')
    
    # 检查BBR状态
    BBR_STATUS=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [ "$BBR_STATUS" == "bbr" ]; then
        BBR_STATUS="${GREEN}已启用${NC}"
    else
        BBR_STATUS="${RED}未启用${NC}"
    fi
    
    # 获取CPU信息
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -n 1 | cut -d ":" -f2 | sed 's/^[ \t]*//')
    CPU_CORES=$(grep -c "processor" /proc/cpuinfo)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    
    # 获取内存信息
    MEM_TOTAL=$(free -h | grep -i mem | awk '{print $2}')
    MEM_USED=$(free -h | grep -i mem | awk '{print $3}')
    MEM_FREE=$(free -h | grep -i mem | awk '{print $4}')
    MEM_USAGE=$(free | grep -i mem | awk '{printf("%.2f%"), $3*100/$2}')
    
    # 获取磁盘信息
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
    
    # 获取网络连接数
    TCP_CONN=$(netstat -an | grep "tcp" | wc -l)
    UDP_CONN=$(netstat -an | grep "udp" | wc -l)
    
    # 显示系统信息
    echo -e "${YELLOW}主机名:${NC} ${HOSTNAME}"
    echo -e "${YELLOW}操作系统:${NC} ${OS}"
    echo -e "${YELLOW}内核版本:${NC} ${KERNEL}"
    echo -e "${YELLOW}系统架构:${NC} ${ARCH}"
    echo -e "${YELLOW}运行时间:${NC} ${UPTIME}"
    echo -e "${YELLOW}时区:${NC} ${TIMEZONE}"
    echo -e "${YELLOW}BBR状态:${NC} ${BBR_STATUS}"
    echo
    echo -e "${YELLOW}公网IPv4:${NC} ${IPV4}"
    echo -e "${YELLOW}公网IPv6:${NC} ${IPV6}"
    echo -e "${YELLOW}本地IPv4:${NC} ${LOCAL_IPV4}"
    echo -e "${YELLOW}本地IPv6:${NC} ${LOCAL_IPV6}"
    echo
    echo -e "${YELLOW}CPU型号:${NC} ${CPU_MODEL}"
    echo -e "${YELLOW}CPU核心数:${NC} ${CPU_CORES}"
    echo -e "${YELLOW}CPU使用率:${NC} ${CPU_USAGE}%"
    echo
    echo -e "${YELLOW}内存总量:${NC} ${MEM_TOTAL}"
    echo -e "${YELLOW}已用内存:${NC} ${MEM_USED} (${MEM_USAGE})"
    echo -e "${YELLOW}可用内存:${NC} ${MEM_FREE}"
    echo
    echo -e "${YELLOW}磁盘总量:${NC} ${DISK_TOTAL}"
    echo -e "${YELLOW}已用空间:${NC} ${DISK_USED} (${DISK_USAGE})"
    echo -e "${YELLOW}可用空间:${NC} ${DISK_FREE}"
    echo
    echo -e "${YELLOW}TCP连接数:${NC} ${TCP_CONN}"
    echo -e "${YELLOW}UDP连接数:${NC} ${UDP_CONN}"
    
    # 显示监听端口
    echo
    echo -e "${YELLOW}监听中的端口:${NC}"
    netstat -tulpn | grep LISTEN | awk '{print $4,$7}' | sed 's/:/ /g' | awk '{printf "  端口: %-5s 进程: %s\n", $2, $3}'
    
    read -p "按回车键继续..." temp
    system_tools
}

# 网络测速
network_speedtest() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}网络速度测试:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请选择测速方式:${NC}"
    echo -e "  1) 使用Speedtest进行测速"
    echo -e "  2) 简单下载速度测试"
    echo -e "  3) 路由追踪"
    echo -e "  0) 返回上级菜单"
    
    read -p "请选择 [0-3]: " SPEED_OPTION
    
    case $SPEED_OPTION in
        1) 
            # 检查Speedtest是否安装
            if ! command -v speedtest &>/dev/null; then
                echo -e "${YELLOW}Speedtest未安装，正在安装...${NC}"
                # 判断系统类型并安装Speedtest
                if [ -f /etc/debian_version ] || [ -f /etc/linuxmint/info ]; then
                    apt update
                    apt install -y curl gnupg
                    
                    # 安装官方建议的方式
                    curl -s https://install.speedtest.net/app/cli/install.deb.sh | sudo bash
                    apt install -y speedtest
                    
                    # 如果上面的方式失败，尝试使用直接安装方式
                    if ! command -v speedtest &>/dev/null; then
                        echo -e "${YELLOW}尝试备用安装方式...${NC}"
                        wget -O speedtest_cli.deb https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-$(dpkg --print-architecture).deb
                        dpkg -i speedtest_cli.deb
                        apt install -f -y
                        rm -f speedtest_cli.deb
                    fi
                elif [ -f /etc/redhat-release ]; then
                    yum install -y curl
                    curl -s https://install.speedtest.net/app/cli/install.rpm.sh | bash
                    yum install -y speedtest
                else
                    echo -e "${RED}不支持的系统类型，无法安装Speedtest${NC}"
                    echo -e "${YELLOW}尝试使用pip3安装...${NC}"
                    if command -v pip3 &>/dev/null; then
                        pip3 install speedtest-cli
                        echo -e "${GREEN}安装完成，但请使用speedtest-cli命令代替speedtest${NC}"
                        alias speedtest="speedtest-cli"
                    else
                        echo -e "${RED}pip3未安装，无法继续安装${NC}"
                        read -p "按回车键继续..." temp
                        network_speedtest
                        return
                    fi
                fi
            fi
            
            echo -e "${YELLOW}开始测速，请稍候...${NC}"
            if command -v speedtest &>/dev/null; then
                speedtest
            elif command -v speedtest-cli &>/dev/null; then
                speedtest-cli
            else
                echo -e "${RED}Speedtest安装失败，请手动安装${NC}"
                echo -e "${YELLOW}可以通过以下命令手动安装:${NC}"
                echo -e "curl -s https://install.speedtest.net/app/cli/install.deb.sh | sudo bash"
                echo -e "sudo apt install speedtest"
            fi
            ;;
        2)
            echo -e "${YELLOW}选择下载测试文件大小:${NC}"
            echo -e "  1) 100MB 文件"
            echo -e "  2) 1GB 文件"
            read -p "请选择 [1-2]: " FILE_SIZE
            
            if [ "$FILE_SIZE" = "1" ]; then
                SPEED_URL="http://cachefly.cachefly.net/100mb.test"
                SIZE="100MB"
            else
                SPEED_URL="http://cachefly.cachefly.net/1gb.test"
                SIZE="1GB"
            fi
            
            echo -e "${YELLOW}开始下载 ${SIZE} 测试文件，请稍候...${NC}"
            curl -o /dev/null $SPEED_URL --progress-bar
            ;;
        3)
            echo -e "${YELLOW}请输入要追踪的域名或IP:${NC}"
            read -p "输入 (例如 google.com): " TRACE_TARGET
            
            if [ -z "$TRACE_TARGET" ]; then
                echo -e "${RED}目标不能为空${NC}"
            else
                echo -e "${YELLOW}开始路由追踪，请稍候...${NC}"
                traceroute $TRACE_TARGET
            fi
            ;;
        0) 
            system_tools
            return
            ;;
        *)
            echo -e "${RED}无效选项，请重试${NC}"
            sleep 2
            network_speedtest
            ;;
    esac
    
    read -p "按回车键继续..." temp
    network_speedtest
}

# 端口管理
port_management() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}端口管理:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请选择操作:${NC}"
    echo -e "  1) 查看所有开放端口"
    echo -e "  2) 查看端口使用情况"
    echo -e "  3) 检查特定端口"
    echo -e "  0) 返回上级菜单"
    
    read -p "请选择 [0-3]: " PORT_OPTION
    
    case $PORT_OPTION in
        1) 
            echo -e "${YELLOW}所有开放端口:${NC}"
            netstat -tulpn | grep LISTEN
            ;;
        2) 
            echo -e "${YELLOW}端口使用情况:${NC}"
            ss -tulpn
            ;;
        3) 
            echo -e "${YELLOW}请输入要检查的端口:${NC}"
            read -p "端口: " CHECK_PORT
            
            if [ -z "$CHECK_PORT" ]; then
                echo -e "${RED}端口不能为空${NC}"
            else
                echo -e "${YELLOW}检查端口 ${CHECK_PORT}...${NC}"
                
                # 检查端口是否在使用中
                if netstat -tuln | grep -q ":$CHECK_PORT "; then
                    echo -e "${GREEN}端口 ${CHECK_PORT} 正在使用中${NC}"
                    echo -e "${YELLOW}详细信息:${NC}"
                    netstat -tulpn | grep ":$CHECK_PORT "
                else
                    echo -e "${RED}端口 ${CHECK_PORT} 未在使用${NC}"
                fi
                
                # 检查防火墙状态
                if command -v iptables &>/dev/null; then
                    if iptables -L INPUT -n | grep -q "dpt:$CHECK_PORT"; then
                        echo -e "${GREEN}端口 ${CHECK_PORT} 在防火墙中已开放${NC}"
                    else
                        echo -e "${RED}端口 ${CHECK_PORT} 在防火墙中未开放${NC}"
                    fi
                fi
                
                # 尝试连接该端口
                echo -e "${YELLOW}尝试连接到本地端口 ${CHECK_PORT}...${NC}"
                if timeout 5 bash -c "cat < /dev/null > /dev/tcp/127.0.0.1/$CHECK_PORT" 2>/dev/null; then
                    echo -e "${GREEN}连接到端口 ${CHECK_PORT} 成功${NC}"
                else
                    echo -e "${RED}连接到端口 ${CHECK_PORT} 失败${NC}"
                fi
            fi
            ;;
        0) 
            system_tools
            return
            ;;
        *)
            echo -e "${RED}无效选项，请重试${NC}"
            sleep 2
            port_management
            ;;
    esac
    
    read -p "按回车键继续..." temp
    port_management
}

# 系统更新
system_update() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}系统更新:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请选择操作:${NC}"
    echo -e "  1) 更新系统包"
    echo -e "  2) 更新脚本"
    echo -e "  0) 返回上级菜单"
    
    read -p "请选择 [0-2]: " UPDATE_OPTION
    
    case $UPDATE_OPTION in
        1) 
            echo -e "${YELLOW}正在更新系统包...${NC}"
            if [ -f /etc/debian_version ]; then
                apt update && apt upgrade -y
            elif [ -f /etc/redhat-release ]; then
                yum update -y
            else
                echo -e "${RED}不支持的系统类型${NC}"
            fi
            
            echo -e "${GREEN}系统包更新完成${NC}"
            ;;
        2) 
            echo -e "${YELLOW}更新脚本功能正在开发中...${NC}"
            ;;
        0) 
            system_tools
            return
            ;;
        *)
            echo -e "${RED}无效选项，请重试${NC}"
            sleep 2
            system_update
            ;;
    esac
    
    read -p "按回车键继续..." temp
    system_update
}

# 重启系统
reboot_system() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}重启系统:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${RED}警告: 此操作将立即重启系统!${NC}"
    echo -e "${YELLOW}是否继续? (y/n)${NC}"
    read -p "选择 [y/n]: " REBOOT_CONFIRM
    
    if [[ $REBOOT_CONFIRM =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}系统将在3秒后重启...${NC}"
        sleep 3
        reboot
    else
        echo -e "${YELLOW}重启已取消${NC}"
        read -p "按回车键继续..." temp
        system_tools
    fi
}

# 关机
shutdown_system() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}关机:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${RED}警告: 此操作将立即关闭系统!${NC}"
    echo -e "${YELLOW}是否继续? (y/n)${NC}"
    read -p "选择 [y/n]: " SHUTDOWN_CONFIRM
    
    if [[ $SHUTDOWN_CONFIRM =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}系统将在3秒后关机...${NC}"
        sleep 3
        shutdown -h now
    else
        echo -e "${YELLOW}关机已取消${NC}"
        read -p "按回车键继续..." temp
        system_tools
    fi
}

#################################################
# 卸载相关函数
#################################################

# 卸载菜单
uninstall() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}卸载:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请选择要卸载的组件:${NC}"
    echo -e "  1) 卸载Hysteria-2"
    echo -e "  2) 卸载3X-UI"
    echo -e "  3) 卸载Sing-box-yg"
    echo -e "  4) 卸载全部软件和环境"
    echo -e "  0) 返回主菜单"
        
    read -p "请选择 [0-4]: " UNINSTALL_OPTION
        
    case $UNINSTALL_OPTION in
        1) uninstall_hysteria2 ;;
 #       1) bash "${SCRIPT_DIR}/hy2.sh" ;;
        2) uninstall_3xui ;;
        3) uninstall_singbox_yg11 ;;
        4) uninstall_all ;;
        0) return ;;
        *) 
            echo -e "${RED}无效选项，请重试${NC}"
            sleep 2
            uninstall
            ;;
    esac
}

# 卸载Hysteria-2
uninstall_hysteria2() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}卸载Hysteria-2:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    :<<'COMMENT'
    # 检查是否安装
    if [ ! -f "/usr/local/bin/hysteria" ]; then
        echo -e "${RED}Hysteria-2未安装，无需卸载${NC}"
        read -p "按回车键继续..." temp
        return
    fi
    
    echo -e "${YELLOW}正在卸载Hysteria-2...${NC}"
    
    # 停止服务
    systemctl stop hysteria 2>/dev/null
    systemctl disable hysteria 2>/dev/null
        
    # 删除文件
    rm -f /usr/local/bin/hysteria
    rm -rf /etc/hysteria
    rm -f /etc/systemd/system/hysteria.service
    
    # 重新加载systemd
    systemctl daemon-reload
    
    # 从安装日志中删除
    sed -i '/Hysteria-2/d' /root/.sb_logs/main_install.log 2>/dev/null
    
    echo -e "${GREEN}Hysteria-2卸载完成${NC}"
    read -p "按回车键继续..." temp
}
COMMENT
  # 检查是否安装，如果未安装则直接退出
#    if [ ! -f "/usr/local/bin/hysteria" ]; then
#        echo -e "${RED}Hysteria-2未安装，无需卸载${NC}"
#        read -p "按回车键继续..." temp
#        return
#    fi

    # 定义卸载脚本的路径
    local uninstaller_script="${SCRIPT_DIR}/hy2.sh"
    
    # 优先使用官方卸载脚本
    if [ -f "$uninstaller_script" ]; then
        echo -e "${YELLOW}检测到官方管理脚本，将启动该脚本进行卸载...${NC}"
        echo -e "${CYAN}请在接下来的菜单中选择 '卸载' 选项以完成操作。${NC}"
        read -p "按回车键以继续..." temp
        # 执行同目录下的 hy2.sh 脚本
        bash "$uninstaller_script"
    else
        # 如果官方脚本不存在，则执行手动卸载作为备用方案
        echo -e "${YELLOW}未找到 hy2.sh 脚本，将执行手动卸载...${NC}"
        
        # 停止并禁用服务
        systemctl stop hysteria-server &>/dev/null
        systemctl disable hysteria-server &>/dev/null
        
        # 删除核心文件
        echo -e "${YELLOW}正在删除核心文件...${NC}"
        rm -f /usr/local/bin/hysteria
        rm -rf /etc/hysteria
        rm -f /etc/systemd/system/hysteria-server.service
        
        # 重新加载 systemd
        systemctl daemon-reload
    fi

    # 清理安装脚本可能生成的额外配置文件
    echo -e "${YELLOW}正在清理残留的客户端配置文件...${NC}"
    rm -f /root/Hy2-hy2-ClashMeta.yaml
    rm -f /root/Hy2-hy2-v2rayN.yaml

    # 从主安装日志中删除记录
    echo -e "${YELLOW}正在清理安装记录...${NC}"
    sed -i '/Hysteria-2/d' /root/.sb_logs/main_install.log 2>/dev/null
    
    echo -e "\n${GREEN}Hysteria-2 卸载流程执行完毕！${NC}"
    read -p "按回车键继续..." temp
}

# 卸载3X-UI
uninstall_3xui() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}卸载3X-UI:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 检查是否安装
    if [ ! -f "/usr/local/x-ui/x-ui" ] && [ ! -f "/usr/bin/x-ui" ]; then
        echo -e "${RED}3X-UI未安装，无需卸载${NC}"
        read -p "按回车键继续..." temp
        return
    fi
    
    echo -e "${YELLOW}正在卸载3X-UI...${NC}"
    
    # 使用3X-UI自带的卸载功能
    if [ -f "/usr/bin/x-ui" ]; then
        x-ui uninstall
    else
        # 手动卸载
        systemctl stop x-ui 2>/dev/null
        systemctl disable x-ui 2>/dev/null
        rm -rf /usr/local/x-ui
        rm -f /usr/bin/x-ui
        rm -f /etc/systemd/system/x-ui.service
        systemctl daemon-reload
    fi
    
    # 从安装日志中删除
    sed -i '/3X-UI/d' /root/.sb_logs/main_install.log 2>/dev/null
    
    echo -e "${GREEN}3X-UI卸载完成${NC}"
    read -p "按回车键继续..." temp
}

# 卸载Sing-box-yg
uninstall_singbox_yg11() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}卸载Sing-box-yg:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 检查是否安装
    if [ ! -f "/usr/local/bin/sing-box" ]; then
        echo -e "${RED}Sing-box-yg未安装，无需卸载${NC}"
        read -p "按回车键继续..." temp
        return
    fi
    
    echo -e "${YELLOW}正在卸载Sing-box-yg...${NC}"
    
    # 使用Sing-box-yg自带的卸载功能
    bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh) uninstall
    
    # 如果自带卸载失败，手动卸载
    if [ -f "/usr/local/bin/sing-box" ]; then
        # 停止服务
        systemctl stop sing-box 2>/dev/null
        systemctl disable sing-box 2>/dev/null
        
        # 删除文件
        rm -f /usr/local/bin/sing-box
        rm -rf /usr/local/etc/sing-box
        rm -f /etc/systemd/system/sing-box.service
        
        # 重新加载systemd
        systemctl daemon-reload
    fi
    
    # 从安装日志中删除
    sed -i '/Sing-box-yg/d' /root/.sb_logs/main_install.log 2>/dev/null
    
    echo -e "${GREEN}Sing-box-yg卸载完成${NC}"
    read -p "按回车键继续..." temp
}

# 卸载全部软件和环境
uninstall_all() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}卸载全部软件和环境:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${RED}警告: 此操作将卸载所有已安装的软件和环境!${NC}"
    echo -e "${YELLOW}是否继续? (y/n)${NC}"
    read -p "选择 [y/n]: " CONFIRM
    
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消卸载${NC}"
        read -p "按回车键继续..." temp
        return
    fi
    
    echo -e "${YELLOW}开始卸载所有软件...${NC}"
    
    # 卸载Hysteria-2
    if [ -f "/usr/local/bin/hysteria" ]; then
        echo -e "${YELLOW}卸载Hysteria-2...${NC}"
        uninstall_hysteria2
    fi
    
    # 卸载3X-UI
    if [ -f "/usr/local/x-ui/x-ui" ] || [ -f "/usr/bin/x-ui" ]; then
        echo -e "${YELLOW}卸载3X-UI...${NC}"
        uninstall_3xui
    fi
    
    # 卸载Sing-box-yg
    if [ -f "/usr/local/bin/sing-box" ]; then
        echo -e "${YELLOW}卸载Sing-box-yg...${NC}"
        uninstall_singbox_yg
    fi
    
    # 删除证书和配置文件
    echo -e "${YELLOW}删除证书和配置文件...${NC}"
    rm -rf /root/.acme.sh
    rm -rf /root/cert
    
    # 删除安装日志
    echo -e "${YELLOW}删除安装日志...${NC}"
    rm -rf /root/.sb_logs
    
    # 删除防火墙配置
    echo -e "${YELLOW}重置防火墙配置...${NC}"
    if command -v ufw &>/dev/null; then
        ufw reset
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --zone=public --remove-service=http
        firewall-cmd --permanent --zone=public --remove-service=https
        firewall-cmd --permanent --zone=public --remove-port=80/tcp
        firewall-cmd --permanent --zone=public --remove-port=443/tcp
        firewall-cmd --reload
    elif command -v iptables &>/dev/null; then
        iptables -F
        iptables -X
        iptables -P INPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT
        if command -v ip6tables &>/dev/null; then
            ip6tables -F
            ip6tables -X
            ip6tables -P INPUT ACCEPT
            ip6tables -P FORWARD ACCEPT
            ip6tables -P OUTPUT ACCEPT
        fi
        if command -v iptables-save >/dev/null 2>&1; then
            if [ -d "/etc/iptables" ]; then
                iptables-save > /etc/iptables/rules.v4
                if command -v ip6tables-save >/dev/null 2>&1; then
                    ip6tables-save > /etc/iptables/rules.v6
                fi
            fi
        fi
    fi
    
    echo -e "${GREEN}所有软件和环境已卸载完成${NC}"
    echo -e "${YELLOW}建议重启系统以完成清理${NC}"
    echo -e "是否立即重启系统? (y/n)"
    read -p "选择 [y/n]: " REBOOT_OPTION
    
    if [[ $REBOOT_OPTION =~ ^[Yy]$ ]]; then
        reboot
    else
        read -p "按回车键继续..." temp
    fi
}

# 主函数 - 仅供单独运行脚本时使用
main() {
    get_ip_addresses
    system_tools
}

# 仅当直接执行此脚本而非被导入时运行main函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi