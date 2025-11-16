#!/bin/bash

# WireGuard 监控脚本卸载程序

set -e

echo "========================================"
echo "WireGuard 监控脚本卸载程序"
echo "========================================"
echo

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo "错误: 此脚本需要 root 权限运行"
    echo "请使用: sudo $0"
    exit 1
fi

# 确认卸载
echo "此操作将卸载 WireGuard 监控系统，包括："
echo "  - 停止并禁用定时器"
echo "  - 删除监控脚本"
echo "  - 删除 systemd 服务文件"
echo "  - 删除日志文件"
echo
read -p "确定要继续吗? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消卸载"
    exit 0
fi

echo

# 停止并禁用服务
echo "停止并禁用服务..."
if systemctl is-active --quiet wg-monitor.timer; then
    systemctl stop wg-monitor.timer
    echo "✓ 已停止 wg-monitor.timer"
else
    echo "• wg-monitor.timer 未运行"
fi

if systemctl is-enabled --quiet wg-monitor.timer 2>/dev/null; then
    systemctl disable wg-monitor.timer
    echo "✓ 已禁用 wg-monitor.timer"
else
    echo "• wg-monitor.timer 未启用"
fi

if systemctl is-active --quiet wg-monitor.service; then
    systemctl stop wg-monitor.service
    echo "✓ 已停止 wg-monitor.service"
fi
echo

# 删除文件
echo "删除安装的文件..."

# 删除主脚本
if [ -f /usr/local/bin/wg-monitor.sh ]; then
    rm /usr/local/bin/wg-monitor.sh
    echo "✓ 已删除 /usr/local/bin/wg-monitor.sh"
else
    echo "• /usr/local/bin/wg-monitor.sh 不存在"
fi

# 删除 systemd 服务文件
if [ -f /etc/systemd/system/wg-monitor.service ]; then
    rm /etc/systemd/system/wg-monitor.service
    echo "✓ 已删除 /etc/systemd/system/wg-monitor.service"
else
    echo "• /etc/systemd/system/wg-monitor.service 不存在"
fi

# 删除 systemd 定时器文件
if [ -f /etc/systemd/system/wg-monitor.timer ]; then
    rm /etc/systemd/system/wg-monitor.timer
    echo "✓ 已删除 /etc/systemd/system/wg-monitor.timer"
else
    echo "• /etc/systemd/system/wg-monitor.timer 不存在"
fi

# 询问是否删除日志文件
echo
if [ -f /var/log/wg-monitor.log ]; then
    read -p "是否删除日志文件 /var/log/wg-monitor.log? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm /var/log/wg-monitor.log
        echo "✓ 已删除 /var/log/wg-monitor.log"
    else
        echo "• 保留日志文件 /var/log/wg-monitor.log"
    fi
else
    echo "• 日志文件不存在"
fi
echo

# 重载 systemd
echo "重载 systemd 配置..."
systemctl daemon-reload
echo "✓ systemd 配置已重载"
echo

echo "========================================"
echo "卸载完成！"
echo "========================================"
echo
echo "WireGuard 监控系统已完全卸载"
echo "WireGuard 本身未受影响，仍然正常运行"
echo
