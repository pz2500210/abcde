#!/bin/bash

# 设置工作目录为脚本所在目录（如果是直接执行）
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cd "$(dirname "$0")" || exit 1
    SCRIPT_DIR="$(pwd)"
fi

# 证书管理菜单
certificate_management() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}SSL证书管理:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请选择操作:${NC}"
    echo -e "  1) 安装新证书 (HTTP验证)"
    echo -e "  2) 创建自签名证书 (无域名)"
    echo -e "  3) 创建必应通配符证书 (*.bing.com)"
    echo -e "  4) 创建自定义通配符证书"
    echo -e "  5) 查看所有证书"
    echo -e "  6) 更新证书"
    echo -e "  7) 删除证书"
    echo -e "  8) 卸载acme.sh"
    echo -e "  0) 返回主菜单"
    
    read -p "选择 [0-8]: " CERT_OPTION
    
    case $CERT_OPTION in
        1) install_certificate_menu ;;
        2) create_self_signed_cert ;;
        3) create_bing_wildcard_cert ;;
        4) create_custom_wildcard_cert ;;
        5) view_all_certificates ;;
        6) update_certificates_menu ;;
        7) delete_certificate_menu ;;
        8) uninstall_acme ;;
        0) return ;;
        *) 
            echo -e "${RED}无效选项，请重试${NC}"
            sleep 2
            certificate_management
            ;;
    esac
}

# 卸载acme.sh
uninstall_acme() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}卸载acme.sh:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}警告: 卸载acme.sh将删除所有证书和相关配置${NC}"
    read -p "确定要卸载acme.sh吗? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "/root/.acme.sh/acme.sh" ]; then
            echo -e "${YELLOW}正在卸载acme.sh...${NC}"
            /root/.acme.sh/acme.sh --uninstall
            rm -rf /root/.acme.sh
            echo -e "${GREEN}acme.sh已成功卸载${NC}"
        else
            echo -e "${RED}未找到acme.sh安装，无需卸载${NC}"
        fi
    else
        echo -e "${YELLOW}已取消卸载操作${NC}"
    fi
    
    read -p "按回车键继续..." temp
    certificate_management
}

# DNS认证管理
dns_management() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}DNS认证管理:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请选择操作:${NC}"
    echo -e "  1) 使用DNS API申请证书"
    echo -e "  2) 使用DNS手动申请证书"
    echo -e "  3) 删除特定域名的证书"
    echo -e "  4) 删除所有证书"
    echo -e "  5) 更新acme.sh及其所有证书"
    echo -e "  0) 返回主菜单"
    
    read -p "选择 [0-5]: " DNS_OPTION
    
    case $DNS_OPTION in
        1) dns_api_certificate ;;
        2) dns_manual_certificate ;;
        3) delete_specific_certificate ;;
        4) delete_all_certificates_dns ;;
        5) update_acme_and_certs ;;
        0) return ;;
        *) 
            echo -e "${RED}无效选项，请重试${NC}"
            sleep 2
            dns_management
            ;;
    esac
}

# 使用DNS API申请证书
dns_api_certificate() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}使用DNS API申请证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请选择DNS提供商:${NC}"
    echo -e "  1) Cloudflare"
    echo -e "  2) Aliyun (阿里云)"
    echo -e "  3) DNSPod"
    echo -e "  4) GoDaddy"
    echo -e "  5) Namesilo"
    echo -e "  0) 返回"
    
    read -p "选择 [0-5]: " DNS_PROVIDER
    
    case $DNS_PROVIDER in
        1) dns_api_cloudflare ;;
        2) dns_api_aliyun ;;
        3) dns_api_dnspod ;;
        4) dns_api_godaddy ;;
        5) dns_api_namesilo ;;
        0) dns_management ;;
        *) 
            echo -e "${RED}无效选项，请重试${NC}"
            sleep 2
            dns_api_certificate
            ;;
    esac
}

# Cloudflare DNS API
dns_api_cloudflare() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}使用Cloudflare DNS API申请证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请输入域名:${NC}"
    read -p "域名: " DOMAIN
    
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}域名不能为空${NC}"
        read -p "按回车键继续..." temp
        dns_api_certificate
        return
    fi
    
    echo -e "${YELLOW}请输入Cloudflare Global API Key:${NC}"
    read -p "API Key: " CF_KEY
    
    echo -e "${YELLOW}请输入Cloudflare Email:${NC}"
    read -p "Email: " CF_EMAIL
    
    if [ -z "$CF_KEY" ] || [ -z "$CF_EMAIL" ]; then
        echo -e "${RED}API Key和Email不能为空${NC}"
        read -p "按回车键继续..." temp
        dns_api_certificate
        return
    fi
    
    # 安装acme.sh
    install_acme
    
    # 设置环境变量
    export CF_Key="$CF_KEY"
    export CF_Email="$CF_EMAIL"
    
    # 申请证书
    /root/.acme.sh/acme.sh --issue --dns dns_cf -d "$DOMAIN" -d "*.$DOMAIN"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}证书申请成功${NC}"
        
        # 安装证书
        install_certificate "$DOMAIN"
    else
        echo -e "${RED}证书申请失败${NC}"
    fi
    
    read -p "按回车键继续..." temp
    dns_management
}

# 阿里云DNS API
dns_api_aliyun() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}使用阿里云DNS API申请证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请输入域名:${NC}"
    read -p "域名: " DOMAIN
    
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}域名不能为空${NC}"
        read -p "按回车键继续..." temp
        dns_api_certificate
        return
    fi
    
    echo -e "${YELLOW}请输入阿里云AccessKey ID:${NC}"
    read -p "AccessKey ID: " ALI_KEY
    
    echo -e "${YELLOW}请输入阿里云AccessKey Secret:${NC}"
    read -p "AccessKey Secret: " ALI_SECRET
    
    if [ -z "$ALI_KEY" ] || [ -z "$ALI_SECRET" ]; then
        echo -e "${RED}AccessKey ID和Secret不能为空${NC}"
        read -p "按回车键继续..." temp
        dns_api_certificate
        return
    fi
    
    # 安装acme.sh
    install_acme
    
    # 设置环境变量
    export Ali_Key="$ALI_KEY"
    export Ali_Secret="$ALI_SECRET"
    
    # 申请证书
    /root/.acme.sh/acme.sh --issue --dns dns_ali -d "$DOMAIN" -d "*.$DOMAIN"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}证书申请成功${NC}"
        
        # 安装证书
        install_certificate "$DOMAIN"
    else
        echo -e "${RED}证书申请失败${NC}"
    fi
    
    read -p "按回车键继续..." temp
    dns_management
}

