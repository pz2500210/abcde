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
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 全局IP地址变量
PUBLIC_IPV4=""
PUBLIC_IPV6=""
LOCAL_IPV4=""
LOCAL_IPV6=""

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

# 防火墙设置
firewall_settings() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}防火墙设置:${NC}"
    echo -e "${BLUE}=================================================${NC}"
                
    # 检测防火墙类型
    local firewall_type=""
    if command -v ufw &>/dev/null; then
        firewall_type="ufw"
    elif command -v firewall-cmd &>/dev/null; then
        firewall_type="firewalld"
    elif command -v iptables &>/dev/null; then
        # 检查是否有ufw或firewalld作为前端
        if systemctl is-active ufw &>/dev/null || systemctl is-active firewalld &>/dev/null; then
            if systemctl is-active ufw &>/dev/null; then
                firewall_type="ufw"
            else
                firewall_type="firewalld"
            fi
        else
            firewall_type="iptables"
        fi
    else
        echo -e "${RED}未检测到支持的防火墙${NC}"
        read -p "按回车键继续..." temp
        return
    fi
    
    echo -e "${YELLOW}检测到防火墙类型: $firewall_type${NC}"
    echo -e "${YELLOW}请选择操作:${NC}"
    echo -e "  1) 查看防火墙状态"
    echo -e "  2) 开启防火墙"
    echo -e "  3) 关闭防火墙"
    echo -e "  4) 开放端口 (IPv4)"
    echo -e "  5) 关闭端口 (IPv4)"
    echo -e "  6) 自动配置应用端口"
    echo -e "  7) 开放端口 (IPv6)"
    echo -e "  8) 关闭端口 (IPv6)"
    echo -e "  0) 返回"
    
    read -p "请选择 [0-8]: " FW_OPTION
                
    case $FW_OPTION in
        1) 
            echo -e "${YELLOW}防火墙状态:${NC}"
            case $firewall_type in
                ufw) 
                    echo -e "${YELLOW}UFW防火墙状态:${NC}"
                    ufw status
                    echo -e "\n${YELLOW}iptables规则 (IPv4):${NC}"
                    iptables -L INPUT -n -v --line-numbers
                    
                    # 检查并显示IPv6规则
                    if command -v ip6tables &>/dev/null; then
                        echo -e "\n${YELLOW}ip6tables规则 (IPv6):${NC}"
                        ip6tables -L INPUT -n -v --line-numbers
                    fi
                    ;;
                firewalld) 
                    echo -e "${YELLOW}firewalld防火墙状态:${NC}"
                    firewall-cmd --state
                    echo -e "\n${YELLOW}iptables规则 (IPv4):${NC}"
                    iptables -L INPUT -n -v --line-numbers
                    
                    # 检查并显示IPv6规则
                    if command -v ip6tables &>/dev/null; then
                        echo -e "\n${YELLOW}ip6tables规则 (IPv6):${NC}"
                        ip6tables -L INPUT -n -v --line-numbers
                    fi
                    ;;
                iptables) 
                    echo -e "${YELLOW}iptables防火墙状态:${NC}"
                    iptables -L INPUT -n -v --line-numbers
                    
                    # 检查并显示IPv6规则
                    if command -v ip6tables &>/dev/null; then
                        echo -e "\n${YELLOW}ip6tables规则 (IPv6):${NC}"
                        ip6tables -L INPUT -n -v --line-numbers
                    fi
                    ;;
            esac
            ;;
        2) 
            echo -e "${YELLOW}开启防火墙...${NC}"
            case $firewall_type in
                ufw) 
                    ufw enable
                    ;;
                firewalld) 
                    systemctl start firewalld && systemctl enable firewalld
                    ;;
                iptables) 
                    # 在iptables模式下，不尝试启动服务，而是直接应用规则
                    echo -e "${YELLOW}在纯iptables模式下，需要手动设置规则...${NC}"
                    echo -e "${YELLOW}应用基本规则...${NC}"
                    
                    # 保存当前规则
                    iptables-save > /tmp/iptables.rules.bak
                    
                    # 清空现有规则
                    iptables -F
                    iptables -X
                    iptables -t nat -F
                    iptables -t nat -X
                    iptables -t mangle -F
                    iptables -t mangle -X
                    
                    # 允许已建立的连接
                    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                    
                    # 允许本地回环接口
                    iptables -A INPUT -i lo -j ACCEPT
                    
                    # 允许SSH (重要！否则可能无法连接服务器)
                    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
                    
                    # 允许常用端口
                    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
                    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
                    
                    # 自动添加已安装应用的端口
                    auto_add_app_ports "iptables"
                    
                    # 重要：设置默认拒绝策略（这才是真正的防火墙）
                    echo -e "${YELLOW}设置默认拒绝策略...${NC}"
                    iptables -P INPUT DROP
                    iptables -P FORWARD DROP
                    # OUTPUT允许，使服务器可以主动发起连接
                    iptables -P OUTPUT ACCEPT
                    
                    # 配置IPv6防火墙（如果可用）
                    if command -v ip6tables >/dev/null 2>&1; then
                        echo -e "${YELLOW}配置IPv6防火墙...${NC}"
                        # 清空现有IPv6规则
                        ip6tables -F
                        ip6tables -X
                        ip6tables -t mangle -F
                        ip6tables -t mangle -X
                        
                        # 允许已建立的连接
                        ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                        
                        # 允许本地回环接口
                        ip6tables -A INPUT -i lo -j ACCEPT
                        
                        # 允许SSH (重要！)
                        ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT
                        
                        # 允许常用端口
                        ip6tables -A INPUT -p tcp --dport 80 -j ACCEPT
                        ip6tables -A INPUT -p tcp --dport 443 -j ACCEPT
                        
                        # 自动添加已安装应用的端口到IPv6规则
                        # 这里我们依赖auto_add_app_ports函数，它会同时处理IPv4和IPv6
                        
                        # 设置默认拒绝策略
                        ip6tables -P INPUT DROP
                        ip6tables -P FORWARD DROP
                        ip6tables -P OUTPUT ACCEPT
                    fi
                    
                    # 保存规则
                    if command -v iptables-save >/dev/null 2>&1; then
                        echo -e "${YELLOW}保存防火墙规则...${NC}"
                        if [ -d "/etc/iptables" ]; then
                            iptables-save > /etc/iptables/rules.v4
                        else
                            mkdir -p /etc/iptables
                            iptables-save > /etc/iptables/rules.v4
                        fi
                        
                        # 保存IPv6规则
                        if command -v ip6tables-save >/dev/null 2>&1 && command -v ip6tables >/dev/null 2>&1; then
                            ip6tables-save > /etc/iptables/rules.v6
                        fi
                        
                        # 创建启动脚本确保规则持久化
                        cat > /etc/network/if-pre-up.d/iptables << 'EOF'
