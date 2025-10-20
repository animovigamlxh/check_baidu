#!/bin/bash

# 网络检测和服务控制脚本
# 功能: 检测baidu.com连通性，根据结果启动或停止服务

# 脚本路径
SCRIPT_PATH="/usr/local/bin/network_check.sh"
LOG_PATH="/var/log/network_check.log"

# 安装函数
install_cron() {
    local interval=$1
    
    # 默认每60分钟执行一次
    if [ -z "$interval" ]; then
        interval=60
    fi
    
    # 验证输入是否为数字
    if ! [[ "$interval" =~ ^[0-9]+$ ]]; then
        echo "错误: 间隔时间必须是数字（分钟）"
        exit 1
    fi
    
    # 验证间隔时间范围
    if [ "$interval" -lt 1 ] || [ "$interval" -gt 1440 ]; then
        echo "错误: 间隔时间必须在 1-1440 分钟之间"
        exit 1
    fi
    
    echo "正在安装定时任务（每 $interval 分钟执行一次）..."
    
    # 保存脚本到系统目录
    cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash

# 网络检测和服务控制脚本
LOG_PATH="/var/log/network_check.log"
TIMEOUT=5
PING_COUNT=3

echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始检测网络连接..."

# Ping baidu.com，设置超时和次数
if ping -c $PING_COUNT -W $TIMEOUT baidu.com > /dev/null 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Ping成功，网络正常"
    echo "启动服务..."
    
    # 启动 xrayr
    if systemctl start xrayr 2>/dev/null; then
        echo "xrayr 服务已启动"
    else
        echo "xrayr 服务启动失败或不存在"
    fi
    
    # 启动 v2bx
    if systemctl start v2bx 2>/dev/null; then
        echo "v2bx 服务已启动"
    else
        echo "v2bx 服务启动失败或不存在"
    fi
    
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Ping超时，网络异常"
    echo "停止服务..."
    
    # 停止 xrayr
    if systemctl stop xrayr 2>/dev/null; then
        echo "xrayr 服务已停止"
    else
        echo "xrayr 服务停止失败或不存在"
    fi
    
    # 停止 v2bx
    if systemctl stop v2bx 2>/dev/null; then
        echo "v2bx 服务已停止"
    else
        echo "v2bx 服务停止失败或不存在"
    fi
    
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - 脚本执行完成"
echo "-----------------------------------"
EOF

    chmod +x "$SCRIPT_PATH"
    echo "脚本已安装到 $SCRIPT_PATH"
    
    # 生成 cron 表达式
    if [ "$interval" -eq 60 ]; then
        # 每小时执行
        cron_expr="0 * * * *"
    elif [ "$interval" -lt 60 ]; then
        # 每X分钟执行
        cron_expr="*/$interval * * * *"
    else
        # 每X小时执行
        hours=$((interval / 60))
        cron_expr="0 */$hours * * *"
    fi
    
    # 删除旧的定时任务（如果存在）
    crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | crontab -
    
    # 添加新的定时任务
    (crontab -l 2>/dev/null; echo "$cron_expr $SCRIPT_PATH >> $LOG_PATH 2>&1") | crontab -
    
    echo "定时任务已安装："
    echo "  间隔: 每 $interval 分钟"
    echo "  Cron表达式: $cron_expr"
    echo "  日志位置: $LOG_PATH"
    echo ""
    echo "提示: 可以使用 'crontab -l' 查看定时任务"
    echo ""
    exit 0
}

# 卸载函数
uninstall_cron() {
    echo "正在卸载定时任务..."
    
    # 删除定时任务
    crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | crontab -
    echo "定时任务已删除"
    
    # 删除脚本文件
    if [ -f "$SCRIPT_PATH" ]; then
        rm -f "$SCRIPT_PATH"
        echo "脚本文件已删除"
    fi
    
    echo "卸载完成！"
    exit 0
}

# 检查命令行参数
case "$1" in
    install)
        install_cron "$2"
        ;;
    uninstall)
        uninstall_cron
        ;;
    --help|-h)
        echo "用法: bash <(curl -fsSL https://raw.githubusercontent.com/your-repo/network_check.sh) install [分钟]"
        echo ""
        echo "选项:"
        echo "  install [分钟]  安装脚本和定时任务"
        echo "                  分钟: 执行间隔时间，范围 1-1440（默认: 60）"
        echo "  uninstall       卸载定时任务"
        echo "  --help, -h      显示此帮助信息"
        echo ""
        echo "示例:"
        echo "  bash <(curl -fsSL https://raw.githubusercontent.com/.../network_check.sh) install"
        echo "  bash <(curl -fsSL https://raw.githubusercontent.com/.../network_check.sh) install 30"
        echo "  bash <(curl -fsSL https://raw.githubusercontent.com/.../network_check.sh) install 5"
        echo ""
        echo "卸载:"
        echo "  bash <(curl -fsSL https://raw.githubusercontent.com/.../network_check.sh) uninstall"
        echo ""
        echo "查看日志:"
        echo "  tail -f /var/log/network_check.log"
        exit 0
        ;;
    *)
        echo "错误: 必须指定 install 或 uninstall"
        echo "使用 '--help' 查看帮助"
        exit 1
        ;;
esac
