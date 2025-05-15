#!/bin/bash

# 设置工作目录为脚本所在目录（如果是直接执行）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cd "$(dirname "$0")" || exit 1
    SCRIPT_DIR="$(pwd)"
fi



# Hysteria-2管理
hysteria2_management() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}Hysteria-2管理:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 检查是否已安装
    if [ -f "/usr/local/bin/hysteria" ]; then
        echo -e "${YELLOW}检测到Hysteria-2已安装${NC}"
        echo -e "${YELLOW}请选择操作:${NC}"
        echo -e "  1) 重新安装"
        echo -e "  2) 修改配置"
        echo -e "  3) 查看配置"
        echo -e "  4) 卸载"
        echo -e "  0) 返回上级菜单"
        
        read -p "选择 [0-4]: " H2_OPTION
        
        case $H2_OPTION in
            1) install_hysteria2 ;;
            2) configure_hysteria2 ;;
            3) view_hysteria2_config ;;
            4) uninstall_hysteria2 ;;
            0) return ;;
            *) 
                echo -e "${RED}无效选项，请重试${NC}"
                sleep 2
                hysteria2_management
                ;;
        esac
    else
        echo -e "${YELLOW}未检测到Hysteria-2，开始安装...${NC}"
        install_hysteria2
    fi
}

# 安装Hysteria-2
install_hysteria2() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}安装Hysteria-2:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 创建日志目录
    mkdir -p /root/.sb_logs
    local log_file="/root/.sb_logs/hysteria2_install.log"
    
    # 记录开始安装
    echo "# Hysteria-2安装日志" > $log_file
    echo "# 安装时间: $(date "+%Y-%m-%d %H:%M:%S")" >> $log_file
    
    # 添加前置环境安装
    echo -e "${YELLOW}正在安装必要的环境...${NC}"
    apt-get update
    apt-get install -y ca-certificates net-tools curl
    
    # 安装Hysteria-2
    echo -e "${YELLOW}开始安装Hysteria-2...${NC}"
    wget -N --no-check-certificate https://raw.githubusercontent.com/Misaka-blog/hysteria-install/main/hy2/hysteria.sh && bash hysteria.sh
    
    # 检查安装结果
    if [ -f "/usr/local/bin/hysteria" ]; then
        echo -e "${GREEN}Hysteria-2安装成功!${NC}"
        
        # 修复权限问题
        if [ -f "/etc/systemd/system/hysteria-server.service" ]; then
            echo -e "${YELLOW}修复Hysteria 2服务权限...${NC}"
            sed -i 's/User=hysteria/#User=hysteria/' /etc/systemd/system/hysteria-server.service
            sed -i 's/Group=hysteria/#Group=hysteria/' /etc/systemd/system/hysteria-server.service
            systemctl daemon-reload
            systemctl restart hysteria-server
        fi
        
        # 更新主安装记录
        update_main_install_log "Hysteria-2"
    else
        echo -e "${RED}Hysteria-2安装失败，请检查网络或稍后再试${NC}"
    fi
    
    read -p "按回车键继续..." temp
    hysteria2_management
}

# 配置Hysteria-2
configure_hysteria2() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}配置Hysteria-2:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 检查是否安装
    if [ ! -f "/usr/local/bin/hysteria" ]; then
        echo -e "${RED}Hysteria-2未安装，请先安装${NC}"
        read -p "按回车键继续..." temp
        hysteria2_management
        return
    fi
    
    # 运行官方脚本进行配置
    wget -N --no-check-certificate https://raw.githubusercontent.com/Misaka-blog/hysteria-install/main/hy2/hysteria.sh && bash hysteria.sh
    
    read -p "按回车键继续..." temp
    hysteria2_management
}