# DNSPod DNS API
dns_api_dnspod() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}使用DNSPod DNS API申请证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请输入域名:${NC}"
    read -p "域名: " DOMAIN
    
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}域名不能为空${NC}"
        read -p "按回车键继续..." temp
        dns_api_certificate
        return
    fi
    
    echo -e "${YELLOW}请输入DNSPod ID:${NC}"
    read -p "DNSPod ID: " DP_ID
    
    echo -e "${YELLOW}请输入DNSPod Token:${NC}"
    read -p "DNSPod Token: " DP_KEY
    
    if [ -z "$DP_ID" ] || [ -z "$DP_KEY" ]; then
        echo -e "${RED}DNSPod ID和Token不能为空${NC}"
        read -p "按回车键继续..." temp
        dns_api_certificate
        return
    fi
    
    # 安装acme.sh
    install_acme
    
    # 设置环境变量
    export DP_Id="$DP_ID"
    export DP_Key="$DP_KEY"
    
    # 申请证书
    /root/.acme.sh/acme.sh --issue --dns dns_dp -d "$DOMAIN" -d "*.$DOMAIN"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}证书申请成功${NC}"
        
        # 安装证书
        install_certificate "$DOMAIN"
    else
        echo -e "${RED}证书申请失败${NC}"
    fi
    
    read -p "按回车键继续..." temp
    dns_management
}

# GoDaddy DNS API
dns_api_godaddy() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}使用GoDaddy DNS API申请证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请输入域名:${NC}"
    read -p "域名: " DOMAIN
    
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}域名不能为空${NC}"
        read -p "按回车键继续..." temp
        dns_api_certificate
        return
    fi
    
    echo -e "${YELLOW}请输入GoDaddy API Key:${NC}"
    read -p "API Key: " GD_KEY
    
    echo -e "${YELLOW}请输入GoDaddy API Secret:${NC}"
    read -p "API Secret: " GD_SECRET
    
    if [ -z "$GD_KEY" ] || [ -z "$GD_SECRET" ]; then
        echo -e "${RED}API Key和Secret不能为空${NC}"
        read -p "按回车键继续..." temp
        dns_api_certificate
        return
    fi
    
    # 安装acme.sh
    install_acme
    
    # 设置环境变量
    export GD_Key="$GD_KEY"
    export GD_Secret="$GD_SECRET"
    
    # 申请证书
    /root/.acme.sh/acme.sh --issue --dns dns_gd -d "$DOMAIN" -d "*.$DOMAIN"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}证书申请成功${NC}"
        
        # 安装证书
        install_certificate "$DOMAIN"
    else
        echo -e "${RED}证书申请失败${NC}"
    fi
    
    read -p "按回车键继续..." temp
    dns_management
}

# Namesilo DNS API
dns_api_namesilo() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}使用Namesilo DNS API申请证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请输入域名:${NC}"
    read -p "域名: " DOMAIN
    
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}域名不能为空${NC}"
        read -p "按回车键继续..." temp
        dns_api_certificate
        return
    fi
    
    echo -e "${YELLOW}请输入Namesilo API Key:${NC}"
    read -p "API Key: " NS_KEY
    
    if [ -z "$NS_KEY" ]; then
        echo -e "${RED}API Key不能为空${NC}"
        read -p "按回车键继续..." temp
        dns_api_certificate
        return
    fi
    
    # 安装acme.sh
    install_acme
    
    # 设置环境变量
    export Namesilo_Key="$NS_KEY"
    
    # 申请证书
    /root/.acme.sh/acme.sh --issue --dns dns_namesilo -d "$DOMAIN" -d "*.$DOMAIN"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}证书申请成功${NC}"
        
        # 安装证书
        install_certificate "$DOMAIN"
    else
        echo -e "${RED}证书申请失败${NC}"
    fi
    
    read -p "按回车键继续..." temp
    dns_management
}

# 使用DNS手动申请证书
dns_manual_certificate() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}使用DNS手动申请证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请输入域名:${NC}"
    read -p "域名: " DOMAIN
    
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}域名不能为空${NC}"
        read -p "按回车键继续..." temp
        dns_management
        return
    fi
    
    # 安装acme.sh
    install_acme
    
    # 申请证书
    /root/.acme.sh/acme.sh --issue --dns -d "$DOMAIN" -d "*.$DOMAIN" --yes-I-know-dns-manual-mode-enough-go-ahead-please
    
    echo -e "${YELLOW}请在DNS控制面板中添加上述TXT记录，然后按回车键继续...${NC}"
    read -p "按回车键继续..." temp
    
    # 验证并颁发证书
    /root/.acme.sh/acme.sh --renew -d "$DOMAIN" --yes-I-know-dns-manual-mode-enough-go-ahead-please
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}证书申请成功${NC}"
        
        # 安装证书
        install_certificate "$DOMAIN"
    else
        echo -e "${RED}证书申请失败${NC}"
    fi
    
    read -p "按回车键继续..." temp
    dns_management
}

# 删除特定域名的证书 (DNS管理专用)
delete_specific_certificate() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}删除特定域名的证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请输入要删除的域名:${NC}"
    read -p "域名: " DELETE_DOMAIN
    
    if [ -z "$DELETE_DOMAIN" ]; then
        echo -e "${RED}域名不能为空${NC}"
        read -p "按回车键继续..." temp
        dns_management
        return
    fi
    
    # 使用acme.sh删除证书
    if [ -f "/root/.acme.sh/acme.sh" ]; then
        /root/.acme.sh/acme.sh --revoke -d "$DELETE_DOMAIN" --force
        /root/.acme.sh/acme.sh --remove -d "$DELETE_DOMAIN" --force
        
        # 删除证书文件
        rm -f "/root/cert/${DELETE_DOMAIN}.pem"
        rm -f "/root/cert/${DELETE_DOMAIN}.key"
        
        # 从安装日志中删除
        sed -i "/SSL证书:${DELETE_DOMAIN}/d" /root/.sb_logs/main_install.log 2>/dev/null
        
        echo -e "${GREEN}证书已删除${NC}"
    else
        echo -e "${RED}未找到acme.sh，无法删除证书${NC}"
    fi
    
    read -p "按回车键继续..." temp
    dns_management
}

# 删除所有证书 (DNS管理专用)
delete_all_certificates_dns() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}删除所有证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${RED}警告: 此操作将删除所有证书!${NC}"
    echo -e "${YELLOW}是否继续? (y/n)${NC}"
    read -p "选择 [y/n]: " DELETE_ALL_CONFIRM
    
    if [[ $DELETE_ALL_CONFIRM =~ ^[Yy]$ ]]; then
        # 使用acme.sh卸载
        if [ -f "/root/.acme.sh/acme.sh" ]; then
            /root/.acme.sh/acme.sh --uninstall
            rm -rf /root/.acme.sh
            
            # 删除证书文件
            rm -rf /root/cert
            
            # 清空安装日志中的证书记录
            sed -i '/SSL证书:/d' /root/.sb_logs/main_install.log 2>/dev/null
            
            echo -e "${GREEN}所有证书已删除${NC}"
        else
            echo -e "${RED}未找到acme.sh，无法删除证书${NC}"
        fi
    else
        echo -e "${YELLOW}已取消删除${NC}"
    fi
    
    read -p "按回车键继续..." temp
    dns_management
}

# 更新acme.sh及其所有证书
update_acme_and_certs() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}更新acme.sh及其所有证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 更新acme.sh
    if [ -f "/root/.acme.sh/acme.sh" ]; then
        echo -e "${YELLOW}更新acme.sh...${NC}"
        /root/.acme.sh/acme.sh --upgrade
        
        echo -e "${YELLOW}更新所有证书...${NC}"
        /root/.acme.sh/acme.sh --renew-all
        
        echo -e "${GREEN}acme.sh和所有证书已更新${NC}"
    else
        echo -e "${RED}未找到acme.sh，无法更新${NC}"
    fi
    
    read -p "按回车键继续..." temp
    dns_management
}

# 安装证书菜单
install_certificate_menu() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}安装SSL证书 (HTTP验证):${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请输入域名:${NC}"
    read -p "域名: " DOMAIN
    
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}域名不能为空${NC}"
        read -p "按回车键继续..." temp
        certificate_management
        return
    fi
    
    # 安装acme.sh
    install_acme
    
    # 申请证书
    issue_certificate_http "$DOMAIN"
    
    read -p "按回车键继续..." temp
    certificate_management
}

# 安装acme.sh
install_acme() {
    if [ ! -f "/root/.acme.sh/acme.sh" ]; then
        echo -e "${YELLOW}安装acme.sh所需环境...${NC}"
        
        # 检测系统类型
        if [ -f /etc/debian_version ]; then
            # Debian/Ubuntu系统
            apt update
            apt install -y curl socat cron ca-certificates openssl
            
            # 确保cron服务启动
            systemctl enable cron
            systemctl start cron
        elif [ -f /etc/redhat-release ]; then
            # CentOS/RHEL系统
            yum install -y curl socat cronie ca-certificates openssl
            
            # 确保cron服务启动
            systemctl enable crond
            systemctl start crond
        else
            echo -e "${RED}不支持的系统类型${NC}"
            return 1
        fi
        
        echo -e "${YELLOW}安装acme.sh...${NC}"
        curl https://get.acme.sh | sh
        
        # 如果安装失败，尝试强制安装
        if [ ! -f "/root/.acme.sh/acme.sh" ]; then
            echo -e "${YELLOW}尝试强制安装acme.sh...${NC}"
            curl https://get.acme.sh | sh -s -- --force
        fi
    fi
    
    # 检查安装是否成功
    if [ ! -f "/root/.acme.sh/acme.sh" ]; then
        echo -e "${RED}acme.sh安装失败，请检查网络或手动安装${NC}"
        return 1
    fi
    
    # 设置默认CA
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
}

# 使用HTTP验证申请证书
issue_certificate_http() {
    local domain=$1
    
    echo -e "${YELLOW}使用HTTP验证申请证书...${NC}"
    
    # 询问邮箱
    echo -e "${YELLOW}请输入您的邮箱 (用于接收证书过期通知):${NC}"
    echo -e "${YELLOW}如果不填写，将使用默认邮箱 xxxx@xxxx.com${NC}"
    read -p "邮箱: " EMAIL
    
    # 如果未提供邮箱，使用默认邮箱
    if [ -z "$EMAIL" ]; then
        EMAIL="admin@${domain}"
        echo -e "${YELLOW}使用默认邮箱: ${EMAIL}${NC}"
    fi
    
    # 检查80端口是否被占用
    if netstat -tuln | grep -q ':80 '; then
        echo -e "${YELLOW}检测到80端口被占用，尝试停止占用服务...${NC}"
        # 尝试停止可能占用80端口的服务
        systemctl stop nginx 2>/dev/null || true
        systemctl stop apache2 2>/dev/null || true
        systemctl stop httpd 2>/dev/null || true
        
        # 再次检查端口
        if netstat -tuln | grep -q ':80 '; then
            echo -e "${RED}无法释放80端口，请手动停止占用80端口的服务后重试${NC}"
            return 1
        fi
    fi
    
    # 确保防火墙允许80端口
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 80/tcp >/dev/null 2>&1 || true
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=80/tcp >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
    elif command -v iptables >/dev/null 2>&1; then
        iptables -I INPUT -p tcp --dport 80 -j ACCEPT >/dev/null 2>&1 || true
    fi
    
    # 注册邮箱
    /root/.acme.sh/acme.sh --register-account -m "$EMAIL"
    
    # 使用standalone模式申请证书
    /root/.acme.sh/acme.sh --issue -d "$domain" --standalone
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}证书申请成功${NC}"
        
        # 安装证书
        install_certificate "$domain"
    else
        echo -e "${RED}证书申请失败${NC}"
    fi
}

# 安装证书
install_certificate() {
    local domain=$1
    
    echo -e "${YELLOW}安装证书...${NC}"
    
    # 询问证书安装位置
    echo -e "${YELLOW}请选择证书安装位置:${NC}"
    echo -e "  1) 默认位置 (/root/cert/${domain}.key 和 /root/cert/${domain}.pem)"
    echo -e "  2) 系统默认位置 (/etc/ssl/private/${domain}.key 和 /etc/ssl/certs/${domain}.pem)"
    echo -e "  3) 自定义位置"
    read -p "选择 [1-3] (默认: 1): " CERT_LOCATION
    CERT_LOCATION=${CERT_LOCATION:-1}
    
    # 根据选择设置证书路径
    case $CERT_LOCATION in
        1)
            # 默认位置
            mkdir -p /root/cert
            KEY_FILE="/root/cert/${domain}.key"
            CERT_FILE="/root/cert/${domain}.pem"
            ;;
        2)
            # 系统默认位置
            mkdir -p /etc/ssl/private
            mkdir -p /etc/ssl/certs
            KEY_FILE="/etc/ssl/private/${domain}.key"
            CERT_FILE="/etc/ssl/certs/${domain}.pem"
            ;;
        3)
            # 自定义位置
            echo -e "${YELLOW}请输入私钥文件路径:${NC}"
            read -p "私钥路径: " KEY_FILE
            echo -e "${YELLOW}请输入证书文件路径:${NC}"
            read -p "证书路径: " CERT_FILE
            
            # 创建目录
            mkdir -p $(dirname "$KEY_FILE")
            mkdir -p $(dirname "$CERT_FILE")
            ;;
        *)
            echo -e "${RED}无效选项，使用默认位置${NC}"
            mkdir -p /root/cert
            KEY_FILE="/root/cert/${domain}.key"
            CERT_FILE="/root/cert/${domain}.pem"
            ;;
    esac
    
    # 安装证书
    /root/.acme.sh/acme.sh --install-cert -d "$domain" \
        --key-file "$KEY_FILE" \
        --fullchain-file "$CERT_FILE"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}证书安装成功${NC}"
        
        # 设置适当的权限
        chmod 644 "$CERT_FILE"
        chmod 600 "$KEY_FILE"
        echo -e "${GREEN}证书权限已设置${NC}"
        
        # 更新主安装记录，包括证书位置
        update_main_install_log "SSL证书:$domain"
        update_main_install_log "证书路径:$CERT_FILE"
        update_main_install_log "私钥路径:$KEY_FILE"
        
        echo -e "${YELLOW}证书信息:${NC}"
        echo -e "  证书路径: $CERT_FILE"
        echo -e "  私钥路径: $KEY_FILE"
    else
        echo -e "${RED}证书安装失败${NC}"
    fi
}

# 更新证书菜单
update_certificates_menu() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}更新SSL证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    local main_log="/root/.sb_logs/main_install.log"
    local domains=()
    local cert_types=()
    
    # 获取所有已安装的证书域名（仅限CA签名证书，自签名证书不需要更新）
    while IFS= read -r line; do
        if [[ $line == *"SSL证书:"* && $line != *"自签名证书"* ]]; then
            domain=$(echo $line | cut -d':' -f2)
            domains+=("$domain")
            cert_types+=("CA签名")
        fi
    done < "$main_log"
    
    if [ ${#domains[@]} -eq 0 ]; then
        echo -e "${RED}未找到可更新的CA签名证书${NC}"
        echo -e "${YELLOW}注意: 自签名证书不需要更新，如需更新请重新创建${NC}"
        read -p "按回车键继续..." temp
        certificate_management
        return
    fi
    
    echo -e "${YELLOW}可更新的证书:${NC}"
    
    for i in "${!domains[@]}"; do
        echo -e "  $((i+1))) ${domains[$i]}"
    done
    
    echo -e "  0) 更新所有证书"
    echo -e "  q) 返回上级菜单"
    
    read -p "选择要更新的证书 [0-${#domains[@]}]/q: " CERT_CHOICE
    
    if [[ $CERT_CHOICE == "q" || $CERT_CHOICE == "Q" ]]; then
        certificate_management
        return
    fi
    
    if [[ $CERT_CHOICE -eq 0 ]]; then
        # 更新所有证书
        /root/.acme.sh/acme.sh --renew-all --force
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}所有证书更新成功${NC}"
        else
            echo -e "${RED}部分证书更新失败，请检查日志${NC}"
        fi
    elif [[ $CERT_CHOICE -ge 1 && $CERT_CHOICE -le ${#domains[@]} ]]; then
        # 更新选定的证书
        domain=${domains[$CERT_CHOICE-1]}
        
        /root/.acme.sh/acme.sh --renew -d "$domain" --force
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}证书 $domain 更新成功${NC}"
        else
            echo -e "${RED}证书 $domain 更新失败${NC}"
        fi
    else
        echo -e "${RED}无效选择${NC}"
    fi
    
    read -p "按回车键继续..." temp
    certificate_management
}

# 删除证书菜单
delete_certificate_menu() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}删除SSL证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    local main_log="/root/.sb_logs/main_install.log"
    local domains=()
    local cert_types=()
    local cert_paths=()
    local cert_exists=()
    local valid_certs=0
    
    # 检查日志是否存在
    if [ ! -f "$main_log" ]; then
        echo -e "${RED}未找到证书日志文件${NC}"
        echo -e "  ${RED}D)${NC} ${RED}删除所有证书${NC}"
        echo -e "  0) 返回上级菜单"
        read -p "选择 [D/0]: " CERT_CHOICE
        if [[ $CERT_CHOICE != "0" ]]; then
            echo -e "${YELLOW}没有证书可以删除${NC}"
            sleep 2
        fi
        certificate_management
        return
    fi
    
    # 获取所有已安装的证书域名（包括CA签名和自签名）
    while IFS= read -r line; do
        if [[ $line == *"SSL证书:"* ]]; then
            domain=$(echo $line | cut -d':' -f2)
            domains+=("$domain")
            cert_types+=("CA签名")
            cert_path=$(grep "证书路径.*$domain" $main_log | head -1 | cut -d':' -f3-)
            cert_paths+=("$cert_path")
            cert_exists+=(false) # 初始设为不存在，后面检查
        elif [[ $line == *"自签名证书:"* ]]; then
            domain=$(echo $line | cut -d':' -f2)
            domains+=("$domain")
            cert_types+=("自签名")
            
            # 尝试以多种方式获取路径
            cert_path=""
            
            # 从日志中尝试获取
            cert_path=$(grep "证书路径.*$domain" $main_log | head -1 | cut -d':' -f3-)
            
            # 如果获取不到，尝试构建默认路径
            if [ -z "$cert_path" ]; then
                if [[ "$domain" == "*.bing.com" ]]; then
                    cert_path="/root/cert/self-signed/bing_wildcard.pem"
                else
                    # 尝试根据域名构建路径
                    domain_clean=$(echo $domain | tr -d '*.' | tr -d ':/' | sed 's/ /_/g')
                    possible_path="/root/cert/self-signed/${domain_clean}.pem"
                    if [ -f "$possible_path" ]; then
                        cert_path="$possible_path"
                    else
                        # 尝试通配符路径
                        possible_path="/root/cert/self-signed/${domain_clean}_wildcard.pem"
                        if [ -f "$possible_path" ]; then
                            cert_path="$possible_path"
                        fi
                    fi
                fi
            fi
            
            # 作为最后手段，使用find查找
            if [ -z "$cert_path" ] || [ ! -f "$cert_path" ]; then
                domain_clean=$(echo $domain | tr -d '*.' | tr -d ':/' | sed 's/ /_/g')
                found_cert=$(find /root/cert -type f -name "*${domain_clean}*.pem" 2>/dev/null | head -1)
                if [ ! -z "$found_cert" ]; then
                    cert_path="$found_cert"
                fi
            fi
            
            cert_paths+=("$cert_path")
            cert_exists+=(false) # 初始设为不存在，后面检查
        fi
    done < "$main_log"
    
    # 检查证书文件是否实际存在，并计算实际存在的证书数量
    for i in "${!domains[@]}"; do
        if [ ! -z "${cert_paths[$i]}" ] && [ -f "${cert_paths[$i]}" ]; then
            cert_exists[$i]=true
            valid_certs=$((valid_certs+1))
        else
            # 尝试查找实际文件
            local domain_clean=""
            local found=false
            
            if [[ "${domains[$i]}" == "*.bing.com" ]] && [ -f "/root/cert/self-signed/bing_wildcard.pem" ]; then
                cert_paths[$i]="/root/cert/self-signed/bing_wildcard.pem"
                found=true
            else
                domain_clean=$(echo "${domains[$i]}" | tr -d '*.' | tr -d ':/' | sed 's/ /_/g')
                if [ -f "/root/cert/self-signed/${domain_clean}.pem" ]; then
                    cert_paths[$i]="/root/cert/self-signed/${domain_clean}.pem"
                    found=true
                elif [ -f "/root/cert/self-signed/${domain_clean}_wildcard.pem" ]; then
                    cert_paths[$i]="/root/cert/self-signed/${domain_clean}_wildcard.pem"
                    found=true
                fi
            fi
            
            if [ "$found" = true ]; then
                cert_exists[$i]=true
                valid_certs=$((valid_certs+1))
            fi
        fi
    done
    
    # 检查是否有证书
    if [ $valid_certs -eq 0 ]; then
        # 无证书时的显示
        echo -e "${RED}未找到任何有效的证书文件${NC}"
        echo -e "  ${RED}D)${NC} ${RED}删除所有证书${NC}"
        echo -e "  0) 返回上级菜单"
        
        read -p "选择 [D/0]: " CERT_CHOICE
        
        if [[ $CERT_CHOICE == "D" || $CERT_CHOICE == "d" ]]; then
            # 如果日志中有记录，清理它们
            if grep -q "SSL证书:\|自签名证书:" "$main_log" 2>/dev/null; then
                sed -i '/SSL证书:/d' "$main_log" 2>/dev/null
                sed -i '/自签名证书:/d' "$main_log" 2>/dev/null
                sed -i '/证书路径:/d' "$main_log" 2>/dev/null
                sed -i '/私钥路径:/d' "$main_log" 2>/dev/null
                echo -e "${GREEN}证书记录已清理${NC}"
                sleep 2
            else
                echo -e "${YELLOW}没有证书可以删除${NC}"
                sleep 2
            fi
        fi
        
        certificate_management
        return
    fi
    
    # 显示存在的证书
    echo -e "${YELLOW}已安装的证书:${NC}"
    
    local display_index=1
    for i in "${!domains[@]}"; do
        # 只显示实际存在的证书
        if [ "${cert_exists[$i]}" = true ]; then
            echo -e "  $display_index) ${domains[$i]}"
            echo -e "      类型: ${cert_types[$i]}"
            
            echo -e "      证书路径: ${cert_paths[$i]}"
            # 显示对应的密钥路径
            key_path="${cert_paths[$i]%.*}.key"
            if [ -f "$key_path" ]; then
                echo -e "      密钥路径: ${key_path}"
            else
                echo -e "      密钥路径: ${RED}未找到文件${NC}"
            fi
        fi
    done
    
    echo -e "  ${RED}D)${NC} ${RED}删除所有证书${NC}"
    echo -e "  0) 返回上级菜单"
    
    read -p "选择要删除的证书 [1-$((display_index-1))/D/0]: " CERT_CHOICE
    
    if [[ $CERT_CHOICE == "q" || $CERT_CHOICE == "Q" || $CERT_CHOICE == "0" ]]; then
        certificate_management
        return
    fi
    
    if [[ $CERT_CHOICE == "D" || $CERT_CHOICE == "d" ]]; then
        # 二次确认
        echo -e "${RED}警告: 您即将删除所有证书!${NC}"
        read -p "是否继续? (y/n): " CONFIRM
        
        if [[ $CONFIRM =~ ^[Yy]$ ]]; then
            # 删除所有证书
            for i in "${!domains[@]}"; do
                if [[ "${cert_types[$i]}" == "CA签名" ]]; then
                    # 使用acme.sh删除CA签名证书
                    if [ -f "/root/.acme.sh/acme.sh" ]; then
                        /root/.acme.sh/acme.sh --revoke -d "${domains[$i]}" --force
                        /root/.acme.sh/acme.sh --remove -d "${domains[$i]}" --force
                    fi
                fi
                
                # 删除证书文件
                local cert_path="${cert_paths[$i]}"
                if [ -z "$cert_path" ] || [ ! -f "$cert_path" ]; then
                    # 尝试找到正确的路径
                    if [[ "${domains[$i]}" == "*.bing.com" ]] && [ -f "/root/cert/self-signed/bing_wildcard.pem" ]; then
                        cert_path="/root/cert/self-signed/bing_wildcard.pem"
                    else
                        domain_clean=$(echo "${domains[$i]}" | tr -d '*.' | tr -d ':/' | sed 's/ /_/g')
                        if [ -f "/root/cert/self-signed/${domain_clean}.pem" ]; then
                            cert_path="/root/cert/self-signed/${domain_clean}.pem"
                        elif [ -f "/root/cert/self-signed/${domain_clean}_wildcard.pem" ]; then
                            cert_path="/root/cert/self-signed/${domain_clean}_wildcard.pem"
                        fi
                    fi
                fi
                
                if [ ! -z "$cert_path" ] && [ -f "$cert_path" ]; then
                    echo -e "${YELLOW}删除证书文件: $cert_path${NC}"
                    rm -f "$cert_path"
                    # 删除对应的密钥文件
                    key_path="${cert_path%.*}.key"
                    if [ -f "$key_path" ]; then
                        echo -e "${YELLOW}删除密钥文件: $key_path${NC}"
                        rm -f "$key_path"
                    fi
                fi
                
                # 从安装日志中删除
                if [[ "${cert_types[$i]}" == "CA签名" ]]; then
                    sed -i "/SSL证书:${domains[$i]}/d" "$main_log"
                else
                    sed -i "/自签名证书:${domains[$i]}/d" "$main_log"
                fi
                sed -i "/证书路径.*${domains[$i]}/d" "$main_log"
                sed -i "/私钥路径.*${domains[$i]}/d" "$main_log"
            done
            
            echo -e "${GREEN}所有证书已删除${NC}"
        else
            echo -e "${YELLOW}操作已取消${NC}"
        fi
    elif [[ $CERT_CHOICE =~ ^[0-9]+$ ]] && [ $CERT_CHOICE -ge 1 ] && [ $CERT_CHOICE -le ${#domains[@]} ]; then
        # 删除选定的证书
        local idx=$((CERT_CHOICE-1))
        local domain="${domains[$idx]}"
        local type="${cert_types[$idx]}"
        local path="${cert_paths[$idx]}"
        
        # 验证和更新路径
        if [ -z "$path" ] || [ ! -f "$path" ]; then
            # 尝试找到正确的路径
            if [[ "$domain" == "*.bing.com" ]] && [ -f "/root/cert/self-signed/bing_wildcard.pem" ]; then
                path="/root/cert/self-signed/bing_wildcard.pem"
            else
                domain_clean=$(echo "$domain" | tr -d '*.' | tr -d ':/' | sed 's/ /_/g')
                if [ -f "/root/cert/self-signed/${domain_clean}.pem" ]; then
                    path="/root/cert/self-signed/${domain_clean}.pem"
                elif [ -f "/root/cert/self-signed/${domain_clean}_wildcard.pem" ]; then
                    path="/root/cert/self-signed/${domain_clean}_wildcard.pem"
                fi
            fi
        fi
        
        # 显示找到的路径
        if [ ! -z "$path" ] && [ -f "$path" ]; then
            echo -e "${YELLOW}找到证书文件: $path${NC}"
        fi
        
        # 二次确认
        echo -e "${RED}警告: 您即将删除证书 $domain!${NC}"
        read -p "是否继续? (y/n): " CONFIRM
        
        if [[ $CONFIRM =~ ^[Yy]$ ]]; then
            if [[ "$type" == "CA签名" ]]; then
                # 使用acme.sh删除CA签名证书
                if [ -f "/root/.acme.sh/acme.sh" ]; then
                    /root/.acme.sh/acme.sh --revoke -d "$domain" --force
                    /root/.acme.sh/acme.sh --remove -d "$domain" --force
                fi
                
                # 从安装日志中删除
                sed -i "/SSL证书:$domain/d" "$main_log"
            else
                # 删除自签名证书
                # 从安装日志中删除
                sed -i "/自签名证书:$domain/d" "$main_log"
            fi
            
            # 删除证书文件
            if [ ! -z "$path" ] && [ -f "$path" ]; then
                echo -e "${YELLOW}删除证书文件: $path${NC}"
                rm -f "$path"
                # 删除对应的密钥文件
                key_path="${path%.*}.key"
                if [ -f "$key_path" ]; then
                    echo -e "${YELLOW}删除密钥文件: $key_path${NC}"
                    rm -f "$key_path"
                fi
            else
                echo -e "${RED}未找到证书文件，无法删除${NC}"
            fi
            
            # 从安装日志中删除路径记录
            sed -i "/证书路径.*$domain/d" "$main_log"
            sed -i "/私钥路径.*$domain/d" "$main_log"
            
            echo -e "${GREEN}证书 $domain 已删除${NC}"
        else
            echo -e "${YELLOW}操作已取消${NC}"
        fi
    else
        echo -e "${RED}无效选择${NC}"
    fi
    
    read -p "按回车键继续..." temp
    certificate_management
}

# 检查证书状态
check_certificate_status() {
    local domain=$1
    
    # 获取证书文件路径
    local cert_file=""
    local key_file=""
    
    # 从安装日志中获取证书路径
    if [ -f "/root/.sb_logs/main_install.log" ]; then
        cert_file=$(grep "证书路径.*$domain" /root/.sb_logs/main_install.log | cut -d':' -f2-)
        key_file=$(grep "私钥路径.*$domain" /root/.sb_logs/main_install.log | cut -d':' -f2-)
    fi
    
    # 如果找不到路径，尝试默认路径
    if [ -z "$cert_file" ]; then
        cert_file="/root/cert/${domain}.pem"
    fi
    
    if [ -z "$key_file" ]; then
        key_file="/root/cert/${domain}.key"
    fi
    
    # 检查证书文件是否存在
    if [ ! -f "$cert_file" ]; then
        echo -e "${RED}证书文件不存在: $cert_file${NC}"
        return 1
    fi
    
    # 检查私钥文件是否存在
    if [ ! -f "$key_file" ]; then
        echo -e "${RED}私钥文件不存在: $key_file${NC}"
        return 1
    fi
    
    # 检查证书有效性
    echo -e "${YELLOW}证书信息:${NC}"
    openssl x509 -in "$cert_file" -text -noout | grep -E "Subject:|Issuer:|Not Before:|Not After :|DNS:" --color=never
    
    # 检查证书和私钥是否匹配
    echo -e "${YELLOW}检查证书和私钥是否匹配...${NC}"
    cert_md5=$(openssl x509 -noout -modulus -in "$cert_file" | openssl md5)
    key_md5=$(openssl rsa -noout -modulus -in "$key_file" | openssl md5)
    
    if [ "$cert_md5" = "$key_md5" ]; then
        echo -e "${GREEN}证书和私钥匹配${NC}"
    else
        echo -e "${RED}证书和私钥不匹配${NC}"
    fi
    
    # 检查是否为自签名证书
    echo -e "${YELLOW}检查是否为自签名证书...${NC}"
    issuer=$(openssl x509 -in "$cert_file" -noout -issuer)
    subject=$(openssl x509 -in "$cert_file" -noout -subject)
    
    if [ "$issuer" = "$subject" ]; then
        echo -e "${RED}这是一个自签名证书${NC}"
    else
        echo -e "${GREEN}这是一个CA签名证书${NC}"
    fi
    
    return 0
}

# 创建自签名证书
create_self_signed_cert() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}创建自签名证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 询问证书信息
    echo -e "${YELLOW}请输入证书通用名称 (Common Name)${NC}"
    echo -e "${YELLOW}如不填写，将使用本机IP地址${NC}"
    read -p "通用名称: " COMMON_NAME
    
    # 如果未提供通用名称，使用IP地址
    if [ -z "$COMMON_NAME" ]; then
        COMMON_NAME="${PUBLIC_IPV4:-localhost}"
        echo -e "${YELLOW}使用IP地址作为通用名称: ${COMMON_NAME}${NC}"
    fi
    
    # 询问证书有效期
    echo -e "${YELLOW}请输入证书有效期 (天数)${NC}"
    echo -e "${YELLOW}如不填写，默认为365天${NC}"
    read -p "有效期 (天): " VALID_DAYS
    
    # 如果未提供有效期，使用默认值
    if [ -z "$VALID_DAYS" ]; then
        VALID_DAYS=365
        echo -e "${YELLOW}使用默认有效期: ${VALID_DAYS}天${NC}"
    fi
    
    # 创建证书目录
    mkdir -p /root/cert/self-signed
    
    # 定义证书文件路径
    local cert_name=$(echo $COMMON_NAME | tr -d '*.' | tr -d ':/' | sed 's/ /_/g')
    local cert_file="/root/cert/self-signed/${cert_name}.pem"
    local key_file="/root/cert/self-signed/${cert_name}.key"
    
    echo -e "${YELLOW}生成自签名证书...${NC}"
    
    # 生成私钥和证书
    openssl req -x509 -newkey rsa:4096 -sha256 -nodes \
        -keyout $key_file \
        -out $cert_file \
        -days $VALID_DAYS \
        -subj "/CN=${COMMON_NAME}" \
        -addext "subjectAltName=DNS:${COMMON_NAME},IP:${PUBLIC_IPV4:-127.0.0.1}"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}证书生成成功${NC}"
        
        # 设置适当的权限
        chmod 644 "$cert_file"
        chmod 600 "$key_file"
        
        # 更新主安装记录
        update_main_install_log "自签名证书:$COMMON_NAME"
        update_main_install_log "证书路径:$cert_file"
        update_main_install_log "私钥路径:$key_file"
        
        echo -e "${YELLOW}证书信息:${NC}"
        echo -e "  证书路径: $cert_file"
        echo -e "  私钥路径: $key_file"
        echo -e "${RED}注意: 此证书为自签名证书，浏览器将显示不安全警告${NC}"
    else
        echo -e "${RED}证书生成失败${NC}"
    fi
    
    read -p "按回车键继续..." temp
    certificate_management
}

