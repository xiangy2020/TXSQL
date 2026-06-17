---
name: rsync-deploy
description: 本地代码快速同步到远端服务器的部署工具 Skill。基于 rsync + SSH，无需 CI/CD，一条命令完成本地→远端代码同步。支持一次性同步、dry-run 预览、watch 监听模式（保存即同步）、同步后自动执行远端命令。当用户需要将本地代码部署到远端服务器、同步文件到测试/生产环境、或希望实现"保存即部署"的开发体验时，请使用此 Skill。触发词：部署代码、同步到服务器、rsync、deploy、上传代码、推送到远端、本地同步远端。
---

# rsync-deploy - 本地代码快速同步到远端服务器

轻量级部署工具，基于 `rsync + SSH`，无需 CI/CD，适合个人开发者将本地代码快速同步到远端服务器。

## 目录结构

```
rsync-deploy/
├── SKILL.md                    # 本文件，Skill 入口和使用指南
├── scripts/
│   └── deploy.sh               # 核心部署脚本（可执行）
└── references/
    ├── config.md               # 配置项详细说明
    └── deploy.conf.example     # 配置文件模板
```

---

## 快速开始

### 第一步：初始化配置

```bash
# 进入 rsync-deploy 目录
cd rsync-deploy

# 从模板创建本地配置（deploy.conf 不会提交到 git）
cp references/deploy.conf.example scripts/deploy.conf
```

编辑 `scripts/deploy.conf`，填写服务器信息：

```bash
REMOTE_USER="root"
REMOTE_HOST="your-server-ip"
REMOTE_PATH="/root/your-project"
LOCAL_PATH=".."        # 同步上一级目录（即项目根目录）
```

> 详细配置说明请参考 `references/config.md`

### 第二步：配置 SSH 密钥（推荐）

使用密钥认证，避免每次输入密码：

```bash
# 生成密钥对（如果还没有）
ssh-keygen -t ed25519 -C "deploy"

# 将公钥推送到远端服务器
ssh-copy-id root@your-server-ip
```

### 第三步：给脚本加执行权限

```bash
chmod +x scripts/deploy.sh
```

### 第四步：执行部署

```bash
# 一次性同步
./scripts/deploy.sh

# 模拟运行（预览将要同步的文件，不实际传输）
./scripts/deploy.sh --dry-run

# 监听模式（文件变化时自动同步，需要 fswatch）
./scripts/deploy.sh --watch

# 查看帮助
./scripts/deploy.sh --help
```

---

## 安全规范

> ⚠️ `deploy.conf` 包含服务器 IP 和认证信息，**绝对不能提交到 git 仓库**。

确保项目根目录的 `.gitignore` 包含：

```
deploy.conf
```

`deploy.conf.example` 是配置模板（不含真实信息），可以安全提交到 git。

---

## 默认排除的文件

以下内容默认不会同步到远端：

| 排除项 | 说明 |
|--------|------|
| `.git/` | Git 仓库元数据 |
| `__pycache__/`、`*.pyc` | Python 缓存 |
| `.env`、`*.env` | 环境变量（敏感信息） |
| `venv/`、`.venv/` | Python 虚拟环境 |
| `node_modules/` | Node.js 依赖 |
| `.DS_Store` | macOS 系统文件 |
| `*.log` | 日志文件 |
| `deploy.conf` | 本地部署配置 |

自定义排除规则请在 `deploy.conf` 中配置 `EXCLUDE_PATTERNS`。

---

## 监听模式依赖安装

```bash
# macOS
brew install fswatch

# Ubuntu / Debian
apt-get install inotify-tools

# CentOS / RHEL
yum install inotify-tools
```

---

## 常见问题

**Q: 提示 `Permission denied (publickey)`**

```bash
# 重新推送公钥到服务器
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@your-server-ip
```

**Q: 同步后自动重启服务**

在 `deploy.conf` 中配置 `POST_SYNC_CMD`：

```bash
POST_SYNC_CMD="systemctl restart myapp"
# 或
POST_SYNC_CMD="cd /root/myapp && bash run.sh"
```

**Q: 只同步某个子目录**

修改 `deploy.conf` 中的 `LOCAL_PATH`：

```bash
LOCAL_PATH="../src"   # 只同步 src 目录
```

**Q: 服务器 SSH 端口不是 22**

```bash
SSH_PORT="2222"
```