# 查看Hysteria-2配置
view_hysteria2_config() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}Hysteria-2配置信息:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 检查是否安装
    if [ ! -f "/usr/local/bin/hysteria" ]; then
        echo -e "${RED}Hysteria-2未安装，请先安装${NC}"
        read -p "按回车键继续..." temp
        hysteria2_management
        return
    fi
    
    # 检查服务状态
    echo -e "${YELLOW}服务状态:${NC}"
    systemctl status hysteria-server --no-pager 2>/dev/null || echo "无法获取服务状态，可能是在容器环境中运行"
    
    # 变量初始化
    local server_addr=""
    local server_port=""
    local auth=""
    local sni="www.bing.com"  # 默认使用www.bing.com作为SNI
    local insecure="1"        # 默认跳过证书验证
    
    # 显示配置文件并提取关键信息
    echo -e "\n${YELLOW}配置文件内容:${NC}"
    if [ -f "/etc/hysteria/config.json" ]; then
        cat /etc/hysteria/config.json
        
        # 从JSON配置提取信息
        if command -v jq &> /dev/null; then
            # 使用jq解析
            server_addr=$(jq -r '.listen' /etc/hysteria/config.json 2>/dev/null | sed 's/:[0-9]*$//')
            server_port=$(jq -r '.listen' /etc/hysteria/config.json 2>/dev/null | grep -o ':[0-9]*' | sed 's/://')
            
            # 获取认证信息
            if jq -e '.auth.type == "password"' /etc/hysteria/config.json &>/dev/null; then
                auth=$(jq -r '.auth.password' /etc/hysteria/config.json 2>/dev/null)
            fi
        else
            # 使用grep和sed解析
            server_addr=$(grep -o '"listen": "[^"]*"' /etc/hysteria/config.json | cut -d'"' -f4 | sed 's/:[0-9]*$//')
            server_port=$(grep -o '"listen": "[^"]*"' /etc/hysteria/config.json | cut -d'"' -f4 | grep -o ':[0-9]*' | sed 's/://')
            auth=$(grep -o '"password": "[^"]*"' /etc/hysteria/config.json | cut -d'"' -f4)
        fi
        
    elif [ -f "/etc/hysteria/config.yaml" ]; then
        cat /etc/hysteria/config.yaml
        
        # 从YAML配置提取信息
        server_addr=$(grep -o 'listen: .*' /etc/hysteria/config.yaml | awk '{print $2}' | sed 's/:[0-9]*$//')
        server_port=$(grep -o 'listen: .*' /etc/hysteria/config.yaml | awk '{print $2}' | grep -o ':[0-9]*' | sed 's/://')
        
        # 获取认证信息
        if grep -q 'type: password' /etc/hysteria/config.yaml; then
            auth=$(grep -A1 'type: password' /etc/hysteria/config.yaml | grep 'password:' | awk '{print $2}')
        fi
    else
        echo -e "${RED}未找到配置文件${NC}"
    fi
    
    # 如果没有获取到服务器地址，使用公网IP
    if [ -z "$server_addr" ] || [ "$server_addr" = "0.0.0.0" ] || [ "$server_addr" = "::" ]; then
        server_addr="${PUBLIC_IPV4}"
    fi
    
    # 生成分享链接
    if [ ! -z "$server_addr" ] && [ ! -z "$server_port" ] && [ ! -z "$auth" ]; then
        echo -e "\n${GREEN}生成的Hysteria-2分享链接:${NC}"
        
        #链接格式生成
        local share_link="hysteria2://${auth}@${server_addr}:${server_port}/?insecure=${insecure}&sni=${sni}#Hysteria2"
        
        echo -e "${YELLOW}${share_link}${NC}"
        
        # 生成二维码
        if command -v qrencode &> /dev/null; then
            echo -e "\n${GREEN}分享二维码:${NC}"
            qrencode -t ANSIUTF8 "$share_link"
        fi
        
        # 提供复制提示
        echo -e "\n${GREEN}复制上面的链接到您的客户端即可使用${NC}"
    else
        echo -e "\n${RED}无法生成分享链接，缺少必要信息${NC}"
        echo -e "${YELLOW}需要的信息:${NC}"
        echo -e "  服务器地址: $server_addr"
        echo -e "  服务器端口: $server_port"
        echo -e "  认证密码: $auth"
    fi
    
    read -p "按回车键继续..." temp
    hysteria2_management
}

# 卸载Hysteria-2
uninstall_hysteria2() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}卸载Hysteria-2:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 检查是否安装
    if [ ! -f "/usr/local/bin/hysteria" ]; then
        echo -e "${RED}Hysteria-2未安装，无需卸载${NC}"
        read -p "按回车键继续..." temp
        hysteria2_management
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
    hysteria2_management
}

# 3X-UI管理
xui_management() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}3X-UI管理:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 检查是否已安装
    if [ -f "/usr/local/x-ui/x-ui" ] || [ -f "/usr/bin/x-ui" ]; then
        echo -e "${YELLOW}检测到3X-UI已安装${NC}"
        echo -e "${YELLOW}请选择操作:${NC}"
        echo -e "  1) 重新安装"
        echo -e "  2) 修改配置"
        echo -e "  3) 查看配置"
        echo -e "  4) 卸载"
        echo -e "  0) 返回上级菜单"
        
        read -p "选择 [0-4]: " choice
        case $choice in
            1)
                install_3xui
                ;;
            2)
                configure_3xui
                ;;
            3)
                view_3xui_config
                ;;
            4)
                uninstall_3xui
                ;;
            0)
                # 直接返回，不再调用xui_management
                return
                ;;
            *)
                echo -e "${RED}无效的选择${NC}"
                read -p "按回车键继续..." temp
                xui_management
                ;;
        esac
    else
        echo -e "${YELLOW}未检测到3X-UI，开始安装...${NC}"
        install_3xui
    fi
}

