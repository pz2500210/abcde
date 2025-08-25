#!/bin/bash

# 设置工作目录为脚本所在目录（如果是直接执行）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cd "$(dirname "$0")" || exit 1
fi

# 颜色定义
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

# 全局IP地址变量
PUBLIC_IPV4=""
PUBLIC_IPV6=""
LOCAL_IPV4=""
LOCAL_IPV6=""

# 获取IP地址的函数
get_ip_addresses() {
    LOCAL_IPV4=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -1)
    LOCAL_IPV6=$(ip -6 addr show | grep -oP '(?<=inet6\s)[\da-f:]+' | grep -v "::1" | grep -v "fe80" | head -1)
    PUBLIC_IPV4=$LOCAL_IPV4
    PUBLIC_IPV6=$LOCAL_IPV6
    TEMP_IPV4=$(curl -s -m 2 https://api.ipify.org 2>/dev/null)
    if [ ! -z "$TEMP_IPV4" ]; then PUBLIC_IPV4=$TEMP_IPV4; fi
    TEMP_IPV6=$(curl -s -m 2 https://api6.ipify.org 2>/dev/null)
    if [ ! -z "$TEMP_IPV6" ]; then PUBLIC_IPV6=$TEMP_IPV6; fi
}

# ==============================================================================
# CORE FUNCTIONS v10.0 (The Only Truth is The Kernel)
# ==============================================================================

# 1. Port Input Validation
validate_port_input() {
    local input=$1
    if [[ "$input" =~ ^[0-9]+$ && "$input" -ge 1 && "$input" -le 65535 ]]; then return 0; fi
    if [[ "$input" =~ ^([0-9]+):([0-9]+)$ ]]; then
        local start=${BASH_REMATCH[1]}; local end=${BASH_REMATCH[2]}
        if [[ "$start" -ge 1 && "$end" -le 65535 && "$start" -le "$end" ]]; then return 0; fi
    fi
    return 1
}

# 2. Kernel Scan: Scan what's ACTUALLY running and detect protocol
detect_real_vpn_ports() {
    echo -e "${CYAN}--> 正在扫描内核，精确检测VPN进程及协议...${NC}" >&2
    local tool_output
    if command -v ss &>/dev/null; then
        tool_output=$(ss -tulnp)
    elif command -v netstat &>/dev/null; then
        tool_output=$(netstat -tulnp 2>/dev/null)
    else
        echo -e "${RED}错误: 未找到 'ss' 或 'netstat' 命令。${NC}" >&2
        return 1
    fi

    local vpn_listeners
    vpn_listeners=$(echo "$tool_output" | grep -E 'x-ui|xray|hysteria.*|hy2|v2ray|sing-box|trojan' | grep -E '\*:[0-9]+|0\.0\.0\.0:[0-9]+|\[::\]:[0-9]+')
    if [ -z "$vpn_listeners" ]; then return 1; fi

    local tcp_ports udp_ports all_ports
    tcp_ports=$(echo "$vpn_listeners" | grep '^tcp' | awk '{print $5}' | sed -E 's/.*:([0-9]+)/\1/' | sort -u)
    udp_ports=$(echo "$vpn_listeners" | grep '^udp' | awk '{print $5}' | sed -E 's/.*:([0-9]+)/\1/' | sort -u)
    all_ports=$(echo -e "$tcp_ports\n$udp_ports" | sort -u)

    for port in $all_ports; do
        is_tcp=false; is_udp=false
        echo "$tcp_ports" | grep -wq "$port" && is_tcp=true
        echo "$udp_ports" | grep -wq "$port" && is_udp=true
        if $is_tcp && $is_udp; then
            echo "$port:both"
        elif $is_tcp; then
            echo "$port:tcp"
        elif $is_udp; then
            echo "$port:udp"
        fi
    done
}

# 3. Config Scan: Detect Hysteria2 ports from config files (for Port Hopping)
detect_hy2_config_ports() {
    echo -e "${CYAN}--> 正在扫描配置文件，查找Hysteria2端口 (特别是跳跃端口)...${NC}" >&2
    local hy2_ports=()
    local file_list
    mapfile -t file_list < <(grep -RIl "hysteria" /root /etc /usr/local 2>/dev/null | grep -E "\.ya?ml|\.json" 2>/dev/null)

    for file in "${file_list[@]}"; do
        while IFS= read -r line; do
            local found_ports=()
            # Strategy 1: Parse URI format (hysteria2://...)
            if [[ "$line" == *"hysteria2://"* ]]; then
                local authority_string=${line#*hysteria2://}
                authority_string=${authority_string%/} # Remove trailing slash
                local host_port_part=${authority_string##*@}
                local port_string=${host_port_part##*:}
                
                IFS=',' read -ra port_array <<< "$port_string"
                for p in "${port_array[@]}"; do
                    found_ports+=("$(echo "$p" | sed 's/-/:/')")
                done
            fi
            
            # Strategy 2: Parse generic keywords (listen, port, ports)
            if [[ "$line" =~ ^\s*(listen|port|ports): ]]; then
                local value
                value=$(echo "$line" | sed -E 's/^\s*(listen|port|ports):\s*//' | tr -d '"'\'' ')
                local port_part=${value##*:} # Handle formats like 0.0.0.0:443
                found_ports+=("$(echo "$port_part" | sed 's/-/:/')")
            fi

            for p in "${found_ports[@]}"; do
                if validate_port_input "$p"; then
                    hy2_ports+=("$p")
                fi
            done
        done < <(grep -v '^\s*#' "$file")
    done
    
    if [ ${#hy2_ports[@]} -gt 0 ]; then
        printf '%s\n' "${hy2_ports[@]}" | sort -u
    fi
}

# 4. Intelligent Port Management (FULLY AUTOMATIC)
intelligent_port_management() {
    local firewall_type=$1
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}VPN服务端口智能管理 (v10.0 全自动版)${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    local ports_from_scan=($(detect_real_vpn_ports))
    local ports_from_config=($(detect_hy2_config_ports))
    
    declare -A port_map
    
    # Process system ports first
    port_map[22]="tcp"
    port_map[80]="tcp"
    
    # Process kernel scan results (highest priority)
    for item in "${ports_from_scan[@]}"; do
        local port=${item%:*}
        local proto=${item#*:}
        port_map[$port]=$proto
    done

    # Process config scan results (add only if not defined by kernel scan)
    for port in "${ports_from_config[@]}"; do
        if [[ -z "${port_map[$port]}" ]]; then
            port_map[$port]="udp"
        fi
    done

    local ports_tcp=() ports_udp=() ports_both=()
    for port in "${!port_map[@]}"; do
        case "${port_map[$port]}" in
            tcp) ports_tcp+=("$port") ;;
            udp) ports_udp+=("$port") ;;
            both) ports_both+=("$port") ;;
        esac
    done

    # Final unique lists
    local unique_ports_both=$(printf '%s\n' "${ports_both[@]}" | sort -n -u)
    local unique_ports_udp=$(printf '%s\n' "${ports_udp[@]}" | sort -n -u)
    local unique_ports_tcp=$(printf '%s\n' "${ports_tcp[@]}" | sort -n -u)

    if [ -z "$unique_ports_both" ] && [ -z "$unique_ports_udp" ] && [[ "${#ports_tcp[@]}" -le 2 ]]; then
        echo -e "${YELLOW}未检测到任何正在运行的VPN服务或有效的Hysteria2配置。${NC}"
    fi

    echo -e "${YELLOW}将根据以下检测结果，自动为您开放端口：${NC}"
    [ -n "$unique_ports_both" ] && echo -e "  - ${CYAN}来自内核扫描 (协议: TCP+UDP):${NC} ${GREEN}${unique_ports_both//$'\n'/, }${NC}"
    [ -n "$unique_ports_udp" ] && echo -e "  - ${CYAN}来自配置/内核 (协议: UDP Only):${NC} ${GREEN}${unique_ports_udp//$'\n'/, }${NC}"
    [ -n "$unique_ports_tcp" ] && echo -e "  - ${CYAN}来自系统/内核 (协议: TCP Only):${NC} ${GREEN}${unique_ports_tcp//$'\n'/, }${NC}"
    
    echo -e "\n${YELLOW}开始执行防火墙操作...${NC}"

    for port in $unique_ports_both; do manage_firewall_port "open" "$port" "both" "$firewall_type" "both"; done
    for port in $unique_ports_udp; do manage_firewall_port "open" "$port" "udp" "$firewall_type" "both"; done
    for port in $unique_ports_tcp; do manage_firewall_port "open" "$port" "tcp" "$firewall_type" "both"; done

    echo -e "\n${GREEN}所有已识别的端口规则已添加/验证。${NC}"
    if [ "$firewall_type" = "iptables" ]; then
        echo -e "${YELLOW}正在保存 iptables 规则...${NC}"
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4
        if command -v ip6tables-save &>/dev/null; then ip6tables-save > /etc/iptables/rules.v6; fi
        echo -e "${GREEN}规则已保存。${NC}"
    fi
}


# 5. Unified Firewall Port Management
manage_firewall_port() {
    local action=$1; local port_input=$2; local protocol=$3; local firewall_type=$4; local ip_version=$5
    if [ -z "$port_input" ]; then return; fi
    echo -e "${CYAN}正在 ${action} 端口 ${port_input} (协议: ${protocol}, IP: ${ip_version})...${NC}"
    case $firewall_type in
        ufw)
            local port_ufw=${port_input//:/-}
            if [[ "$protocol" = "tcp" || "$protocol" = "both" ]]; then
                if [[ "$ip_version" = "ipv4" || "$ip_version" = "both" ]]; then
                    if [ "$action" = "open" ]; then
                        if ufw status | grep -E "^\s*${port_ufw}/tcp\s" | grep -v '(v6)' >/dev/null 2>&1; then
                            echo -e "  ${YELLOW}规则已存在: ${port_ufw}/tcp (ipv4)${NC}"
                        else
                            ufw allow ${port_ufw}/tcp >/dev/null; echo -e "  ${GREEN}成功添加规则: ${port_ufw}/tcp (ipv4)${NC}"
                        fi
                    else
                        ufw delete allow ${port_ufw}/tcp >/dev/null; echo -e "  ${GREEN}已删除规则: ${port_ufw}/tcp (ipv4)${NC}"
                    fi
                fi
                if [[ "$ip_version" = "ipv6" || "$ip_version" = "both" ]]; then
                    if [ "$action" = "open" ]; then
                        if ufw status | grep -E "^\s*${port_ufw}/tcp\s" | grep '(v6)' >/dev/null 2>&1; then
                             echo -e "  ${YELLOW}规则已存在: ${port_ufw}/tcp (ipv6)${NC}"
                        else
                             ufw allow from ::/0 to any port ${port_ufw} proto tcp >/dev/null; echo -e "  ${GREEN}成功添加规则: ${port_ufw}/tcp (ipv6)${NC}"
                        fi
                    else
                         ufw delete allow from ::/0 to any port ${port_ufw} proto tcp >/dev/null; echo -e "  ${GREEN}已删除规则: ${port_ufw}/tcp (ipv6)${NC}"
                    fi
                fi
            fi
            if [[ "$protocol" = "udp" || "$protocol" = "both" ]]; then
                 if [[ "$ip_version" = "ipv4" || "$ip_version" = "both" ]]; then
                    if [ "$action" = "open" ]; then
                        if ufw status | grep -E "^\s*${port_ufw}/udp\s" | grep -v '(v6)' >/dev/null 2>&1; then
                            echo -e "  ${YELLOW}规则已存在: ${port_ufw}/udp (ipv4)${NC}"
                        else
                            ufw allow ${port_ufw}/udp >/dev/null; echo -e "  ${GREEN}成功添加规则: ${port_ufw}/udp (ipv4)${NC}"
                        fi
                    else
                        ufw delete allow ${port_ufw}/udp >/dev/null; echo -e "  ${GREEN}已删除规则: ${port_ufw}/udp (ipv4)${NC}"
                    fi
                 fi
                 if [[ "$ip_version" = "ipv6" || "$ip_version" = "both" ]]; then
                    if [ "$action" = "open" ]; then
                        if ufw status | grep -E "^\s*${port_ufw}/udp\s" | grep '(v6)' >/dev/null 2>&1; then
                             echo -e "  ${YELLOW}规则已存在: ${port_ufw}/udp (ipv6)${NC}"
                        else
                             ufw allow from ::/0 to any port ${port_ufw} proto udp >/dev/null; echo -e "  ${GREEN}成功添加规则: ${port_ufw}/udp (ipv6)${NC}"
                        fi
                    else
                         ufw delete allow from ::/0 to any port ${port_ufw} proto udp >/dev/null; echo -e "  ${GREEN}已删除规则: ${port_ufw}/udp (ipv6)${NC}"
                    fi
                 fi
            fi
            ;;
        firewalld)
            local port_fwcmd=${port_input//:/-}; local changed=0
            if [[ "$protocol" = "tcp" || "$protocol" = "both" ]]; then
                [[ "$ip_version" = "ipv4" || "$ip_version" = "both" ]] && {
                    if [ "$action" = "open" ]; then
                        if firewall-cmd --permanent --query-port=${port_fwcmd}/tcp --family=ipv4 >/dev/null 2>&1; then
                            echo -e "  ${YELLOW}规则已存在: ${port_fwcmd}/tcp (ipv4)${NC}"
                        else
                            firewall-cmd --permanent --add-port=${port_fwcmd}/tcp --family=ipv4 >/dev/null 2>&1 && changed=1
                            echo -e "  ${GREEN}成功添加规则: ${port_fwcmd}/tcp (ipv4)${NC}"
                        fi
                    else
                        firewall-cmd --permanent --remove-port=${port_fwcmd}/tcp --family=ipv4 >/dev/null 2>&1 && changed=1
                        echo -e "  ${GREEN}已删除规则: ${port_fwcmd}/tcp (ipv4)${NC}"
                    fi
                }
                [[ "$ip_version" = "ipv6" || "$ip_version" = "both" ]] && {
                     if [ "$action" = "open" ]; then
                        if firewall-cmd --permanent --query-port=${port_fwcmd}/tcp --family=ipv6 >/dev/null 2>&1; then
                            echo -e "  ${YELLOW}规则已存在: ${port_fwcmd}/tcp (ipv6)${NC}"
                        else
                            firewall-cmd --permanent --add-port=${port_fwcmd}/tcp --family=ipv6 >/dev/null 2>&1 && changed=1
                            echo -e "  ${GREEN}成功添加规则: ${port_fwcmd}/tcp (ipv6)${NC}"
                        fi
                    else
                        firewall-cmd --permanent --remove-port=${port_fwcmd}/tcp --family=ipv6 >/dev/null 2>&1 && changed=1
                        echo -e "  ${GREEN}已删除规则: ${port_fwcmd}/tcp (ipv6)${NC}"
                    fi
                }
            fi
            if [[ "$protocol" = "udp" || "$protocol" = "both" ]]; then
                 [[ "$ip_version" = "ipv4" || "$ip_version" = "both" ]] && {
                    if [ "$action" = "open" ]; then
                        if firewall-cmd --permanent --query-port=${port_fwcmd}/udp --family=ipv4 >/dev/null 2>&1; then
                            echo -e "  ${YELLOW}规则已存在: ${port_fwcmd}/udp (ipv4)${NC}"
                        else
                            firewall-cmd --permanent --add-port=${port_fwcmd}/udp --family=ipv4 >/dev/null 2>&1 && changed=1
                            echo -e "  ${GREEN}成功添加规则: ${port_fwcmd}/udp (ipv4)${NC}"
                        fi
                    else
                        firewall-cmd --permanent --remove-port=${port_fwcmd}/udp --family=ipv4 >/dev/null 2>&1 && changed=1
                        echo -e "  ${GREEN}已删除规则: ${port_fwcmd}/udp (ipv4)${NC}"
                    fi
                 }
                 [[ "$ip_version" = "ipv6" || "$ip_version" = "both" ]] && {
                    if [ "$action" = "open" ]; then
                        if firewall-cmd --permanent --query-port=${port_fwcmd}/udp --family=ipv6 >/dev/null 2>&1; then
                            echo -e "  ${YELLOW}规则已存在: ${port_fwcmd}/udp (ipv6)${NC}"
                        else
                            firewall-cmd --permanent --add-port=${port_fwcmd}/udp --family=ipv6 >/dev/null 2>&1 && changed=1
                            echo -e "  ${GREEN}成功添加规则: ${port_fwcmd}/udp (ipv6)${NC}"
                        fi
                    else
                        firewall-cmd --permanent --remove-port=${port_fwcmd}/udp --family=ipv6 >/dev/null 2>&1 && changed=1
                        echo -e "  ${GREEN}已删除规则: ${port_fwcmd}/udp (ipv6)${NC}"
                    fi
                 }
            fi
            if [ $changed -eq 1 ]; then firewall-cmd --reload >/dev/null; fi
            ;;
        iptables)
            local port_iptables=${port_input//-/:}; local rules_to_process=()
            if [[ "$protocol" = "tcp" || "$protocol" = "both" ]]; then
                [[ "$ip_version" = "ipv4" || "$ip_version" = "both" ]] && rules_to_process+=("iptables -p tcp --dport ${port_iptables} -j ACCEPT")
                [[ "$ip_version" = "ipv6" || "$ip_version" = "both" ]] && command -v ip6tables &>/dev/null && rules_to_process+=("ip6tables -p tcp --dport ${port_iptables} -j ACCEPT")
            fi
            if [[ "$protocol" = "udp" || "$protocol" = "both" ]]; then
                [[ "$ip_version" = "ipv4" || "$ip_version" = "both" ]] && rules_to_process+=("iptables -p udp --dport ${port_iptables} -j ACCEPT")
                [[ "$ip_version" = "ipv6" || "$ip_version" = "both" ]] && command -v ip6tables &>/dev/null && rules_to_process+=("ip6tables -p udp --dport ${port_iptables} -j ACCEPT")
            fi
            for rule_string in "${rules_to_process[@]}"; do
                read -r -a rule_parts <<< "$rule_string"; local fw_tool="${rule_parts[0]}"; local fw_args=("${rule_parts[@]:1}")
                if [ "$action" = "open" ]; then
                    if ! "$fw_tool" -C INPUT "${fw_args[@]}" >/dev/null 2>&1; then
                        "$fw_tool" -I INPUT 1 "${fw_args[@]}" >/dev/null 2>&1; echo -e "  ${GREEN}成功添加规则: $rule_string${NC}"
                    else
                        echo -e "  ${YELLOW}规则已存在: $rule_string${NC}"
                    fi
                else
                    while "$fw_tool" -D INPUT "${fw_args[@]}" >/dev/null 2>&1; do :; done; echo -e "  ${GREEN}已删除规则: $rule_string${NC}"
                fi
            done
            ;;
    esac
}

# 6. Handlers for manual port management
port_management_handler() {
    local action=$1; local ip_version=$2; local firewall_type=$3
    local prompt_text="请输入要 ${action} 的 ${ip_version} 端口 (可以是单个端口如 8080, 或范围如 8000:8100)"
    if [ "$action" = "close" ]; then
        prompt_text+=", 或输入 'ALL' 关闭除22外的所有端口"
    fi
    echo -e "${YELLOW}${prompt_text}:${NC}"
    read -p "端口: " port_input

    if [[ "$action" = "close" && ( "$port_input" == "ALL" || "$port_input" == "all" ) ]]; then
        echo -e "${YELLOW}正在关闭所有 ${ip_version} 端口 (保留 SSH 端口 22)...${NC}"
        case $firewall_type in
            ufw)
                local rules_to_delete
                if [[ "$ip_version" == "ipv4" ]]; then
                    rules_to_delete=$(ufw status numbered | grep -v '(v6)' | grep -vE '\<22/tcp\>|\<22/udp\>' | awk '{print $1}' | tr -d '[]' | sort -rn)
                else # ipv6
                    rules_to_delete=$(ufw status numbered | grep '(v6)' | grep -vE '\<22/tcp\>|\<22/udp\>' | awk '{print $1}' | tr -d '[]' | sort -rn)
                fi

                if [ -n "$rules_to_delete" ]; then
                    echo "$rules_to_delete" | while read -r num; do yes | ufw delete "$num" >/dev/null; done
                    echo -e "${GREEN}UFW ${ip_version} 规则已清理 (保留 SSH)。${NC}"
                else
                    echo -e "${YELLOW}没有需要清理的非 SSH ${ip_version} 规则。${NC}"
                fi
                ;;
            firewalld)
                local zone
                zone=$(firewall-cmd --get-default-zone)
                local changed=0
                for port in $(firewall-cmd --permanent --zone=$zone --list-ports --family=$ip_version); do
                    if [[ "$port" != "22/tcp" && "$port" != "22/udp" ]]; then
                        firewall-cmd --permanent --zone=$zone --remove-port="$port" --family=$ip_version >/dev/null 2>&1 && changed=1
                    fi
                done
                if [ $changed -eq 1 ]; then firewall-cmd --reload >/dev/null; fi
                echo -e "${GREEN}Firewalld ${ip_version} 端口规则已清理。${NC}"
                ;;
            iptables)
                if [[ "$ip_version" == "ipv4" ]]; then
                    iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -F INPUT
                    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                    iptables -A INPUT -i lo -j ACCEPT; iptables -A INPUT -p tcp --dport 22 -j ACCEPT
                    echo -e "${GREEN}iptables (IPv4) 规则已重置，仅允许端口 22 及相关连接。${NC}"
                else # ipv6
                    if command -v ip6tables &>/dev/null; then
                        ip6tables -P INPUT DROP; ip6tables -P FORWARD DROP; ip6tables -F INPUT
                        ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                        ip6tables -A INPUT -i lo -j ACCEPT; ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT
                        echo -e "${GREEN}ip6tables (IPv6) 规则已重置，仅允许端口 22 及相关连接。${NC}"
                    else
                        echo -e "${YELLOW}未找到 ip6tables 命令。${NC}"
                    fi
                fi
                ;;
        esac
        return
    fi

    if ! validate_port_input "$port_input"; then echo -e "${RED}无效的端口或端口范围: $port_input${NC}"; return; fi
    echo -e "${YELLOW}请选择协议:${NC}"; echo -e "  1) TCP\n  2) UDP\n  3) TCP+UDP (两者)"
    read -p "选择 [1-3] (默认: 3): " protocol_choice
    protocol_choice=${protocol_choice:-3}
    local protocol="both"; case $protocol_choice in 1) protocol="tcp" ;; 2) protocol="udp" ;; esac
    manage_firewall_port "$action" "$port_input" "$protocol" "$firewall_type" "$ip_version"
}

# ==============================================================================
# MAIN SCRIPT LOGIC
# ==============================================================================

firewall_settings() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}防火墙设置 (v10.0 - 最终版)${NC}"
    echo -e "${BLUE}=================================================${NC}"
                
    local firewall_type=""
    if command -v ufw &>/dev/null; then firewall_type="ufw"
    elif command -v firewall-cmd &>/dev/null; then firewall_type="firewalld"
    elif command -v iptables &>/dev/null; then firewall_type="iptables"
    else
        echo -e "${RED}未检测到支持的防火墙 (ufw, firewalld, iptables).${NC}"; read -p "按回车键退出..."; return
    fi
    echo -e "${YELLOW}检测到防火墙类型: ${WHITE}$firewall_type${NC}"
    if [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)" = "1" ]; then
        echo -e "${YELLOW}IPv6状态: ${RED}已禁用${NC}"
    else
        echo -e "${YELLOW}IPv6状态: ${GREEN}已启用${NC}"
    fi
    
    echo
    echo -e "${YELLOW}请选择操作:${NC}"
    echo -e "  1) 查看防火墙状态\n  2) 开启防火墙 (安全策略)\n  3) 关闭防火墙 (清空规则)\n  ---"
    echo -e "  4) ${GREEN}手动开放端口 (IPv4, 支持范围)${NC}\n  5) ${RED}手动关闭端口 (IPv4, 支持范围)${NC}\n  ---"
    echo -e "  6) ${CYAN}自动识别并开放所有VPN端口${NC}\n  ---"
    echo -e "  7) ${GREEN}手动开放端口 (IPv6, 支持范围)${NC}\n  8) ${RED}手动关闭端口 (IPv6, 支持范围)${NC}\n  ---"
    echo -e "  99) IPv6 开启/关闭\n  0) 退出"
    echo
    read -p "请选择: " FW_OPTION
                
    case $FW_OPTION in
        1)
            echo -e "${YELLOW}防火墙状态:${NC}";
            case $firewall_type in
                ufw) ufw status verbose ;;
                firewalld) firewall-cmd --state && firewall-cmd --list-all ;;
                iptables) 
                    echo "IPv4 Rules:"; iptables -L INPUT -v -n --line-numbers
                    if command -v ip6tables &>/dev/null; then echo -e "\nIPv6 Rules:"; ip6tables -L INPUT -v -n --line-numbers; fi
                    ;;
            esac
            ;;
        2)
            echo -e "${YELLOW}开启防火墙...${NC}"
            case $firewall_type in
                ufw) ufw allow 22/tcp >/dev/null; ufw allow 80/tcp >/dev/null; ufw enable ;;
                firewalld) 
                    systemctl start firewalld && systemctl enable firewalld
                    firewall-cmd --permanent --add-port=22/tcp >/dev/null 2>&1
                    firewall-cmd --permanent --add-port=80/tcp >/dev/null 2>&1
                    firewall-cmd --reload >/dev/null
                    ;;
                iptables) 
                    iptables -P INPUT DROP; iptables -P FORWARD DROP; iptables -F INPUT
                    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                    iptables -A INPUT -i lo -j ACCEPT; iptables -A INPUT -p tcp --dport 22 -j ACCEPT; iptables -A INPUT -p tcp --dport 80 -j ACCEPT
                    if command -v ip6tables &>/dev/null; then
                        ip6tables -P INPUT DROP; ip6tables -P FORWARD DROP; ip6tables -P OUTPUT ACCEPT; ip6tables -F INPUT
                        ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                        ip6tables -A INPUT -i lo -j ACCEPT; ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT; ip6tables -A INPUT -p tcp --dport 80 -j ACCEPT
                    fi
                    echo -e "${GREEN}iptables 默认策略已设为 DROP，基础规则已应用。${NC}"
                    ;;
            esac
            intelligent_port_management "$firewall_type"
            ;;
        3)
            echo -e "${YELLOW}关闭防火墙...${NC}"
            case $firewall_type in
                ufw) ufw disable ;;
                firewalld) systemctl stop firewalld && systemctl disable firewalld ;;
                iptables) 
                    iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT; iptables -F; iptables -X
                    if command -v ip6tables &>/dev/null; then
                        ip6tables -P INPUT ACCEPT; ip6tables -P FORWARD ACCEPT; ip6tables -P OUTPUT ACCEPT; ip6tables -F; ip6tables -X
                    fi
                    echo -e "${GREEN}所有 iptables 规则已清空，策略已设为 ACCEPT。${NC}"
                    ;;
            esac
            ;;
        4) port_management_handler "open" "ipv4" "$firewall_type" ;;
        5) port_management_handler "close" "ipv4" "$firewall_type" ;;
        6) intelligent_port_management "$firewall_type" ;;
        7) port_management_handler "open" "ipv6" "$firewall_type" ;;
        8) port_management_handler "close" "ipv6" "$firewall_type" ;;
        99)
            echo -e "${YELLOW}IPv6 开启/关闭...${NC}"
            echo "当前状态: $(if [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)" = "1" ]; then echo "已禁用"; else echo "已启用"; fi)"
            echo "1) 启用IPv6"; echo "2) 禁用IPv6"
            read -p "请选择: " ipv6_choice
            case $ipv6_choice in
                1)
                    sed -i '/disable_ipv6/d' /etc/sysctl.conf
                    echo "net.ipv6.conf.all.disable_ipv6 = 0" >> /etc/sysctl.conf
                    echo "net.ipv6.conf.default.disable_ipv6 = 0" >> /etc/sysctl.conf
                    sysctl -p >/dev/null 2>&1
                    echo -e "${GREEN}IPv6 已启用, 重启后生效。${NC}"
                    ;;
                2)
                    sed -i '/disable_ipv6/d' /etc/sysctl.conf
                    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
                    echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
                    sysctl -p >/dev/null 2>&1
                    echo -e "${GREEN}IPv6 已禁用, 重启后生效。${NC}"
                    ;;
                *) echo -e "${RED}无效选择。${NC}" ;;
            esac
            ;;
        0) echo -e "${GREEN}退出脚本。${NC}"; exit 0 ;;
        *) echo -e "${RED}无效选项，请重试${NC}"; sleep 2 ;;
    esac
                
    read -p "按回车键返回菜单..." temp
}

# Main function
main() {
    if [ "$(id -u)" -ne 0 ]; then echo -e "${RED}此脚本需要 root 权限运行。${NC}"; exit 1; fi
    get_ip_addresses
    while true; do
        firewall_settings
    done
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi