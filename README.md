# Docker Remote Setup

一个用于快速配置 Docker Remote API 的自动化脚本，支持 Debian、Ubuntu 和 CentOS 系统。

## 功能特性

- 自动检测和安装 Docker
- 自动配置 Docker Remote API
- 支持自定义端口
- 自动配置系统防火墙
- 配置失败自动回滚
- 支持主流 Linux 发行版：
  - Debian
  - Ubuntu
  - CentOS

## 快速开始

1. 下载脚本：
```bash
curl -sSL https://raw.githubusercontent.com/phpnbw/docker_remote_open/main/docker_remote_setup.sh -o docker_remote_setup.sh
```

2. 添加执行权限：
```bash
chmod +x docker_remote_setup.sh
```

3. 运行脚本：
```bash
# 使用默认端口(2375)
sudo ./docker_remote_setup.sh

# 或指定自定义端口
sudo ./docker_remote_setup.sh 2376
```

## 使用说明

### 参数说明

- 无参数：使用默认端口 2375
- 端口参数：指定自定义端口（1-65535）

### 示例

```bash
# 使用默认端口 2375
sudo ./docker_remote_setup.sh

# 使用自定义端口 2376
sudo ./docker_remote_setup.sh 2376
```

## 安全建议

Docker Remote API 默认没有认证机制，为了确保安全，建议：

1. 使用防火墙限制可访问的 IP
2. 配置 TLS 证书加密通信
3. 使用反向代理添加认证层
4. 考虑使用 VPN 或专用网络

## 故障排除

如果遇到问题，可以查看 Docker 服务日志：
```bash
journalctl -xu docker.service
```

## 贡献指南

欢迎提交 Issue 和 Pull Request 来帮助改进这个项目。

## 许可证

MIT License

## 免责声明

本脚本仅用于开发测试环境，在生产环境使用前请确保已经采取了适当的安全措施。作者不对因使用本脚本造成的任何损失负责。 
