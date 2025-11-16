#!/bin/bash

# WireGuard 监控脚本安装程序

set -e

echo "========================================"
echo "WireGuard 监控脚本安装程序"
echo "========================================"
echo

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo "错误: 此脚本需要 root 权限运行"
    echo "请使用: sudo $0"
    exit 1
fi

# 检查必要的命令是否存在
echo "检查依赖..."
for cmd in wg wg-quick systemctl ping; do
    if ! command -v $cmd &>/dev/null; then
        echo "错误: 未找到命令 $cmd"
        exit 1
    fi
done
echo "✓ 依赖检查通过"
echo

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 安装主脚本
echo "安装监控脚本..."
cp "$SCRIPT_DIR/wg-monitor.sh" /usr/local/bin/wg-monitor.sh
chmod +x /usr/local/bin/wg-monitor.sh
echo "✓ 已安装到 /usr/local/bin/wg-monitor.sh"
echo

# 安装 systemd 服务文件
echo "安装 systemd 服务..."
cp "$SCRIPT_DIR/wg-monitor.service" /etc/systemd/system/wg-monitor.service
cp "$SCRIPT_DIR/wg-monitor.timer" /etc/systemd/system/wg-monitor.timer
echo "✓ 已安装 systemd 服务文件"
echo

# 创建日志文件
echo "创建日志文件..."
touch /var/log/wg-monitor.log
chmod 644 /var/log/wg-monitor.log
echo "✓ 日志文件: /var/log/wg-monitor.log"
echo

# 重载 systemd
echo "重载 systemd 配置..."
systemctl daemon-reload
echo "✓ systemd 配置已重载"
echo

echo "========================================"
echo "安装完成！"
echo "========================================"
echo
echo "接下来的步骤:"
echo
echo "1. 编辑配置文件，设置你的服务端 IP:"
echo "   nano /usr/local/bin/wg-monitor.sh"
echo "   # 修改 SERVER_IP 变量为你的阿里云服务端 WireGuard 内网 IP"
echo
echo "2. 测试脚本是否正常工作:"
echo "   sudo /usr/local/bin/wg-monitor.sh"
echo
echo "3. 启用并启动定时器:"
echo "   sudo systemctl enable wg-monitor.timer"
echo "   sudo systemctl start wg-monitor.timer"
echo
echo "4. 查看定时器状态:"
echo "   sudo systemctl status wg-monitor.timer"
echo
echo "5. 查看监控日志:"
echo "   sudo tail -f /var/log/wg-monitor.log"
echo
echo "6. 查看服务日志:"
echo "   sudo journalctl -u wg-monitor.service -f"
echo
