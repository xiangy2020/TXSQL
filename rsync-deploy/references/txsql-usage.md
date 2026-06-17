# TXSQL 项目 rsync-deploy 使用文档

本文档记录了 TXSQL 项目的代码同步与远端编译配置，直接可用，无需修改。

---

## 项目信息

| 项目 | 值 |
|------|-----|
| 本地代码目录 | `~/Documents/code/opentbase/TXSQL` |
| 远端服务器 | `9.135.12.62` |
| 远端用户 | `root` |
| SSH 端口 | `36000` |
| 远端代码目录 | `/data/TXSQL` |

---

## 日常使用命令

所有命令都在这个目录下执行：

```bash
cd ~/Documents/code/opentbase/TXSQL/rsync-deploy/scripts
```

### 同步代码 + 增量编译（日常最常用）

```bash
./deploy.sh
```

执行后会：
1. 把本地 TXSQL 代码 rsync 到远端 `/data/TXSQL`
2. 自动在远端执行 `make -C bld-release -j$(nproc)`，增量编译
3. 编译日志输出到远端 `/data/TXSQL/build.log`

### 预览将要同步哪些文件（不真正传输）

```bash
./deploy.sh --dry-run
```

适合在正式同步前确认改动范围。

### 监听模式（保存即自动同步）

```bash
# 先安装 fswatch（只需装一次）
brew install fswatch

# 启动监听
./deploy.sh --watch
```

文件一保存，自动触发同步 + 增量编译，适合频繁改动调试时使用。

---

## 首次编译 / CMake 配置变更时

增量编译 `make` 只适合源码改动。如果是**第一次编译**或**改了 CMakeLists.txt / build.sh 相关配置**，需要完整构建：

**第一步**：临时修改 `deploy.conf` 中的 `POST_SYNC_CMD`：

```bash
# 打开配置文件
open ~/Documents/code/opentbase/TXSQL/rsync-deploy/scripts/deploy.conf
```

把 `POST_SYNC_CMD` 改为：

```bash
POST_SYNC_CMD="./build.sh -t release"
```

**第二步**：执行同步

```bash
./deploy.sh
```

**第三步**：完整编译跑完后，把 `POST_SYNC_CMD` 改回增量编译：

```bash
POST_SYNC_CMD="make -C bld-release -j$(nproc) 2>&1 | tee build.log"
```

---

## 配置文件位置

```
TXSQL/rsync-deploy/scripts/deploy.conf
```

当前配置内容：

```bash
REMOTE_USER="root"
REMOTE_HOST="9.135.12.62"
REMOTE_PATH="/data/TXSQL"
SSH_PORT="36000"
LOCAL_PATH=".."
EXCLUDE_PATTERNS="bld-debug/, bld-release/, build.log, boost/"
POST_SYNC_CMD="make -C bld-release -j$(nproc) 2>&1 | tee build.log"
```

> ⚠️ `deploy.conf` 已加入 `.gitignore`，不会被提交到 git，服务器信息安全。

---

## 默认不同步的目录

以下目录不会被同步到远端（避免把本地构建产物覆盖远端）：

| 排除项 | 原因 |
|--------|------|
| `bld-debug/` | 本地 Debug 构建产物 |
| `bld-release/` | 本地 Release 构建产物 |
| `build.log` | 本地构建日志 |
| `boost/` | 第三方依赖，远端已有 |
| `.git/` | Git 元数据 |
| `.DS_Store` | macOS 系统文件 |

---

## 查看远端编译日志

同步并编译完成后，可以 SSH 到远端查看日志：

```bash
ssh -p 36000 root@9.135.12.62 "tail -100 /data/TXSQL/build.log"
```

或者实时跟踪：

```bash
ssh -p 36000 root@9.135.12.62 "tail -f /data/TXSQL/build.log"
```

---

## SSH 免密登录配置（推荐，避免每次输密码）

```bash
# 生成密钥（如果还没有）
ssh-keygen -t ed25519 -C "txsql-deploy"

# 推送公钥到远端（注意端口是 36000）
ssh-copy-id -p 36000 root@9.135.12.62
```

配置完成后，在 `deploy.conf` 中可以指定密钥路径（可选）：

```bash
SSH_KEY="~/.ssh/id_ed25519"
```

---

## 常见问题

**Q: 提示 `Permission denied (publickey)`**

```bash
ssh-copy-id -p 36000 -i ~/.ssh/id_ed25519.pub root@9.135.12.62
```

**Q: 同步成功但编译报错，怎么看详细日志？**

```bash
ssh -p 36000 root@9.135.12.62 "cat /data/TXSQL/build.log"
```

**Q: 只想同步，不想触发编译**

临时注释掉 `deploy.conf` 中的 `POST_SYNC_CMD`：

```bash
# POST_SYNC_CMD="make -C bld-release -j$(nproc) 2>&1 | tee build.log"
```

**Q: 编译机上 `bld-release` 目录不存在怎么办？**

说明还没有初始化过构建目录，需要先跑一次完整构建：

```bash
# 把 deploy.conf 里的 POST_SYNC_CMD 改为：
POST_SYNC_CMD="./build.sh -t release"
# 执行一次 ./deploy.sh，等完整构建完成后再改回增量编译
```
