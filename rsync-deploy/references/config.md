# rsync-deploy 配置项详细说明

本文档说明 `deploy.conf` 中所有可用配置项的含义、默认值和使用示例。

---

## 必填配置

### `REMOTE_USER`
远端服务器的登录用户名。

```bash
REMOTE_USER="root"
REMOTE_USER="ubuntu"
REMOTE_USER="deploy"
```

---

### `REMOTE_HOST`
远端服务器的 IP 地址或域名。

```bash
REMOTE_HOST="146.56.247.114"
REMOTE_HOST="myserver.example.com"
```

---

### `REMOTE_PATH`
代码同步到远端服务器的目标目录（绝对路径）。目录不存在时 rsync 会自动创建。

```bash
REMOTE_PATH="/root/my-project"
REMOTE_PATH="/home/ubuntu/apps/backend"
REMOTE_PATH="/var/www/html/myapp"
```

---

### `LOCAL_PATH`
要同步的本地目录路径。支持相对路径（相对于 `deploy.sh` 所在位置）和绝对路径。

```bash
LOCAL_PATH=".."              # 上一级目录（即项目根目录，最常用）
LOCAL_PATH="../src"          # 只同步 src 子目录
LOCAL_PATH="/Users/me/code/myproject"  # 绝对路径
```

---

## 可选配置

### `SSH_PORT`
SSH 连接端口，默认为 `22`。

```bash
SSH_PORT="22"      # 默认，可省略
SSH_PORT="2222"    # 自定义端口
```

---

### `SSH_KEY`
SSH 私钥文件路径。留空时使用系统默认密钥（`~/.ssh/id_rsa` 或 `~/.ssh/id_ed25519`）。

```bash
# SSH_KEY=""                        # 使用默认密钥（留空或注释掉）
SSH_KEY="~/.ssh/id_ed25519"         # 指定 ed25519 密钥
SSH_KEY="~/.ssh/deploy_key"         # 指定专用部署密钥
```

> 推荐为部署专门生成一对密钥，与日常使用的密钥分离：
> ```bash
> ssh-keygen -t ed25519 -f ~/.ssh/deploy_key -C "deploy"
> ssh-copy-id -i ~/.ssh/deploy_key.pub root@your-server
> ```

---

### `EXCLUDE_PATTERNS`
自定义排除规则，多个规则用英文逗号分隔，支持通配符。

脚本已内置以下默认排除项（无需重复配置）：
- `.git/`、`__pycache__/`、`*.pyc`、`*.pyo`
- `.env`、`*.env`、`venv/`、`.venv/`
- `node_modules/`、`.DS_Store`、`*.log`
- `deploy.conf`

```bash
# 排除编译产物和临时目录
EXCLUDE_PATTERNS="dist/, build/, tmp/, *.sql"

# 排除测试文件
EXCLUDE_PATTERNS="tests/, *.test.js, coverage/"

# 排除大型数据文件
EXCLUDE_PATTERNS="data/, *.csv, *.xlsx"
```

---

### `POST_SYNC_CMD`
同步完成后在远端服务器自动执行的命令。命令在 `REMOTE_PATH` 目录下执行。

```bash
# 重启 systemd 服务
POST_SYNC_CMD="systemctl restart myapp"

# 安装依赖后重启
POST_SYNC_CMD="pip3 install -r requirements.txt && systemctl restart myapp"

# 执行启动脚本
POST_SYNC_CMD="bash run.sh"

# Flask 项目示例
POST_SYNC_CMD="source venv/bin/activate && pip3 install -r requirements.txt"

# Node.js 项目示例
POST_SYNC_CMD="npm install && pm2 restart myapp"
```

> ⚠️ 命令在远端以 `REMOTE_USER` 身份执行，请确保该用户有足够权限。

---

## 完整配置示例

### 示例 1：Python Flask 项目

```bash
REMOTE_USER="root"
REMOTE_HOST="146.56.247.114"
REMOTE_PATH="/root/flask-app"
LOCAL_PATH=".."
SSH_PORT="22"
EXCLUDE_PATTERNS="dist/, *.sqlite3"
POST_SYNC_CMD="source venv/bin/activate && pip3 install -r requirements.txt && systemctl restart flask-app"
```

### 示例 2：Node.js 项目

```bash
REMOTE_USER="ubuntu"
REMOTE_HOST="myserver.example.com"
REMOTE_PATH="/home/ubuntu/nodeapp"
LOCAL_PATH=".."
SSH_KEY="~/.ssh/deploy_key"
EXCLUDE_PATTERNS="dist/, coverage/"
POST_SYNC_CMD="npm install --production && pm2 restart nodeapp"
```

### 示例 3：静态网站

```bash
REMOTE_USER="www-data"
REMOTE_HOST="192.168.1.100"
REMOTE_PATH="/var/www/html/mysite"
LOCAL_PATH="../dist"
POST_SYNC_CMD="nginx -s reload"
```
