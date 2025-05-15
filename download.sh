#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}服务器管理系统下载程序${NC}"
echo -e "${BLUE}=================================================${NC}"

# 检查curl命令是否可用
if ! command -v curl &> /dev/null; then
    echo -e "${RED}curl命令不可用，尝试安装...${NC}"
    if command -v apt &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y curl
    elif command -v yum &> /dev/null; then
        sudo yum install -y curl
    else
        echo -e "${RED}无法安装curl，请手动安装后重试${NC}"
        exit 1
    fi
fi

# 检测GitHub仓库URL
echo -e "${YELLOW}检测GitHub仓库URL...${NC}"
REPO_URL="https://raw.githubusercontent.com/pz2500210/abcd/main"
echo -e "${YELLOW}使用URL: ${REPO_URL}${NC}"

# 创建临时目录
TEMP_DIR="/tmp/server-setup-temp"
mkdir -p $TEMP_DIR
cd $TEMP_DIR

# 下载安装脚本
echo -e "${YELLOW}下载安装脚本...${NC}"
curl -s -o install.sh ${REPO_URL}/install.sh
chmod +x install.sh

# 检查文件是否下载成功
if [ ! -s install.sh ]; then
    echo -e "${RED}文件下载失败，尝试备用URL...${NC}"
    REPO_URL="https://raw.githubusercontent.com/pz2500210/abcd/refs/heads/main"    
    echo -e "${YELLOW}使用备用URL: ${REPO_URL}${NC}"
    curl -s -o install.sh ${REPO_URL}/install.sh
    chmod +x install.sh
    
    # 再次检查
    if [ ! -s install.sh ]; then
        echo -e "${RED}文件下载失败，请检查网络连接或仓库地址${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}安装脚本下载成功!${NC}"

# 切换到root并执行安装
echo -e "${YELLOW}准备切换到root用户并执行安装...${NC}"
# 获取install.sh的绝对路径
INSTALL_SCRIPT_PATH=$(readlink -f "$TEMP_DIR/install.sh")

if [ "$(id -u)" != "0" ]; then
    echo -e "${YELLOW}当前不是root用户，将尝试切换...${NC}"
    if command -v sudo &> /dev/null; then
        echo -e "${GREEN}使用sudo执行安装脚本...${NC}"
        sudo bash "$INSTALL_SCRIPT_PATH"
    else
        echo -e "${YELLOW}sudo命令不可用，尝试使用su切换...${NC}"
        echo -e "${YELLOW}请输入root密码:${NC}"
        su -c "bash \"$INSTALL_SCRIPT_PATH\""
    fi
else
    # 已经是root用户
    bash "$INSTALL_SCRIPT_PATH"
fi

# 清理临时文件
cd ~
rm -rf $TEMP_DIR

echo -e "${GREEN}下载和安装过程已完成${NC}"