# 创建必应通配符证书
create_bing_wildcard_cert() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}创建必应通配符证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}生成必应通配符证书 (*.bing.com)...${NC}"
    
    # 创建证书目录
    mkdir -p /root/cert/self-signed
    
    # 定义证书文件路径
    local cert_file="/root/cert/self-signed/bing_wildcard.pem"
    local key_file="/root/cert/self-signed/bing_wildcard.key"
    
    # 生成私钥和证书
    openssl req -x509 -newkey rsa:4096 -sha256 -nodes \
        -keyout $key_file \
        -out $cert_file \
        -days 365 \
        -subj "/CN=*.bing.com" \
        -addext "subjectAltName=DNS:*.bing.com,DNS:bing.com,DNS:www.bing.com"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}必应通配符证书生成成功${NC}"
        
        # 设置适当的权限
        chmod 644 "$cert_file"
        chmod 600 "$key_file"
        
        # 更新主安装记录
        update_main_install_log "自签名证书:*.bing.com"
        update_main_install_log "证书路径:$cert_file"
        update_main_install_log "私钥路径:$key_file"
        
        echo -e "${YELLOW}证书信息:${NC}"
        echo -e "  证书路径: $cert_file"
        echo -e "  私钥路径: $key_file"
        echo -e "${RED}注意: 此证书为自签名证书，浏览器将显示不安全警告${NC}"
    else
        echo -e "${RED}证书生成失败${NC}"
    fi
    
    read -p "按回车键继续..." temp
    certificate_management
}

