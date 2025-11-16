#!/bin/bash

# WireGuard 自动重连监控脚本
# 用于监控 WireGuard 连接状态，断线时自动重启

# ========== 配置区域 ==========
# WireGuard 接口名称
WG_INTERFACE="wg0"

# 服务端 WireGuard 内网 IP (用于 ping 测试)
# 请修改为你的阿里云服务端的 WireGuard 内网 IP
SERVER_IP="10.0.0.1"

# ping 超时时间（秒）
PING_TIMEOUT=5

# ping 重试次数
PING_COUNT=3

# 最大握手时间（秒），超过这个时间没有握手则认为连接断开
# WireGuard 默认每 2 分钟握手一次，设置为 180 秒（3 分钟）
MAX_HANDSHAKE_AGE=180

# 日志文件路径
LOG_FILE="/var/log/wg-monitor.log"

# 日志文件最大行数（超过此行数将自动清理，只保留最新的记录）
MAX_LOG_LINES=500

# 是否启用详细日志
VERBOSE=true
# ==============================

# 日志函数
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" | tee -a "$LOG_FILE"
}

verbose_log() {
    if [ "$VERBOSE" = true ]; then
        log "$1"
    fi
}

# 清理日志文件，只保留最新的记录
cleanup_log() {
    if [ -f "$LOG_FILE" ]; then
        local line_count=$(wc -l < "$LOG_FILE")
        if [ "$line_count" -gt "$MAX_LOG_LINES" ]; then
            # 保留最后 300 行（约为最大行数的 60%）
            local keep_lines=$((MAX_LOG_LINES * 60 / 100))
            tail -n "$keep_lines" "$LOG_FILE" > "$LOG_FILE.tmp"
            mv "$LOG_FILE.tmp" "$LOG_FILE"
            verbose_log "日志文件已清理，保留最新 $keep_lines 行记录"
        fi
    fi
}

# 检查是否以 root 权限运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log "ERROR: 此脚本需要 root 权限运行"
        exit 1
    fi
}

# 检查 WireGuard 接口是否存在
check_interface_exists() {
    if ! ip link show "$WG_INTERFACE" &>/dev/null; then
        log "ERROR: WireGuard 接口 $WG_INTERFACE 不存在"
        return 1
    fi
    return 0
}

# 检查接口是否 UP
check_interface_up() {
    if ! ip link show "$WG_INTERFACE" | grep -q "state UP"; then
        log "WARNING: WireGuard 接口 $WG_INTERFACE 状态不是 UP"
        return 1
    fi
    return 0
}

# 检查最后一次握手时间
check_handshake() {
    verbose_log "检查 WireGuard 握手时间..."

    # 获取最后一次握手的时间戳
    local handshake=$(wg show "$WG_INTERFACE" latest-handshakes | awk '{print $2}')

    if [ -z "$handshake" ] || [ "$handshake" = "0" ]; then
        log "WARNING: 未检测到握手记录"
        return 1
    fi

    local current_time=$(date +%s)
    local handshake_age=$((current_time - handshake))

    verbose_log "最后握手时间: ${handshake_age} 秒前"

    if [ "$handshake_age" -gt "$MAX_HANDSHAKE_AGE" ]; then
        log "WARNING: 握手时间过旧 (${handshake_age}秒 > ${MAX_HANDSHAKE_AGE}秒)"
        return 1
    fi

    verbose_log "握手时间正常"
    return 0
}

# Ping 测试连接
check_ping() {
    verbose_log "Ping 测试服务端 $SERVER_IP ..."

    if ping -c "$PING_COUNT" -W "$PING_TIMEOUT" -I "$WG_INTERFACE" "$SERVER_IP" &>/dev/null; then
        verbose_log "Ping 测试成功"
        return 0
    else
        log "WARNING: Ping 测试失败，无法连接到服务端 $SERVER_IP"
        return 1
    fi
}

# 重启 WireGuard
restart_wireguard() {
    log "开始重启 WireGuard 接口 $WG_INTERFACE ..."

    # 尝试使用 systemd 方式重启
    if systemctl is-active --quiet "wg-quick@$WG_INTERFACE"; then
        log "使用 systemd 重启 WireGuard..."
        systemctl restart "wg-quick@$WG_INTERFACE"
        local exit_code=$?
    else
        # 使用 wg-quick 命令重启
        log "使用 wg-quick 重启 WireGuard..."
        wg-quick down "$WG_INTERFACE" 2>&1 | tee -a "$LOG_FILE"
        sleep 2
        wg-quick up "$WG_INTERFACE" 2>&1 | tee -a "$LOG_FILE"
        local exit_code=$?
    fi

    if [ $exit_code -eq 0 ]; then
        log "WireGuard 重启成功"
        # 等待接口完全启动
        sleep 3
        return 0
    else
        log "ERROR: WireGuard 重启失败，退出码: $exit_code"
        return 1
    fi
}

# 主监控逻辑
main() {
    check_root

    # 清理旧日志
    cleanup_log

    verbose_log "========== 开始 WireGuard 连接检查 =========="

    # 检查接口是否存在
    if ! check_interface_exists; then
        log "ERROR: 接口不存在，跳过检查"
        exit 1
    fi

    # 检查接口状态
    local interface_ok=true
    if ! check_interface_up; then
        interface_ok=false
    fi

    # 检查握手时间
    local handshake_ok=true
    if ! check_handshake; then
        handshake_ok=false
    fi

    # Ping 测试
    local ping_ok=true
    if ! check_ping; then
        ping_ok=false
    fi

    # 判断是否需要重启
    if [ "$interface_ok" = false ] || [ "$handshake_ok" = false ] || [ "$ping_ok" = false ]; then
        log "检测到连接问题，准备重启 WireGuard"
        restart_wireguard

        # 重启后再次检查
        sleep 5
        if check_ping; then
            log "重启后连接恢复正常"
        else
            log "ERROR: 重启后连接仍然异常，请手动检查"
        fi
    else
        verbose_log "WireGuard 连接正常"
    fi

    verbose_log "========== WireGuard 检查完成 =========="
}

# 执行主函数
main