# 安装3X-UI
install_3xui() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}安装3X-UI:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 检查并安装wget
    if ! command -v wget &> /dev/null; then
        echo -e "${YELLOW}检测到wget未安装，正在安装...${NC}"
        if [ -f /etc/debian_version ]; then
            apt update && apt install -y wget curl
        elif [ -f /etc/redhat-release ]; then
            yum install -y wget curl
        else
            echo -e "${RED}无法安装wget，请手动安装后重试${NC}"
            read -p "按回车键继续..." temp
            xui_management
            return
        fi
    fi
    
    # 创建日志目录
    mkdir -p /root/.sb_logs
    local log_file="/root/.sb_logs/3xui_install.log"
    
    # 记录开始安装
    echo "# 3X-UI安装日志" > $log_file
    echo "# 安装时间: $(date "+%Y-%m-%d %H:%M:%S")" >> $log_file
    
    # 安装3X-UI
    echo -e "${YELLOW}开始安装3X-UI...${NC}"
    # 创建临时文件存储安装输出
    local temp_output="/tmp/3xui_install_output.txt"
    wget -N --no-check-certificate https://raw.githubusercontent.com/MHSanaei/3x-ui/refs/tags/v2.5.8/install.sh -O /tmp/3xui_install.sh
    bash /tmp/3xui_install.sh | tee $temp_output
    
    # 等待几秒确保服务启动
    sleep 3
    
    # 从安装输出提取Access URL
    local access_url=$(grep -o "Access URL: http://[^ ]*" $temp_output | cut -d' ' -f3)
    
    # 使用x-ui settings命令获取准确的配置信息
    echo -e "${YELLOW}获取面板配置信息...${NC}"
    x_ui_settings=$(x-ui settings 2>/dev/null)
    
    # 从设置中提取信息
    local panel_user=$(echo "$x_ui_settings" | grep -oP "username: \K.*" | head -1)
    local panel_pass=$(echo "$x_ui_settings" | grep -oP "password: \K.*" | head -1)
    local panel_port=$(echo "$x_ui_settings" | grep -oP "port: \K[0-9]+" | head -1)
    local panel_path=$(echo "$x_ui_settings" | grep -oP "base_path: \K.*" | head -1)
    
    # 更新主安装记录
    if [ ! -z "$panel_port" ]; then
        update_main_install_log "3X-UI:${panel_port}"
    else 
        update_main_install_log "3X-UI"
    fi
    
    # 显示面板信息
    echo -e "${GREEN}3X-UI安装成功!${NC}"
    echo -e "${YELLOW}面板信息:${NC}"
    
    # 优先使用从安装输出中提取的完整Access URL
    if [ ! -z "$access_url" ]; then
        echo -e "  面板地址: $access_url"
    elif [ ! -z "$panel_port" ]; then
        if [ ! -z "$panel_path" ] && [ "$panel_path" != "/" ]; then
            echo -e "  面板地址: http://${PUBLIC_IPV4}:${panel_port}${panel_path}"
        else
            echo -e "  面板地址: http://${PUBLIC_IPV4}:${panel_port}"
        fi
    else
        echo -e "  面板地址: http://${PUBLIC_IPV4}:2053 (默认端口)"
    fi
    
    if [ ! -z "$panel_user" ] && [ ! -z "$panel_pass" ]; then
        echo -e "  用户名: $panel_user"
        echo -e "  密码: $panel_pass"
    else
        # 尝试从安装输出中提取用户名密码
        local username=$(grep -o "Username: [^ ]*" $temp_output | cut -d' ' -f2)
        local password=$(grep -o "Password: [^ ]*" $temp_output | cut -d' ' -f2)
        if [ ! -z "$username" ] && [ ! -z "$password" ]; then
            echo -e "  用户名: $username"
            echo -e "  密码: $password"
        else
            echo -e "  默认用户名: admin"
            echo -e "  默认密码: admin"
        fi
    fi
    
    echo -e "  请登录后立即修改默认密码!"
    
    # 记录到日志文件
    echo "PANEL_PORT: $panel_port" >> $log_file
    echo "PANEL_PATH: $panel_path" >> $log_file
    echo "PANEL_USER: $panel_user" >> $log_file
    echo "PANEL_PASS: $panel_pass" >> $log_file
    echo "ACCESS_URL: $access_url" >> $log_file
    
    # 清理临时文件
    rm -f /tmp/3xui_install.sh
    rm -f $temp_output
    
    read -p "按回车键继续..." temp
    xui_management
}

# 配置3X-UI
configure_3xui() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}配置3X-UI:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 检查是否安装
    if [ ! -f "/usr/local/x-ui/x-ui" ] && [ ! -f "/usr/bin/x-ui" ]; then
        echo -e "${RED}3X-UI未安装，请先安装${NC}"
        read -p "按回车键继续..." temp
        xui_management
        return
    fi
    
    # 运行3X-UI自带的配置命令
    if [ -f "/usr/bin/x-ui" ]; then
        x-ui
    else
        echo -e "${RED}无法找到x-ui命令，请尝试重新安装${NC}"
    fi
    
    read -p "按回车键继续..." temp
    xui_management
}

# 查看3X-UI配置
view_3xui_config() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}3X-UI配置信息:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 检查是否安装
    if [ ! -f "/usr/local/x-ui/x-ui" ] && [ ! -f "/usr/bin/x-ui" ]; then
        echo -e "${RED}3X-UI未安装，请先安装${NC}"
        read -p "按回车键继续..." temp
        xui_management
        return
    fi
    
    # 检查服务状态
    echo -e "${YELLOW}服务状态:${NC}"
    systemctl status x-ui --no-pager 2>/dev/null || echo "无法获取服务状态，可能是在容器环境中运行"
    
    # 使用x-ui settings获取面板信息
    echo -e "\n${YELLOW}面板信息:${NC}"
    if [ -f "/usr/bin/x-ui" ]; then
        # 直接运行命令并显示结果
        echo -e "  $(x-ui settings 2>/dev/null | sed 's/^/  /')"
    else
        echo -e "${RED}无法找到x-ui命令，请尝试重新安装${NC}"
    fi
    
    read -p "按回车键继续..." temp
    xui_management
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
        xui_management
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
    xui_management
}