# 创建自定义通配符证书
create_custom_wildcard_cert() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}创建自定义通配符证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    # 询问证书域名
    echo -e "${YELLOW}请输入域名 (例如: example.com)${NC}"
    read -p "域名: " DOMAIN
    
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}域名不能为空${NC}"
        read -p "按回车键继续..." temp
        certificate_management
        return
    fi
    
    # 询问证书有效期
    echo -e "${YELLOW}请输入证书有效期 (天数)${NC}"
    echo -e "${YELLOW}如不填写，默认为365天${NC}"
    read -p "有效期 (天): " VALID_DAYS
    
    # 如果未提供有效期，使用默认值
    if [ -z "$VALID_DAYS" ]; then
        VALID_DAYS=365
        echo -e "${YELLOW}使用默认有效期: ${VALID_DAYS}天${NC}"
    fi
    
    # 创建证书目录
    mkdir -p /root/cert/self-signed
    
    # 定义证书文件路径
    local domain_name=$(echo $DOMAIN | tr -d '*.' | sed 's/ /_/g')
    local cert_file="/root/cert/self-signed/${domain_name}_wildcard.pem"
    local key_file="/root/cert/self-signed/${domain_name}_wildcard.key"
    
    echo -e "${YELLOW}生成自定义通配符证书 (*.${DOMAIN})...${NC}"
    
    # 生成私钥和证书
    openssl req -x509 -newkey rsa:4096 -sha256 -nodes \
        -keyout $key_file \
        -out $cert_file \
        -days $VALID_DAYS \
        -subj "/CN=*.${DOMAIN}" \
        -addext "subjectAltName=DNS:*.${DOMAIN},DNS:${DOMAIN},DNS:www.${DOMAIN}"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}自定义通配符证书生成成功${NC}"
        
        # 设置适当的权限
        chmod 644 "$cert_file"
        chmod 600 "$key_file"
        
        # 更新主安装记录
        update_main_install_log "自签名证书:*.${DOMAIN}"
        update_main_install_log "证书路径:$cert_file"
        update_main_install_log "私钥路径:$key_file"
        
        echo -e "${YELLOW}证书信息:${NC}"
        echo -e "  证书路径: $cert_file"
        echo -e "  私钥路径: $key_file"
        echo -e "${RED}注意: 此证书为自签名证书，浏览器将显示不安全警告${NC}"
    else
        echo -e "${RED}证书生成失败${NC}"
    fi
    
    read -p "按回车键继续..." temp
    certificate_management
}

