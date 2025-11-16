# WireGuard 自动重连监控脚本

简单实用的 WireGuard 客户端监控脚本，当检测到连接断开时自动重启 WireGuard 接口。

## 功能特性

- ✅ 定期检查 WireGuard 连接状态（接口状态、握手时间、网络连通性）
- ✅ 连接断开时自动重启 WireGuard
- ✅ 详细的日志记录
- ✅ 自动清理日志，只保留最近 500 行记录
- ✅ 使用 systemd timer 自动运行（每 2 分钟检查一次）

## 文件说明

- `wg-monitor.sh` - 主监控脚本
- `wg-monitor.service` - systemd 服务单元文件
- `wg-monitor.timer` - systemd 定时器文件
- `install.sh` - 自动安装脚本
- `uninstall.sh` - 自动卸载脚本

## 快速开始

### 1. 安装

```bash
# 赋予安装脚本执行权限
chmod +x install.sh

# 运行安装脚本
sudo ./install.sh
```

### 2. 配置

编辑监控脚本，修改服务端 IP：

```bash
sudo nano /usr/local/bin/wg-monitor.sh
```

**必须修改的配置项：**

```bash
SERVER_IP="10.0.0.1"  # 改为你的阿里云服务端 WireGuard 内网 IP
```

例如，如果你的服务端 WireGuard 配置是：
```ini
[Interface]
Address = 10.0.0.1/24
```

那么 `SERVER_IP` 就应该设置为 `10.0.0.1`

**可选配置项：**

```bash
WG_INTERFACE="wg0"           # WireGuard 接口名称
PING_TIMEOUT=5               # Ping 超时时间（秒）
PING_COUNT=3                 # Ping 重试次数
MAX_HANDSHAKE_AGE=180        # 最大握手间隔时间（秒）
MAX_LOG_LINES=500            # 日志文件最大行数
VERBOSE=true                 # 是否启用详细日志
```

### 3. 测试

手动运行脚本测试：

```bash
sudo /usr/local/bin/wg-monitor.sh
```

查看输出，确认脚本运行正常。

### 4. 启用自动监控

```bash
# 启用定时器（开机自启）
sudo systemctl enable wg-monitor.timer

# 启动定时器
sudo systemctl start wg-monitor.timer

# 查看状态
sudo systemctl status wg-monitor.timer
```

## 使用说明

### 查看监控日志

```bash
# 实时查看日志
sudo tail -f /var/log/wg-monitor.log

# 查看最近 50 行
sudo tail -50 /var/log/wg-monitor.log

# 查看 systemd 日志
sudo journalctl -u wg-monitor.service -f
```

### 查看定时器状态

```bash
# 查看定时器运行状态
sudo systemctl status wg-monitor.timer

# 查看下次运行时间
sudo systemctl list-timers wg-monitor.timer
```

### 手动触发检查

```bash
sudo systemctl start wg-monitor.service
```

### 修改检查频率

编辑 timer 文件：

```bash
sudo nano /etc/systemd/system/wg-monitor.timer
```

修改 `OnUnitActiveSec` 值（默认 2 分钟）：

```ini
[Timer]
OnUnitActiveSec=2min    # 改为你想要的时间，如 1min, 5min 等
```

重新加载配置并重启：

```bash
sudo systemctl daemon-reload
sudo systemctl restart wg-monitor.timer
```

### 停止监控

```bash
# 停止定时器
sudo systemctl stop wg-monitor.timer

# 禁用定时器（取消开机自启）
sudo systemctl disable wg-monitor.timer
```

## 日志管理

脚本会自动管理日志文件：
- 当日志超过 500 行时，自动清理，只保留最新 300 行
- 无需手动清理或安装额外的日志工具
- 可以通过修改脚本中的 `MAX_LOG_LINES` 参数调整保留的行数

## 卸载

### 使用卸载脚本（推荐）

```bash
# 赋予执行权限
chmod +x uninstall.sh

# 运行卸载脚本
sudo ./uninstall.sh
```