# Sing-box-yg管理
singbox_management() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}Sing-box-yg管理:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 使用更全面的检测方法
    if [ -f "/usr/local/bin/sing-box" ] || [ -f "/usr/bin/sing-box" ] || 
       [ -f "/usr/local/etc/sing-box/config.json" ] || command -v sb &>/dev/null || 
       systemctl status sing-box &>/dev/null || 
       grep -q "Sing-box-yg" /root/.sb_logs/main_install.log 2>/dev/null; then
        
        echo -e "${YELLOW}检测到Sing-box-yg已安装${NC}"
        echo -e "${YELLOW}请选择操作:${NC}"
        echo -e "  1) 重新安装"
        echo -e "  2) 修改配置"
        echo -e "  3) 查看配置"
        echo -e "  4) 卸载"
        echo -e "  0) 返回主菜单"
        
        read -p "选择 [0-4]: " SB_OPTION
        
        case $SB_OPTION in
            1) install_singbox_yg ;;
            2) configure_singbox_yg ;;
            3) view_singbox_yg_config ;;
            4) uninstall_singbox_yg ;;
            0) return ;;
            *) 
                echo -e "${RED}无效选项，请重试${NC}"
                sleep 2
                singbox_management
                ;;
        esac
    else
        echo -e "${YELLOW}未检测到Sing-box-yg${NC}"
        echo -e "${YELLOW}请选择操作:${NC}"
        echo -e "  1) 安装 Sing-box-yg"
        echo -e "  0) 返回主菜单"
        
        read -p "选择 [0-1]: " SB_OPTION
        
        case $SB_OPTION in
            1) install_singbox_yg ;;
            0) return ;;
            *) 
                echo -e "${RED}无效选项，请重试${NC}"
                sleep 2
                singbox_management
                ;;
        esac
    fi
}

# 安装Sing-box-yg
install_singbox_yg() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}安装Sing-box-yg:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 创建日志目录
    mkdir -p /root/.sb_logs
    local log_file="/root/.sb_logs/singbox_yg_install.log"
    
    # 记录开始安装
    echo "# Sing-box-yg安装日志" > $log_file
    echo "# 安装时间: $(date "+%Y-%m-%d %H:%M:%S")" >> $log_file
    
    # 安装Sing-box-yg
    echo -e "${YELLOW}开始安装Sing-box-yg...${NC}"
    
    # 直接执行安装脚本
    bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
    
    # 检查安装结果
    if [ -f "/usr/local/bin/sing-box" ]; then
        echo -e "${GREEN}Sing-box-yg安装成功!${NC}"
        # 更新主安装记录
        update_main_install_log "Sing-box-yg"
    else
        echo -e "${YELLOW}返回Sing-box-yg管理菜单...${NC}"
    fi
    
    sleep 1
    singbox_management
}

# 配置Sing-box-yg
configure_singbox_yg() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}配置Sing-box-yg:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 使用更全面的检测方法
    if [ -f "/usr/local/bin/sing-box" ] || [ -f "/usr/bin/sing-box" ] || 
       [ -f "/usr/local/etc/sing-box/config.json" ] || command -v sb &>/dev/null || 
       systemctl status sing-box &>/dev/null || 
       grep -q "Sing-box-yg" /root/.sb_logs/main_install.log 2>/dev/null; then
        
        # 直接执行sb命令
        if command -v sb &>/dev/null; then
            echo -e "${YELLOW}正在打开Sing-box-yg配置面板...${NC}"
            sb
        else
            # 如果没有sb命令，尝试通过官方脚本
            echo -e "${YELLOW}未找到sb命令，尝试通过官方脚本打开配置...${NC}"
            bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
        fi
    else
        echo -e "${RED}Sing-box-yg未安装，请先安装${NC}"
        echo -e "${YELLOW}检查以下可能的安装路径：${NC}"
        echo -e "  - /usr/local/bin/sing-box: $([ -f "/usr/local/bin/sing-box" ] && echo "存在" || echo "不存在")"
        echo -e "  - /usr/bin/sing-box: $([ -f "/usr/bin/sing-box" ] && echo "存在" || echo "不存在")"
        echo -e "  - 配置文件: $([ -f "/usr/local/etc/sing-box/config.json" ] && echo "存在" || echo "不存在")"
        echo -e "  - sb命令: $(command -v sb &>/dev/null && echo "存在" || echo "不存在")"
        echo -e "  - systemd服务: $(systemctl status sing-box &>/dev/null && echo "存在" || echo "不存在")"
        
        echo -e "${YELLOW}是否强制尝试打开配置面板？(y/n)${NC}"
        read -p "选择 [y/n]: " FORCE_OPEN
        
        if [[ $FORCE_OPEN =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}尝试通过官方脚本打开配置...${NC}"
            bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
        fi
    fi
    
    echo -e "${YELLOW}返回Sing-box-yg管理菜单...${NC}"
    sleep 1
    singbox_management
}