#!/bin/bash
/sbin/iptables-restore < /etc/iptables/rules.v4
if [ -f /etc/iptables/rules.v6 ]; then
    /sbin/ip6tables-restore < /etc/iptables/rules.v6
fi
EOF
                        chmod +x /etc/network/if-pre-up.d/iptables
                        echo -e "${GREEN}防火墙规则已保存并设置开机自启${NC}"
                    else
                        echo -e "${RED}iptables-save命令不可用，无法保存规则${NC}"
                    fi
                    
                    echo -e "${GREEN}防火墙已启用，提供了真正的安全保护${NC}"
                    echo -e "${YELLOW}注意：现在只有特定端口允许连接，其他所有连接都会被拒绝${NC}"
                    ;;
            esac
            ;;
        3) 
            echo -e "${YELLOW}关闭防火墙...${NC}"
            case $firewall_type in
                ufw) ufw disable ;;
                firewalld) systemctl stop firewalld && systemctl disable firewalld ;;
                iptables) 
                    # 清空所有规则
                    iptables -F
                    iptables -X
                    iptables -t nat -F
                    iptables -t nat -X
                    iptables -t mangle -F
                    iptables -t mangle -X
                    iptables -P INPUT ACCEPT
                    iptables -P FORWARD ACCEPT
                    iptables -P OUTPUT ACCEPT
                    
                    # 如果支持IPv6，也清空IPv6规则
                    if command -v ip6tables >/dev/null 2>&1; then
                        ip6tables -F
                        ip6tables -X
                        ip6tables -t mangle -F
                        ip6tables -t mangle -X
                        ip6tables -P INPUT ACCEPT
                        ip6tables -P FORWARD ACCEPT
                        ip6tables -P OUTPUT ACCEPT
                    fi
                    
                    # 保存空规则
                    if command -v iptables-save >/dev/null 2>&1; then
                        if [ -d "/etc/iptables" ]; then
                            iptables-save > /etc/iptables/rules.v4
                            
                            # 保存IPv6规则
                            if command -v ip6tables-save >/dev/null 2>&1; then
                                ip6tables-save > /etc/iptables/rules.v6
                            fi
                        fi
                    fi
                    
                    echo -e "${GREEN}已清空所有iptables规则${NC}"
                    ;;
            esac
            ;;
        4) # 开放IPv4端口
            echo -e "${YELLOW}请输入要开放的IPv4端口:${NC}"
            read -p "端口: " OPEN_PORT
            
            if [ -z "$OPEN_PORT" ]; then
                echo -e "${RED}端口不能为空${NC}"
            else
                echo -e "${YELLOW}请选择协议:${NC}"
                echo -e "  1) TCP"
                echo -e "  2) UDP"
                echo -e "  3) TCP+UDP (两者都开放)"
                read -p "选择 [1-3] (默认: 3): " PROTOCOL_OPTION
                PROTOCOL_OPTION=${PROTOCOL_OPTION:-3}
                
                echo -e "${YELLOW}开放IPv4端口 $OPEN_PORT...${NC}"
                case $firewall_type in
                    ufw) 
                        case $PROTOCOL_OPTION in
                            1) ufw allow $OPEN_PORT/tcp ;;
                            2) ufw allow $OPEN_PORT/udp ;;
                            *) ufw allow $OPEN_PORT/tcp && ufw allow $OPEN_PORT/udp ;;
                        esac
                        ;;
                    firewalld) 
                        case $PROTOCOL_OPTION in
                            1) firewall-cmd --permanent --add-port=$OPEN_PORT/tcp ;;
                            2) firewall-cmd --permanent --add-port=$OPEN_PORT/udp ;;
                            *) 
                                firewall-cmd --permanent --add-port=$OPEN_PORT/tcp 
                                firewall-cmd --permanent --add-port=$OPEN_PORT/udp 
                                ;;
                        esac
                        firewall-cmd --reload 
                        ;;
                    iptables) 
                        case $PROTOCOL_OPTION in
                            1) iptables -A INPUT -p tcp --dport $OPEN_PORT -j ACCEPT ;;
                            2) iptables -A INPUT -p udp --dport $OPEN_PORT -j ACCEPT ;;
                            *) 
                                iptables -A INPUT -p tcp --dport $OPEN_PORT -j ACCEPT
                                iptables -A INPUT -p udp --dport $OPEN_PORT -j ACCEPT
                                ;;
                        esac
                        
                        # 保存规则
                        if command -v iptables-save >/dev/null 2>&1; then
                            if [ -d "/etc/iptables" ]; then
                                iptables-save > /etc/iptables/rules.v4
                            fi
                        fi
                        ;;
                esac
                echo -e "${GREEN}IPv4端口 $OPEN_PORT 已开放${NC}"
            fi
            ;;
        5) # 关闭IPv4端口
            echo -e "${YELLOW}请输入要关闭的IPv4端口:${NC}"
            read -p "端口: " CLOSE_PORT
            
            if [ -z "$CLOSE_PORT" ]; then
                echo -e "${RED}端口不能为空${NC}"
            else
                echo -e "${YELLOW}请选择协议:${NC}"
                echo -e "  1) TCP"
                echo -e "  2) UDP"
                echo -e "  3) TCP+UDP (两者都关闭)"
                read -p "选择 [1-3] (默认: 3): " PROTOCOL_OPTION
                PROTOCOL_OPTION=${PROTOCOL_OPTION:-3}
                
                echo -e "${YELLOW}关闭IPv4端口 $CLOSE_PORT...${NC}"
                case $firewall_type in
                    ufw) 
                        case $PROTOCOL_OPTION in
                            1) ufw delete allow $CLOSE_PORT/tcp ;;
                            2) ufw delete allow $CLOSE_PORT/udp ;;
                            *) ufw delete allow $CLOSE_PORT/tcp && ufw delete allow $CLOSE_PORT/udp ;;
                        esac
                        ;;
                    firewalld) 
                        case $PROTOCOL_OPTION in
                            1) firewall-cmd --permanent --remove-port=$CLOSE_PORT/tcp ;;
                            2) firewall-cmd --permanent --remove-port=$CLOSE_PORT/udp ;;
                            *) 
                                firewall-cmd --permanent --remove-port=$CLOSE_PORT/tcp 
                                firewall-cmd --permanent --remove-port=$CLOSE_PORT/udp 
                                ;;
                        esac
                        firewall-cmd --reload 
                        ;;
                    iptables) 
                        case $PROTOCOL_OPTION in
                            1) iptables -D INPUT -p tcp --dport $CLOSE_PORT -j ACCEPT 2>/dev/null ;;
                            2) iptables -D INPUT -p udp --dport $CLOSE_PORT -j ACCEPT 2>/dev/null ;;
                            *) 
                                iptables -D INPUT -p tcp --dport $CLOSE_PORT -j ACCEPT 2>/dev/null
                                iptables -D INPUT -p udp --dport $CLOSE_PORT -j ACCEPT 2>/dev/null
                                ;;
                        esac
                        
                        # 保存规则
                        if command -v iptables-save >/dev/null 2>&1; then
                            if [ -d "/etc/iptables" ]; then
                                iptables-save > /etc/iptables/rules.v4
                            fi
                        fi
                        ;;
                esac
                echo -e "${GREEN}IPv4端口 $CLOSE_PORT 已关闭${NC}"
            fi
            ;;
        6) # 自动配置应用端口
            echo -e "${YELLOW}自动配置已安装应用的端口...${NC}"
            auto_add_app_ports "$firewall_type"
            echo -e "${GREEN}应用端口已配置完成${NC}"
            ;;
        7) # 开放IPv6端口
            # 检查是否支持IPv6
            if ! command -v ip6tables &>/dev/null; then
                echo -e "${RED}系统不支持IPv6或ip6tables命令不可用${NC}"
                read -p "按回车键继续..." temp
                firewall_settings
                return
            fi
            
            echo -e "${YELLOW}请输入要开放的IPv6端口:${NC}"
            read -p "端口: " OPEN_PORT
            
            if [ -z "$OPEN_PORT" ]; then
                echo -e "${RED}端口不能为空${NC}"
            else
                echo -e "${YELLOW}请选择协议:${NC}"
                echo -e "  1) TCP"
                echo -e "  2) UDP"
                echo -e "  3) TCP+UDP (两者都开放)"
                read -p "选择 [1-3] (默认: 3): " PROTOCOL_OPTION
                PROTOCOL_OPTION=${PROTOCOL_OPTION:-3}
                
                echo -e "${YELLOW}开放IPv6端口 $OPEN_PORT...${NC}"
                case $PROTOCOL_OPTION in
                    1) ip6tables -A INPUT -p tcp --dport $OPEN_PORT -j ACCEPT ;;
                    2) ip6tables -A INPUT -p udp --dport $OPEN_PORT -j ACCEPT ;;
                    *) 
                        ip6tables -A INPUT -p tcp --dport $OPEN_PORT -j ACCEPT
                        ip6tables -A INPUT -p udp --dport $OPEN_PORT -j ACCEPT
                        ;;
                esac
                
                # 保存规则
                if command -v ip6tables-save >/dev/null 2>&1; then
                    if [ -d "/etc/iptables" ]; then
                        mkdir -p /etc/iptables
                        ip6tables-save > /etc/iptables/rules.v6
                    fi
                fi
                
                echo -e "${GREEN}IPv6端口 $OPEN_PORT 已开放${NC}"
            fi
            ;;
        8) # 关闭IPv6端口
            # 检查是否支持IPv6
            if ! command -v ip6tables &>/dev/null; then
                echo -e "${RED}系统不支持IPv6或ip6tables命令不可用${NC}"
                read -p "按回车键继续..." temp
                firewall_settings
                return
            fi
            
            echo -e "${YELLOW}请输入要关闭的IPv6端口:${NC}"
            read -p "端口: " CLOSE_PORT
            
            if [ -z "$CLOSE_PORT" ]; then
                echo -e "${RED}端口不能为空${NC}"
            else
                echo -e "${YELLOW}请选择协议:${NC}"
                echo -e "  1) TCP"
                echo -e "  2) UDP"
                echo -e "  3) TCP+UDP (两者都关闭)"
                read -p "选择 [1-3] (默认: 3): " PROTOCOL_OPTION
                PROTOCOL_OPTION=${PROTOCOL_OPTION:-3}
                
                echo -e "${YELLOW}关闭IPv6端口 $CLOSE_PORT...${NC}"
                case $PROTOCOL_OPTION in
                    1) ip6tables -D INPUT -p tcp --dport $CLOSE_PORT -j ACCEPT 2>/dev/null ;;
                    2) ip6tables -D INPUT -p udp --dport $CLOSE_PORT -j ACCEPT 2>/dev/null ;;
                    *) 
                        ip6tables -D INPUT -p tcp --dport $CLOSE_PORT -j ACCEPT 2>/dev/null
                        ip6tables -D INPUT -p udp --dport $CLOSE_PORT -j ACCEPT 2>/dev/null
                        ;;
                esac
                
                # 保存规则
                if command -v ip6tables-save >/dev/null 2>&1; then
                    if [ -d "/etc/iptables" ]; then
                        mkdir -p /etc/iptables
                        ip6tables-save > /etc/iptables/rules.v6
                    fi
                fi
                
                echo -e "${GREEN}IPv6端口 $CLOSE_PORT 已关闭${NC}"
            fi
            ;;
        0) 
            return
            ;;
        *) 
            echo -e "${RED}无效选项，请重试${NC}"
            sleep 2
            firewall_settings
            ;;
    esac
                
    read -p "按回车键继续..." temp
    firewall_settings
}