# 查看已生成的自签名证书
view_generated_certs() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}查看已生成的证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    local cert_dir="/root/cert/self-signed"
    local certs=()
    
    if [ ! -d "$cert_dir" ]; then
        echo -e "${RED}未找到证书目录${NC}"
        read -p "按回车键继续..." temp
        certificate_management
        return
    fi
    
    # 获取所有证书文件
    while IFS= read -r cert; do
        if [[ $cert == *.pem ]]; then
            cert_name=$(basename "$cert" .pem)
            certs+=("$cert_name")
        fi
    done < <(find "$cert_dir" -type f -name "*.pem")
    
    if [ ${#certs[@]} -eq 0 ]; then
        echo -e "${RED}未找到已生成的证书${NC}"
        read -p "按回车键继续..." temp
        certificate_management
        return
    fi
    
    echo -e "${YELLOW}已生成的证书:${NC}"
    
    for i in "${!certs[@]}"; do
        cert_file="$cert_dir/${certs[$i]}.pem"
        subject=$(openssl x509 -in "$cert_file" -noout -subject | sed 's/subject=//g')
        valid_until=$(openssl x509 -in "$cert_file" -noout -enddate | sed 's/notAfter=//g')
        
        echo -e "  $((i+1))) ${certs[$i]}"
        echo -e "      Subject: $subject"
        echo -e "      有效期至: $valid_until"
        echo -e ""
    done
    
    read -p "按回车键继续..." temp
    certificate_management
}

# 查看所有类型的证书
view_all_certificates() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}查看所有证书:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    local certs_found=false
    local main_log="/root/.sb_logs/main_install.log"
    
    echo -e "${YELLOW}证书列表:${NC}"
    echo -e "${BLUE}-------------------------------------------------${NC}"
    
    # 记录已显示证书的路径
    local shown_certs=()
    
    # 1. 清理日志中存在但文件不存在的记录
    if [ -f "$main_log" ]; then
        # 创建临时文件
        local temp_file=$(mktemp)
        
        # 读取日志并保留有效记录
        while IFS= read -r line; do
            if [[ $line == *"SSL证书:"* || $line == *"自签名证书:"* ]]; then
                domain=$(echo $line | cut -d':' -f2)
                # 暂时保存记录，稍后验证文件是否存在
                echo "$line" >> "$temp_file"
            elif [[ $line == *"证书路径:"* ]]; then
                path=$(echo $line | cut -d':' -f2-)
                if [ -f "$path" ]; then
                    # 证书文件存在，保留记录
                    echo "$line" >> "$temp_file"
                fi
            elif [[ $line == *"私钥路径:"* ]]; then
                path=$(echo $line | cut -d':' -f2-)
                if [ -f "$path" ]; then
                    # 密钥文件存在，保留记录
                    echo "$line" >> "$temp_file"
                fi
            else
                # 保留其他记录
                echo "$line" >> "$temp_file"
            fi
        done < "$main_log"
        
        # 用临时文件替换原日志
        mv "$temp_file" "$main_log"
    fi
    
    # 2. 显示自签名证书
    if [ -f "$main_log" ]; then
        local self_domains=()
        local self_paths=()
        local self_keys=()
        local domains_seen=()  # 跟踪已经见过的域名
        
        # 获取自签名证书信息
        while IFS= read -r line; do
            if [[ $line == *"自签名证书:"* ]]; then
                domain=$(echo $line | cut -d':' -f2)
                
                # 检查是否已经处理过这个域名
                local domain_seen=false
                for seen_domain in "${domains_seen[@]}"; do
                    if [[ "$seen_domain" == "$domain" ]]; then
                        domain_seen=true
                        break
                    fi
                done
                
                # 如果已经处理过此域名，跳过
                if [ "$domain_seen" = true ]; then
                    continue
                fi
                
                # 添加到已处理域名列表
                domains_seen+=("$domain")
                
                # 继续处理证书信息
                self_domains+=("$domain")
                
                # 获取证书路径 - 使用最新的记录（尾部匹配）
                cert_path=$(grep "证书路径.*$domain" "$main_log" | tail -1 | cut -d':' -f3-)
                self_paths+=("$cert_path")
                
                # 获取密钥路径 - 使用最新的记录（尾部匹配）
                key_path=$(grep "私钥路径.*$domain" "$main_log" | tail -1 | cut -d':' -f3-)
                if [ -z "$key_path" ]; then
                    key_path="${cert_path%.pem}.key"
                fi
                self_keys+=("$key_path")
            fi
        done < "$main_log"
        
        # 显示自签名证书
        if [ ${#self_domains[@]} -gt 0 ]; then
            local has_shown=false
            echo -e "${GREEN}【自签名/通配符证书】${NC}"
            
            for i in "${!self_domains[@]}"; do
                if [ -f "${self_paths[$i]}" ]; then
                    echo -e "  $((i+1))) ${self_domains[$i]}"
                    echo -e "      证书类型: 自签名证书"
                    echo -e "      证书路径: ${self_paths[$i]}"
                    
                    if [ -f "${self_keys[$i]}" ]; then
                        echo -e "      密钥路径: ${self_keys[$i]}"
                    else
                        echo -e "      密钥路径: ${RED}未找到文件${NC}"
                    fi
                    
                    # 提取有效期信息
                    if openssl x509 -in "${self_paths[$i]}" -noout &>/dev/null; then
                        valid_until=$(openssl x509 -in "${self_paths[$i]}" -noout -enddate 2>/dev/null | sed 's/notAfter=//g')
                        echo -e "      有效期至: $valid_until"
                    fi
                    echo -e ""
                    
                    has_shown=true
                    certs_found=true
                    shown_certs+=("${self_paths[$i]}")
                fi
            done
            
            if [ "$has_shown" = false ]; then
                echo -e "  ${YELLOW}未找到有效的自签名证书${NC}"
                echo -e ""
            fi
        fi
    fi
    
    # 3. 显示CA签名证书
    if [ -f "$main_log" ]; then
        local ca_domains=()
        local ca_paths=()
        local ca_keys=()
        local ca_domains_seen=()  # 跟踪已经见过的域名
        
        # 获取CA签名证书信息
        while IFS= read -r line; do
            if [[ $line == *"SSL证书:"* && $line != *"自签名证书:"* ]]; then
                domain=$(echo $line | cut -d':' -f2)
                
                # 检查是否已经处理过这个域名
                local domain_seen=false
                for seen_domain in "${ca_domains_seen[@]}"; do
                    if [[ "$seen_domain" == "$domain" ]]; then
                        domain_seen=true
                        break
                    fi
                done
                
                # 如果已经处理过此域名，跳过
                if [ "$domain_seen" = true ]; then
                    continue
                fi
                
                # 添加到已处理域名列表
                ca_domains_seen+=("$domain")
                
                # 继续处理证书信息
                ca_domains+=("$domain")
                
                # 获取证书路径 - 使用最新的记录（尾部匹配）
                cert_path=$(grep "证书路径.*$domain" "$main_log" | tail -1 | cut -d':' -f3-)
                ca_paths+=("$cert_path")
                
                # 获取密钥路径 - 使用最新的记录（尾部匹配）
                key_path=$(grep "私钥路径.*$domain" "$main_log" | tail -1 | cut -d':' -f3-)
                ca_keys+=("$key_path")
            fi
        done < "$main_log"
        
        # 显示CA签名证书
        if [ ${#ca_domains[@]} -gt 0 ]; then
            local has_shown=false
            echo -e "${GREEN}【Let's Encrypt CA签名证书】${NC}"
            
            for i in "${!ca_domains[@]}"; do
                if [ -f "${ca_paths[$i]}" ]; then
                    echo -e "  $((i+1))) ${ca_domains[$i]}"
                    echo -e "      证书类型: CA签名证书 (Let's Encrypt)"
                    echo -e "      证书路径: ${ca_paths[$i]}"
                    
                    if [ -f "${ca_keys[$i]}" ]; then
                        echo -e "      密钥路径: ${ca_keys[$i]}"
                    else
                        echo -e "      密钥路径: ${RED}未找到文件${NC}"
                    fi
                    
                    # 提取有效期信息
                    if openssl x509 -in "${ca_paths[$i]}" -noout &>/dev/null; then
                        valid_until=$(openssl x509 -in "${ca_paths[$i]}" -noout -enddate 2>/dev/null | sed 's/notAfter=//g')
                        echo -e "      有效期至: $valid_until"
                    fi
                    echo -e ""
                    
                    has_shown=true
                    certs_found=true
                    shown_certs+=("${ca_paths[$i]}")
                fi
            done
            
            if [ "$has_shown" = false ]; then
                echo -e "  ${YELLOW}未找到有效的CA签名证书${NC}"
                echo -e ""
            fi
        fi
    fi
    
    # 4. 在目录中查找其他证书
    for dir in "/root/cert" "/root/cert/self-signed" "/etc/ssl/certs"; do
        if [ -d "$dir" ]; then
            local other_certs=()
            
            # 查找证书文件
            while IFS= read -r file; do
                if [[ ! "$file" =~ /ca-certificates.crt$ && ! "$file" =~ /ca-bundle.crt$ ]]; then
                    # 检查是否已显示
                    local already_shown=false
                    for shown in "${shown_certs[@]}"; do
                        if [ "$shown" = "$file" ]; then
                            already_shown=true
                            break
                        fi
                    done
                    
                    if [ "$already_shown" = false ] && openssl x509 -in "$file" -noout &>/dev/null; then
                        other_certs+=("$file")
                    fi
                fi
            done < <(find "$dir" -maxdepth 1 -type f \( -name "*.pem" -o -name "*.crt" \) 2>/dev/null)
            
            # 显示其他证书
            if [ ${#other_certs[@]} -gt 0 ]; then
                echo -e "${GREEN}【在 $dir 中找到的其他证书】${NC}"
                
                for cert in "${other_certs[@]}"; do
                    echo -e "  - $(basename "$cert")"
                    subject=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null | sed 's/subject=//g')
                    valid_until=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | sed 's/notAfter=//g')
                    echo -e "      证书路径: $cert"
                    echo -e "      主题: $subject"
                    echo -e "      有效期至: $valid_until"
                    echo -e ""
                    
                    certs_found=true
                done
            fi
        fi
    done
    
    # 5. 如果没有找到任何证书
    if [ "$certs_found" = false ]; then
        echo -e "${RED}未找到任何证书${NC}"
    fi
    
    read -p "按回车键继续..." temp
    certificate_management
}

# 主函数-证书与DNS管理入口
show_cert_dns_menu() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN}证书与DNS管理:${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    echo -e "${YELLOW}请选择操作:${NC}"
    echo -e "  1) SSL证书管理 (HTTP验证)"
    echo -e "  2) DNS认证管理"
    echo -e "  0) 返回主菜单"
    
    read -p "选择 [0-2]: " CERT_DNS_OPTION
    
    case $CERT_DNS_OPTION in
        1) certificate_management ;;
        2) dns_management ;;
        0) return ;;
        *) 
            echo -e "${RED}无效选项，请重试${NC}"
            sleep 2
            show_cert_dns_menu
            ;;
    esac
    
    # 返回本菜单
    show_cert_dns_menu
}