# 查看Sing-box-yg配置
view_singbox_yg_config() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}Sing-box-yg配置信息:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 使用更全面的检测方法
    if [ -f "/usr/local/bin/sing-box" ] || [ -f "/usr/bin/sing-box" ] || 
       [ -f "/usr/local/etc/sing-box/config.json" ] || command -v sb &>/dev/null || 
       systemctl status sing-box &>/dev/null || 
       grep -q "Sing-box-yg" /root/.sb_logs/main_install.log 2>/dev/null; then
        
        echo -e "${YELLOW}即将打开Sing-box-yg面板并选择'9. 刷新并查看节点'选项${NC}"
        echo -e "${GREEN}请手动选择选项'9. 刷新并查看节点'选项${NC}"
        sleep 2
        
        if command -v sb &>/dev/null; then
            sb
        else
            bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
        fi
    else
        echo -e "${RED}Sing-box-yg未安装，请先安装${NC}"
        echo -e "${YELLOW}检查以下可能的安装路径：${NC}"
        echo -e "  - /usr/local/bin/sing-box: $([ -f "/usr/local/bin/sing-box" ] && echo "存在" || echo "不存在")"
        echo -e "  - /usr/bin/sing-box: $([ -f "/usr/bin/sing-box" ] && echo "存在" || echo "不存在")"
        echo -e "  - 配置文件: $([ -f "/usr/local/etc/sing-box/config.json" ] && echo "存在" || echo "不存在")"
        echo -e "  - sb命令: $(command -v sb &>/dev/null && echo "存在" || echo "不存在")"
        echo -e "  - systemd服务: $(systemctl status sing-box &>/dev/null && echo "存在" || echo "不存在")"
        
        echo -e "${YELLOW}是否强制尝试查看配置？(y/n)${NC}"
        read -p "选择 [y/n]: " FORCE_VIEW
        
        if [[ $FORCE_VIEW =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}尝试通过官方脚本查看配置...${NC}"
            bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
        fi
    fi
    
    read -p "按回车键继续..." temp
    singbox_management
}

# 卸载Sing-box-yg
uninstall_singbox_yg() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}卸载Sing-box-yg:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 使用统一的检测方法，与其他函数保持一致
    if [ -f "/usr/local/bin/sing-box" ] || [ -f "/usr/bin/sing-box" ] || 
       [ -f "/usr/local/etc/sing-box/config.json" ] || command -v sb &>/dev/null || 
       systemctl status sing-box &>/dev/null || 
       grep -q "Sing-box-yg" /root/.sb_logs/main_install.log 2>/dev/null; then
        
        # 如果sb命令存在，优先使用面板卸载
        if command -v sb &>/dev/null; then
            echo -e "${GREEN}检测到sb命令，使用面板卸载...${NC}"
            echo -e "${GREEN}请在面板中选择'2. 删除卸载Sing-box'选项${NC}"
            sleep 2
            sb
            
            # 询问用户是否已完成卸载
            echo ""
            read -p "您已在面板中执行卸载操作了吗？(y/n): " PANEL_UNINSTALL
            if [[ $PANEL_UNINSTALL =~ ^[Yy]$ ]]; then
                echo -e "${GREEN}卸载已完成，返回菜单${NC}"
                read -p "按回车键继续..." temp
                singbox_management
                return
            fi
        else
            # 如果没有sb命令，使用官方脚本
            echo -e "${GREEN}使用官方脚本卸载...${NC}"
            echo -e "${GREEN}请在脚本中选择'2. 删除卸载Sing-box'选项${NC}"
            sleep 2
            bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
            
            # 询问用户是否已完成卸载
            echo ""
            read -p "您已通过官方脚本执行卸载操作了吗？(y/n): " SCRIPT_UNINSTALL
            if [[ $SCRIPT_UNINSTALL =~ ^[Yy]$ ]]; then
                echo -e "${GREEN}卸载已完成，返回菜单${NC}"
                read -p "按回车键继续..." temp
                singbox_management
                return
            fi
        fi
        
        # 如果用户未确认卸载完成，执行强制清理
        echo -e "${YELLOW}执行强制清理操作...${NC}"
    else
        echo -e "${RED}未检测到Sing-box-yg安装痕迹${NC}"
        read -p "是否继续尝试强制清理？(y/n): " FORCE_CLEAN
        if [[ ! $FORCE_CLEAN =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}取消操作，返回菜单${NC}"
            read -p "按回车键继续..." temp
            singbox_management
            return
        fi
        echo -e "${YELLOW}执行强制清理操作...${NC}"
    fi
    
    # 清理二进制文件
    if [ -f "/usr/local/bin/sing-box" ]; then
        echo -e "${YELLOW}删除 /usr/local/bin/sing-box${NC}"
        rm -f /usr/local/bin/sing-box
    fi
    
    if [ -f "/usr/bin/sing-box" ]; then
        echo -e "${YELLOW}删除 /usr/bin/sing-box${NC}"
        rm -f /usr/bin/sing-box
    fi
    
    # 清理配置目录
    if [ -d "/usr/local/etc/sing-box" ]; then
        echo -e "${YELLOW}删除 /usr/local/etc/sing-box/${NC}"
        rm -rf /usr/local/etc/sing-box
    fi
    
    # 清理systemd服务
    if [ -f "/etc/systemd/system/sing-box.service" ]; then
        echo -e "${YELLOW}删除并停止sing-box服务${NC}"
        systemctl stop sing-box &>/dev/null
        systemctl disable sing-box &>/dev/null
        rm -f /etc/systemd/system/sing-box.service
        systemctl daemon-reload
    fi
    
    # 清理sb命令
    if [ -f "/usr/local/bin/sb" ]; then
        echo -e "${YELLOW}删除 /usr/local/bin/sb${NC}"
        rm -f /usr/local/bin/sb
    fi
    
    if [ -f "/usr/bin/sb" ]; then
        echo -e "${YELLOW}删除 /usr/bin/sb${NC}"
        rm -f /usr/bin/sb
    fi
    
    # 清理其他可能位置
    rm -f /usr/sbin/sing-box 2>/dev/null
    rm -f /opt/sing-box/sing-box 2>/dev/null
    rm -rf /opt/sing-box 2>/dev/null
    
    # 从安装日志中删除
    if [ -f "/root/.sb_logs/main_install.log" ]; then
        echo -e "${YELLOW}从安装日志中删除记录${NC}"
        sed -i '/Sing-box-yg/d' /root/.sb_logs/main_install.log 2>/dev/null
    fi
    
    # 杀死sing-box进程
    echo -e "${YELLOW}终止sing-box进程...${NC}"
    pkill -9 sing-box 2>/dev/null
    
    echo -e "${GREEN}Sing-box-yg强制清理完成${NC}"
    
    read -p "按回车键继续..." temp
    singbox_management
}