卸载脚本会：
- 停止并禁用 systemd timer 和 service
- 删除所有安装的文件
- 询问是否删除日志文件（可选择保留）
- 重载 systemd 配置

### 手动卸载

如果没有 `uninstall.sh` 脚本，可以手动卸载：

```bash
# 停止并禁用服务
sudo systemctl stop wg-monitor.timer
sudo systemctl disable wg-monitor.timer

# 删除文件
sudo rm /usr/local/bin/wg-monitor.sh
sudo rm /etc/systemd/system/wg-monitor.service
sudo rm /etc/systemd/system/wg-monitor.timer
sudo rm /var/log/wg-monitor.log

# 重载 systemd
sudo systemctl daemon-reload
```

## 工作原理

脚本会执行以下检查：

1. **接口状态检查** - 检查 WireGuard 接口是否处于 UP 状态
2. **握手时间检查** - 检查最后一次握手是否在 3 分钟内（WireGuard 默认每 2 分钟握手）
3. **Ping 连通性测试** - 通过 WireGuard 隧道 ping 服务端 IP

如果任何一项检查失败，脚本会：
1. 记录问题到日志
2. 尝试重启 WireGuard 接口（wg-quick down/up）
3. 等待几秒后再次检查连接状态
4. 记录重启结果

## 故障排查

### 脚本报错 "接口不存在"

检查你的 WireGuard 接口名称：

```bash
wg show
```

如果不是 `wg0`，需要修改脚本中的 `WG_INTERFACE` 变量。

### Ping 测试一直失败

1. 确认服务端 IP 配置正确
2. 检查服务端是否允许 ping（ICMP）
3. 查看 WireGuard 配置中的 AllowedIPs 是否包含服务端 IP

```bash
sudo wg show wg0
```

### 重启后仍然无法连接

可能的原因：
- WireGuard 配置文件有问题
- 服务端防火墙阻止了连接
- 网络环境问题

手动检查：

```bash
# 查看 WireGuard 状态
sudo wg show

# 查看接口状态
ip addr show wg0

# 手动测试连接
ping -c 3 <服务端IP>

# 手动重启 WireGuard
sudo wg-quick down wg0
sudo wg-quick up wg0
```

## 日志示例

**正常运行：**
```
[2025-01-16 10:00:01] ========== 开始 WireGuard 连接检查 ==========
[2025-01-16 10:00:01] 检查 WireGuard 握手时间...
[2025-01-16 10:00:01] 最后握手时间: 45 秒前
[2025-01-16 10:00:01] 握手时间正常
[2025-01-16 10:00:01] Ping 测试服务端 10.0.0.1 ...
[2025-01-16 10:00:02] Ping 测试成功
[2025-01-16 10:00:02] WireGuard 连接正常
[2025-01-16 10:00:02] ========== WireGuard 检查完成 ==========
```

**检测到问题并重启：**
```
[2025-01-16 10:02:01] ========== 开始 WireGuard 连接检查 ==========
[2025-01-16 10:02:01] 检查 WireGuard 握手时间...
[2025-01-16 10:02:01] WARNING: 握手时间过旧 (250秒 > 180秒)
[2025-01-16 10:02:01] Ping 测试服务端 10.0.0.1 ...
[2025-01-16 10:02:06] WARNING: Ping 测试失败，无法连接到服务端 10.0.0.1
[2025-01-16 10:02:06] 检测到连接问题，准备重启 WireGuard
[2025-01-16 10:02:06] 开始重启 WireGuard 接口 wg0 ...
[2025-01-16 10:02:06] 使用 systemd 重启 WireGuard...
[2025-01-16 10:02:08] WireGuard 重启成功
[2025-01-16 10:02:14] 重启后连接恢复正常
[2025-01-16 10:02:14] ========== WireGuard 检查完成 ==========
```

## 注意事项

1. 脚本需要 root 权限运行
2. 确保服务端配置正确并且在运行
3. 日志会自动清理，无需手动管理
4. 建议先手动测试脚本正常工作后再启用自动监控
5. 定时器默认每 2 分钟检查一次，可根据需要调整

## 许可证

MIT License