# 检查端口规则是否已存在，避免重复添加
port_rule_exists() {
    local port=$1
    local protocol=$2  # tcp or udp
    
    if iptables -L INPUT -n | grep -q "$protocol dpt:$port"; then
        return 0  # 规则已存在
    else
        return 1  # 规则不存在
    fi
}

# 增强型自动配置应用端口函数，可以处理删除和修改的端口
auto_add_app_ports() {
    local firewall_type=$1
    local ports_added=0
    local active_ports=()
    
    echo -e "${YELLOW}检测已安装应用的端口...${NC}"
    
    # 创建临时文件存储当前活跃端口
    local temp_active_ports="/tmp/active_ports.txt"
    touch $temp_active_ports
    
    # 使用netstat直接检测应用端口
    echo -e "${YELLOW}从运行进程中检测端口...${NC}"
    
    # 检测所有活跃的端口并记录
    collect_active_ports() {
        # 检测x-ui面板端口
        X_UI_PORTS=$(netstat -tulpn 2>/dev/null | grep 'x-ui' | awk '{print $4}' | grep -o '[0-9]*$' | sort -u)
        for port in $X_UI_PORTS; do
            if [ ! -z "$port" ]; then
                echo "$port" >> $temp_active_ports
                echo -e "${GREEN}检测到3X-UI面板端口: ${port}${NC}"
                active_ports+=("$port")
            fi
        done
        
        # 检测xray入站端口
        XRAY_PORTS=$(netstat -tulpn 2>/dev/null | grep -E 'xray|v2ray' | awk '{print $4}' | grep -o '[0-9]*$' | sort -u)
        for port in $XRAY_PORTS; do
            if [ ! -z "$port" ]; then
                echo "$port" >> $temp_active_ports
                echo -e "${GREEN}检测到Xray入站端口: ${port}${NC}"
                active_ports+=("$port")
            fi
        done
        
        # 检测hysteria端口
        HYSTERIA_PORTS=$(netstat -tulpn 2>/dev/null | grep -E 'hysteria' | awk '{print $4}' | grep -o '[0-9]*$' | sort -u)
        for port in $HYSTERIA_PORTS; do
            if [ ! -z "$port" ]; then
                echo "$port" >> $temp_active_ports
                echo -e "${GREEN}检测到Hysteria端口: ${port}${NC}"
                active_ports+=("$port")
            fi
        done
        
        # 检查3X-UI中配置的入站规则端口
        if [ -f "/usr/local/x-ui/db/x-ui.db" ]; then
            echo -e "${YELLOW}检测3X-UI入站规则端口...${NC}"
            # 如果有sqlite3命令可用
            if command -v sqlite3 &>/dev/null; then
                INBOUND_PORTS=$(sqlite3 /usr/local/x-ui/db/x-ui.db "SELECT port FROM inbounds WHERE enable = 1;" 2>/dev/null)
                for port in $INBOUND_PORTS; do
                    if [ ! -z "$port" ]; then
                        echo "$port" >> $temp_active_ports
                        echo -e "${GREEN}检测到入站规则端口: ${port}${NC}"
                        active_ports+=("$port")
                    fi
                done
            else
                echo -e "${YELLOW}未找到sqlite3命令，尝试安装...${NC}"
                # 尝试安装sqlite3
                if [ -f /etc/debian_version ]; then
                    apt update && apt install -y sqlite3
                elif [ -f /etc/redhat-release ]; then
                    yum install -y sqlite
                fi
                
                # 重新尝试
                if command -v sqlite3 &>/dev/null; then
                    INBOUND_PORTS=$(sqlite3 /usr/local/x-ui/db/x-ui.db "SELECT port FROM inbounds WHERE enable = 1;" 2>/dev/null)
                    for port in $INBOUND_PORTS; do
                        if [ ! -z "$port" ]; then
                            echo "$port" >> $temp_active_ports
                            echo -e "${GREEN}检测到入站规则端口: ${port}${NC}"
                            active_ports+=("$port")
                        fi
                    done
                else
                    echo -e "${YELLOW}无法安装sqlite3，使用备用方法检测端口...${NC}"
                fi
            fi
        fi
        
        # 检查Hysteria-2配置文件
        if [ -f "/etc/hysteria/config.json" ]; then
            # 从config.json中提取端口
            HY2_PORT=$(grep -o '"listen": "[^"]*"' /etc/hysteria/config.json | grep -o '[0-9]*')
            if [ -z "$HY2_PORT" ]; then
                # 尝试另一种格式
                HY2_PORT=$(grep -o '"listen": ":.*"' /etc/hysteria/config.json | grep -o '[0-9]*')
            fi
            
            if [ ! -z "$HY2_PORT" ]; then
                echo "$HY2_PORT" >> $temp_active_ports
                echo -e "${GREEN}检测到Hysteria-2端口: ${HY2_PORT}${NC}"
                active_ports+=("$HY2_PORT")
            fi
        elif [ -f "/etc/hysteria/server.json" ]; then
            # 旧版本配置文件
            HY2_PORT=$(grep -o '"listen": "[^"]*"' /etc/hysteria/server.json | grep -o '[0-9]*')
            if [ -z "$HY2_PORT" ]; then
                # 尝试另一种格式
                HY2_PORT=$(grep -o '"listen": ":.*"' /etc/hysteria/server.json | grep -o '[0-9]*')
            fi
            
            if [ ! -z "$HY2_PORT" ]; then
                echo "$HY2_PORT" >> $temp_active_ports
                echo -e "${GREEN}检测到Hysteria-2端口: ${HY2_PORT}${NC}"
                active_ports+=("$HY2_PORT")
            fi
        fi
        
        # 添加常用系统端口（仅记录端口号，不添加到active_ports数组）
        echo "22" >> $temp_active_ports  # SSH
        echo "80" >> $temp_active_ports  # HTTP
        echo "443" >> $temp_active_ports # HTTPS
        
        # 去重
        sort -u $temp_active_ports -o $temp_active_ports
    }
    
    # 收集活跃端口
    collect_active_ports
    
    # 添加活跃端口到防火墙
    for port in "${active_ports[@]}"; do
        case $firewall_type in
            ufw) 
                ufw status | grep -q "$port/tcp" || ufw allow $port/tcp
                ufw status | grep -q "$port/udp" || ufw allow $port/udp
                ;;
            firewalld) 
                firewall-cmd --list-ports | grep -q "$port/tcp" || firewall-cmd --permanent --add-port=$port/tcp
                firewall-cmd --list-ports | grep -q "$port/udp" || firewall-cmd --permanent --add-port=$port/udp
                ;;
            iptables) 
                port_rule_exists $port "tcp" || iptables -A INPUT -p tcp --dport $port -j ACCEPT
                port_rule_exists $port "udp" || iptables -A INPUT -p udp --dport $port -j ACCEPT
                # IPv6规则
                if command -v ip6tables &>/dev/null; then
                    ip6tables -L INPUT -n | grep -q "tcp dpt:$port" || ip6tables -A INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null || true
                    ip6tables -L INPUT -n | grep -q "udp dpt:$port" || ip6tables -A INPUT -p udp --dport $port -j ACCEPT 2>/dev/null || true
                fi
                ;;
        esac
        echo -e "${GREEN}已添加/验证端口 ${port} 规则${NC}"
        ports_added=1
    done
    
    # 单独添加常用系统端口（仅TCP）
    echo -e "${YELLOW}添加常用端口...${NC}"
    
    # SSH, HTTP, HTTPS (仅TCP)
    case $firewall_type in
        ufw) 
            ufw status | grep -q "22/tcp" || ufw allow 22/tcp
            ufw status | grep -q "80/tcp" || ufw allow 80/tcp
            ufw status | grep -q "443/tcp" || ufw allow 443/tcp
            ;;
        firewalld) 
            firewall-cmd --list-ports | grep -q "22/tcp" || firewall-cmd --permanent --add-port=22/tcp
            firewall-cmd --list-ports | grep -q "80/tcp" || firewall-cmd --permanent --add-port=80/tcp
            firewall-cmd --list-ports | grep -q "443/tcp" || firewall-cmd --permanent --add-port=443/tcp
            ;;
        iptables) 
            port_rule_exists 22 "tcp" || iptables -A INPUT -p tcp --dport 22 -j ACCEPT
            port_rule_exists 80 "tcp" || iptables -A INPUT -p tcp --dport 80 -j ACCEPT
            port_rule_exists 443 "tcp" || iptables -A INPUT -p tcp --dport 443 -j ACCEPT
            # IPv6规则
            if command -v ip6tables &>/dev/null; then
                ip6tables -L INPUT -n | grep -q "tcp dpt:22" || ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
                ip6tables -L INPUT -n | grep -q "tcp dpt:80" || ip6tables -A INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
                ip6tables -L INPUT -n | grep -q "tcp dpt:443" || ip6tables -A INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || true
            fi
            ;;
    esac
    
    # 检查并清理不再活跃的端口规则（可选功能）
    echo -e "${YELLOW}检查不再活跃的端口规则...${NC}"
    
    if [[ "$firewall_type" == "iptables" ]]; then
        # 获取当前iptables中的所有端口规则
        current_tcp_ports=$(iptables -L INPUT -n | grep "tcp dpt:" | grep -o 'dpt:[0-9]*' | cut -d':' -f2 | sort -u)
        current_udp_ports=$(iptables -L INPUT -n | grep "udp dpt:" | grep -o 'dpt:[0-9]*' | cut -d':' -f2 | sort -u)
        
        # 检查每个TCP端口是否仍然活跃
        for tcp_port in $current_tcp_ports; do
            if ! grep -q "^$tcp_port$" $temp_active_ports && [[ "$tcp_port" != "22" ]] && [[ "$tcp_port" != "80" ]] && [[ "$tcp_port" != "443" ]]; then
                echo -e "${YELLOW}删除不再活跃的TCP端口规则: ${tcp_port}${NC}"
                iptables -D INPUT -p tcp --dport $tcp_port -j ACCEPT 2>/dev/null || true
            fi
        done
        
        # 检查每个UDP端口是否仍然活跃
        for udp_port in $current_udp_ports; do
            if ! grep -q "^$udp_port$" $temp_active_ports && [[ "$udp_port" != "22" ]] && [[ "$udp_port" != "80" ]] && [[ "$udp_port" != "443" ]]; then
                echo -e "${YELLOW}删除不再活跃的UDP端口规则: ${udp_port}${NC}"
                iptables -D INPUT -p udp --dport $udp_port -j ACCEPT 2>/dev/null || true
            fi
        done
        
        # 特殊处理：删除22, 80, 443的UDP规则，因为这些通常只需要TCP
        echo -e "${YELLOW}删除不必要的常用端口UDP规则...${NC}"
        iptables -D INPUT -p udp --dport 22 -j ACCEPT 2>/dev/null || true
        iptables -D INPUT -p udp --dport 80 -j ACCEPT 2>/dev/null || true
        iptables -D INPUT -p udp --dport 443 -j ACCEPT 2>/dev/null || true
        
        # 同样处理IPv6规则
        if command -v ip6tables &>/dev/null; then
            current_tcp6_ports=$(ip6tables -L INPUT -n | grep "tcp dpt:" | grep -o 'dpt:[0-9]*' | cut -d':' -f2 | sort -u)
            current_udp6_ports=$(ip6tables -L INPUT -n | grep "udp dpt:" | grep -o 'dpt:[0-9]*' | cut -d':' -f2 | sort -u)
            
            # 检查每个TCP端口是否仍然活跃
            for tcp_port in $current_tcp6_ports; do
                if ! grep -q "^$tcp_port$" $temp_active_ports && [[ "$tcp_port" != "22" ]] && [[ "$tcp_port" != "80" ]] && [[ "$tcp_port" != "443" ]]; then
                    echo -e "${YELLOW}删除不再活跃的IPv6 TCP端口规则: ${tcp_port}${NC}"
                    ip6tables -D INPUT -p tcp --dport $tcp_port -j ACCEPT 2>/dev/null || true
                fi
            done
            
            # 检查每个UDP端口是否仍然活跃
            for udp_port in $current_udp6_ports; do
                if ! grep -q "^$udp_port$" $temp_active_ports && [[ "$udp_port" != "22" ]] && [[ "$udp_port" != "80" ]] && [[ "$udp_port" != "443" ]]; then
                    echo -e "${YELLOW}删除不再活跃的IPv6 UDP端口规则: ${udp_port}${NC}"
                    ip6tables -D INPUT -p udp --dport $udp_port -j ACCEPT 2>/dev/null || true
                fi
            done
            
            # 特殊处理：删除IPv6的22, 80, 443的UDP规则
            echo -e "${YELLOW}删除不必要的常用端口IPv6 UDP规则...${NC}"
            ip6tables -D INPUT -p udp --dport 22 -j ACCEPT 2>/dev/null || true
            ip6tables -D INPUT -p udp --dport 80 -j ACCEPT 2>/dev/null || true
            ip6tables -D INPUT -p udp --dport 443 -j ACCEPT 2>/dev/null || true
        fi
    fi
    
    # 如果是iptables，保存规则
    if [ "$firewall_type" = "iptables" ]; then
        if command -v iptables-save >/dev/null 2>&1; then
            echo -e "${YELLOW}保存防火墙规则...${NC}"
            if [ -d "/etc/iptables" ]; then
                iptables-save > /etc/iptables/rules.v4
            else
                mkdir -p /etc/iptables
                iptables-save > /etc/iptables/rules.v4
            fi
            
            # 保存IPv6规则
            if command -v ip6tables-save >/dev/null 2>&1 && command -v ip6tables >/dev/null 2>&1; then
                ip6tables-save > /etc/iptables/rules.v6
            fi
            echo -e "${GREEN}防火墙规则已保存${NC}"
        fi
    fi
    
    # 清理临时文件
    rm -f $temp_active_ports
    
    if [ "$ports_added" -eq 0 ]; then
        echo -e "${YELLOW}未检测到任何已安装的应用端口${NC}"
    else
        echo -e "${GREEN}已完成端口配置${NC}"
    fi
}

# 主函数
main() {
    get_ip_addresses
    
    # 默认运行防火墙设置
    firewall_settings
}

# 仅当直接执行时才调用main函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