# BBR加速管理
bbr_management() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}BBR加速管理:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请选择要安装的BBR版本:${NC}"
    echo -e "${WHITE}1)${NC} ${GREEN}BBR原版${NC} - 官方原版BBR"
    echo -e "${WHITE}2)${NC} ${GREEN}BBRplus${NC} - BBR魔改版"
    echo -e "${WHITE}3)${NC} ${GREEN}BBRplus面板${NC} - 打开BBRplus管理面板"
    echo -e "${WHITE}4)${NC} ${GREEN}检查当前BBR状态${NC}"
    echo -e "${WHITE}5)${NC} ${RED}卸载BBR/BBRplus${NC}"
    echo -e "${WHITE}0)${NC} ${RED}返回上级菜单${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    read -p "请选择 [0-5]: " BBR_OPTION
    
    case $BBR_OPTION in
        1) install_original_bbr ;;
        2) install_bbrplus ;;
        3) show_bbrplus_panel ;;
        4) check_bbr_status ;;
        5) uninstall_bbr ;;
        0) return ;;
        *) 
            echo -e "${RED}无效选项，请重试${NC}"
            sleep 2
            bbr_management
            ;;
    esac
}

# 安装原版BBR
install_original_bbr() {
    echo -e "${GREEN}开始安装原版BBR...${NC}"
    
    # 检测系统是否已开启BBR
    if lsmod | grep -q "bbr"; then
        echo -e "${YELLOW}系统已启用BBR，无需重复安装${NC}"
        read -p "是否强制重新安装? (y/n): " REINSTALL
        if [[ ! $REINSTALL =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}已取消安装${NC}"
            read -p "按回车键继续..." temp
            bbr_management
            return
        fi
    fi
    
    # 检测系统内核版本
    KERNEL_VERSION=$(uname -r | cut -d- -f1)
    if [ "$(echo $KERNEL_VERSION | cut -d. -f1)" -lt 4 ] || ([ "$(echo $KERNEL_VERSION | cut -d. -f1)" -eq 4 ] && [ "$(echo $KERNEL_VERSION | cut -d. -f2)" -lt 9 ]); then
        echo -e "${RED}当前内核版本（$KERNEL_VERSION）过低，BBR需要4.9或更高版本${NC}"
        echo -e "${YELLOW}是否自动升级内核? (y/n)${NC}"
        read -p "选择 [y/n]: " UPGRADE_KERNEL
        
        if [[ $UPGRADE_KERNEL =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}开始升级内核...${NC}"
            
            if [ -f /etc/debian_version ]; then
                # Debian/Ubuntu系统
                apt update
                apt install -y linux-image-generic linux-headers-generic
            elif [ -f /etc/redhat-release ]; then
                # CentOS/RHEL系统
                rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
                if grep -q "release 7" /etc/redhat-release; then
                    # CentOS 7
                    rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
                elif grep -q "release 8" /etc/redhat-release; then
                    # CentOS 8
                    rpm -Uvh http://www.elrepo.org/elrepo-release-8.0-1.el8.elrepo.noarch.rpm
                elif grep -q "release 9" /etc/redhat-release; then
                    # CentOS/RHEL 9
                    rpm -Uvh http://www.elrepo.org/elrepo-release-9.0-1.el9.elrepo.noarch.rpm
                fi
                yum --enablerepo=elrepo-kernel install -y kernel-ml
                grub2-set-default 0
            fi
            
            echo -e "${GREEN}内核已升级，需要重启系统才能生效${NC}"
            echo -e "${YELLOW}系统将在10秒后重启...${NC}"
            sleep 10
            reboot
            return
        else
            echo -e "${RED}已取消内核升级，BBR将无法安装${NC}"
            read -p "按回车键继续..." temp
            bbr_management
            return
        fi
    fi
    
    # 开启BBR
    echo -e "${YELLOW}开始配置BBR...${NC}"
    
    # 检查是否已存在sysctl配置
    if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    fi
    
    if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    fi
    
    # 应用设置
    sysctl -p
    
    # 确认是否已启用BBR
    sleep 2
    if lsmod | grep -q "bbr" && sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        echo -e "${GREEN}BBR已成功启用${NC}"
    else
        echo -e "${RED}BBR可能未正确启用，请尝试重启系统${NC}"
    fi
    
    # 显示当前拥塞控制算法
    echo -e "${YELLOW}当前拥塞控制算法: $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')${NC}"
    
    read -p "按回车键继续..." temp
    bbr_management
}

# 安装BBRplus
install_bbrplus() {
    echo -e "${GREEN}开始安装BBRplus...${NC}"
    
    # 检测系统是否已开启BBRplus - 使用更安全的检测方式
    if { command -v lsmod &>/dev/null && lsmod | grep -q "bbr"; } && 
       { sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbrplus"; }; then
        echo -e "${YELLOW}系统已启用BBRplus，无需重复安装${NC}"
        read -p "是否强制重新安装? (y/n): " REINSTALL
        if [[ ! $REINSTALL =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}已取消安装${NC}"
            read -p "按回车键继续..." temp
            bbr_management
            return
        fi
    fi
    
    # 检查是否在本地安装记录中
    if [ -f "/root/.sb_logs/bbr_installed.log" ] && grep -q "BBRplus" "/root/.sb_logs/bbr_installed.log"; then
        echo -e "${YELLOW}本地记录显示BBRplus已安装${NC}"
        read -p "是否强制重新安装? (y/n): " REINSTALL
        if [[ ! $REINSTALL =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}已取消安装${NC}"
            read -p "按回车键继续..." temp
            bbr_management
            return
        fi
    fi
    
    # 检查系统
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu系统
        apt update
        apt install -y wget curl git make gcc
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL系统
        yum update -y
        yum install -y wget curl git make gcc
    else
        echo -e "${RED}不支持的系统类型${NC}"
        read -p "按回车键继续..." temp
        bbr_management
        return
    fi
    
    # 下载并运行BBRplus安装脚本
    echo -e "${YELLOW}下载BBRplus安装脚本...${NC}"
    wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
    
    echo -e "${GREEN}BBRplus安装脚本已下载，正在启动安装程序...${NC}"
    echo -e "${YELLOW}请在脚本中选择安装BBRplus对应的选项${NC}"
    sleep 3
    
    # 运行脚本
    ./tcp.sh
    
    # 安装后记录状态，避免重复安装
    mkdir -p /root/.sb_logs
    echo "BBRplus installed on $(date '+%Y-%m-%d %H:%M:%S')" >> /root/.sb_logs/bbr_installed.log
    
    read -p "按回车键继续..." temp
    bbr_management
}

# 显示BBRplus面板
show_bbrplus_panel() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}BBRplus管理面板:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 检查tcp.sh是否存在
    if [ ! -f "./tcp.sh" ]; then
        echo -e "${YELLOW}未找到BBRplus脚本，正在下载...${NC}"
        wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh
        
        if [ ! -f "./tcp.sh" ]; then
            echo -e "${RED}下载BBRplus脚本失败，请检查网络连接${NC}"
            read -p "按回车键继续..." temp
            bbr_management
            return
        fi
    fi
    
    # 运行BBRplus面板
    echo -e "${GREEN}正在打开BBRplus管理面板...${NC}"
    echo -e "${YELLOW}提示: 在面板中选择相应选项进行操作${NC}"
    
    # 运行脚本
    ./tcp.sh
    
    read -p "按回车键继续..." temp
    bbr_management
}

# 检查BBR状态
check_bbr_status() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}BBR状态检查:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 检查内核版本
    echo -e "${YELLOW}内核版本:${NC} $(uname -r)"
    
    # 检查拥塞控制算法
    echo -e "${YELLOW}当前拥塞控制算法:${NC} $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')"
    
    # 检查默认队列算法
    echo -e "${YELLOW}当前队列算法:${NC} $(sysctl net.core.default_qdisc | awk '{print $3}')"
    
    # 检查是否加载了BBR模块
    if command -v lsmod &>/dev/null; then
        if lsmod | grep -q "bbr"; then
            echo -e "${GREEN}BBR模块已加载${NC}"
        else
            echo -e "${RED}BBR模块未加载${NC}"
        fi
    else
        if [ -f "/root/.sb_logs/bbr_installed.log" ]; then
            echo -e "${YELLOW}无法检测内核模块，根据安装记录:${NC}"
            tail -n 1 /root/.sb_logs/bbr_installed.log
        else
            echo -e "${YELLOW}无法检测内核模块${NC}"
        fi
    fi
    
    # 检查可用的拥塞控制算法
    echo -e "${YELLOW}可用的拥塞控制算法:${NC}"
    sysctl net.ipv4.tcp_available_congestion_control
    
    # 检查是否启用了BBR
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        echo -e "${GREEN}BBR已启用${NC}"
    else
        echo -e "${RED}BBR未启用${NC}"
    fi
    
    read -p "按回车键继续..." temp
    bbr_management
}

# 卸载BBR/BBRplus
uninstall_bbr() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${RED}卸载BBR/BBRplus:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 检测当前系统使用的拥塞控制算法
    local current_cc=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    local bbr_installed=false
    local bbr_type=""
    
    # 检查是否已安装BBR
    if [ "$current_cc" = "bbr" ]; then
        bbr_installed=true
        bbr_type="原版BBR"
    elif [ "$current_cc" = "bbrplus" ]; then
        bbr_installed=true
        bbr_type="BBRplus"
    elif [ -f "/root/.sb_logs/bbr_installed.log" ]; then
        # 从安装记录检查
        if grep -q "BBRplus" "/root/.sb_logs/bbr_installed.log"; then
            bbr_installed=true
            bbr_type="BBRplus (根据安装记录)"
        elif grep -q "BBR" "/root/.sb_logs/bbr_installed.log"; then
            bbr_installed=true
            bbr_type="BBR (根据安装记录)"
        fi
    fi
    
    # 根据检测结果显示信息
    if [ "$bbr_installed" = true ]; then
        echo -e "${YELLOW}检测到系统已安装: ${GREEN}$bbr_type${NC}"
    else
        echo -e "${YELLOW}未检测到系统安装了BBR或BBRplus${NC}"
        read -p "是否继续尝试卸载? (y/n): " CONTINUE
        if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}已取消卸载${NC}"
            read -p "按回车键继续..." temp
            bbr_management
            return
        fi
    fi
    
    # 确认卸载
    echo -e "${YELLOW}您确定要卸载${bbr_type:+$bbr_type}吗?${NC}"
    read -p "确认卸载? (y/n): " CONFIRM
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}已取消卸载${NC}"
        read -p "按回车键继续..." temp
        bbr_management
        return
    fi
    
    echo -e "${YELLOW}正在卸载${bbr_type:+$bbr_type}...${NC}"
    
    # 检查tcp.sh是否存在，如果不存在则下载
    if [ ! -f "./tcp.sh" ]; then
        echo -e "${YELLOW}未找到BBRplus脚本，正在下载...${NC}"
        wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh
        
        if [ ! -f "./tcp.sh" ]; then
            echo -e "${RED}下载tcp.sh脚本失败，尝试手动卸载...${NC}"
            
            # 手动卸载BBR设置
            echo -e "${YELLOW}正在手动清除BBR设置...${NC}"
            sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
            sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
            sysctl -p
            
            echo -e "${GREEN}BBR设置已清除${NC}"
            # 清除安装记录
            if [ -f "/root/.sb_logs/bbr_installed.log" ]; then
                echo -e "${YELLOW}正在删除BBR安装记录...${NC}"
                sed -i '/BBR/d' /root/.sb_logs/bbr_installed.log
                sed -i '/bbr/d' /root/.sb_logs/bbr_installed.log
            fi
            
            echo -e "${GREEN}卸载完成${NC}"
            read -p "按回车键继续..." temp
            bbr_management
            return
        fi
    fi
    
    # 使用tcp.sh的卸载功能
    echo -e "${GREEN}调用tcp.sh脚本执行卸载...${NC}"
    echo -e "${YELLOW}请在弹出的菜单中选择'9. 卸载全部加速'选项${NC}"
    sleep 3
    
    # 运行脚本
    ./tcp.sh
    
    # 进行更彻底的清理
    echo -e "${YELLOW}正在执行额外的清理操作...${NC}"
    
    # 1. 移除内核模块
    echo -e "${YELLOW}移除相关内核模块...${NC}"
    rmmod tcp_bbr 2>/dev/null || echo -e "${YELLOW}移除tcp_bbr模块失败或模块未加载，继续清理...${NC}"
    rmmod tcp_bbrplus 2>/dev/null || echo -e "${YELLOW}移除tcp_bbrplus模块失败或模块未加载，继续清理...${NC}"
    
    # 2. 清理内核相关文件
    echo -e "${YELLOW}清理内核相关文件...${NC}"
    if [ -d "/lib/modules/$(uname -r)/kernel/net/ipv4" ]; then
        rm -f /lib/modules/$(uname -r)/kernel/net/ipv4/tcp_bbr.ko 2>/dev/null
        rm -f /lib/modules/$(uname -r)/kernel/net/ipv4/tcp_bbrplus.ko 2>/dev/null
    fi
    
    # 3. 清理sysctl配置
    echo -e "${YELLOW}清理系统配置...${NC}"
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    sysctl -p
    
    # 4. 移除临时文件和脚本
    echo -e "${YELLOW}清理临时文件和脚本...${NC}"
    rm -f ./tcp.sh
    rm -f ./bbr.sh
    rm -f ./bbrplus.sh
    
    # 5. 清除安装记录
    if [ -f "/root/.sb_logs/bbr_installed.log" ]; then
        echo -e "${YELLOW}删除BBR安装记录...${NC}"
        sed -i '/BBR/d' /root/.sb_logs/bbr_installed.log
        sed -i '/bbr/d' /root/.sb_logs/bbr_installed.log
    fi
    
    echo -e "${GREEN}BBR/BBRplus已完全卸载并清理${NC}"
    read -p "按回车键继续..." temp
    bbr_management
}
