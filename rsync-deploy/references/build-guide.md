# TXSQL 编译指南

本文档记录 TXSQL（基于 MySQL 8.0）在 Linux 编译机上的完整构建流程，包括前置依赖、已知问题修复、编译、打包、安装、启动和测试。

---

## 环境信息

| 项目 | 值 |
|------|-----|
| 编译机 OS | TencentOS Server 3.2（tlinux3） |
| 内核版本 | `5.4.241-1-tlinux4-0025.1` x86_64 |
| 编译器 | GCC 8.5.0（Tencent 8.5.0-28） |
| 构建系统 | CMake + Make |
| 代码目录 | `/data/TXSQL` |
| 默认安装目录 | `/usr/local/mysql` |
| 构建产物目录 | `bld-release`（release）/ `bld-debug`（debug） |

---

## 一、前置依赖

### 1.1 系统依赖包

```bash
# TencentOS 3.2（实际编译环境）
# GCC 8.5.0 已预装，无需额外安装编译器
yum install -y \
  cmake make \
  curl libcurl-devel \
  zlib zlib-devel \
  ncurses ncurses-devel \
  libtirpc-devel \
  bison \
  git \
  perl \
  pkg-config \
  patchelf \
  rpcgen
```

### 1.2 GCC 版本确认

```bash
gcc --version
# 实际输出：
# gcc (GCC) 8.5.0 20210514 (Tencent 8.5.0-28)
```

当前编译机使用 GCC 8.5.0，**需要额外链接 `libstdc++fs`**，详见第二章。

### 1.3 CMake 版本确认

```bash
cmake --version
# 要求 CMake >= 3.13
# 如果系统自带版本过低，优先尝试 cmake3
cmake3 --version
```

如果 cmake3 不存在，手动安装：

```bash
yum install -y cmake3
```

### 1.4 Boost 依赖

项目已内置 Boost 1.77.0，位于 `boost/boost_1_77_0`，**无需单独安装**。

`build.sh` 默认使用项目内置 Boost：

```bash
# 默认 boost 路径（相对于项目根目录）
boost_dir="$pwd/"   # 脚本内部会拼接为 $boost_dir/boost/
```

如需指定外部 Boost：

```bash
./build.sh -t release -b /usr/local/boost_1_77_0
```

### 1.5 SSL 依赖

项目使用 bundled SSL（内置 OpenSSL），**无需系统安装 OpenSSL**。

CMake 参数中已配置：

```cmake
-DWITH_SSL=bundled
-DWITH_SSL_PATH=/usr/local/ssl
```

### 1.6 curl 依赖

curl 使用系统版本：

```bash
yum install -y curl libcurl-devel
```

---

## 二、GCC 8 std::filesystem 链接问题

### 2.1 问题描述

在 GCC 8 下编译时，链接 `mysqld` 阶段会出现以下报错：

```
undefined reference to 'std::filesystem::__cxx11::path::_M_split_cmpts()'
undefined reference to 'std::filesystem::__cxx11::path::has_root_directory() const'
undefined reference to 'std::filesystem::__cxx11::path::has_filename() const'
collect2: error: ld returned 1 exit status
```

### 2.2 根因

GCC 8 中 `std::filesystem` 的实现库 `libstdc++fs` 是**独立的**，不会自动链接。从 GCC 9 开始才内置到 `libstdc++` 中，无需额外链接。

### 2.3 修复方案（已落地）

在 `build.sh` 的 **normal compile 分支**（`if [ $optimize -eq 0 ]` 块）的 `$cmk ..` 调用末尾，已加入以下两行：

```bash
    -DCMAKE_SHARED_LINKER_FLAGS="-lstdc++fs" \
    -DCMAKE_CXX_STANDARD_LIBRARIES="-lstdc++fs"
```

完整位置在 `build.sh` 约第 330 行附近，紧接在 `-DCOMPILATION_COMMENT_SERVER="20221230"` 之后：

```bash
    -DCOMPILATION_COMMENT_SERVER="20221230" \
    -DCMAKE_SHARED_LINKER_FLAGS="-lstdc++fs" \
    -DCMAKE_CXX_STANDARD_LIBRARIES="-lstdc++fs"
```

`-DCMAKE_CXX_STANDARD_LIBRARIES` 会把 `-lstdc++fs` 注入到**所有 C++ 目标**的链接命令中；`-DCMAKE_SHARED_LINKER_FLAGS` 则覆盖共享库的链接标志，两者配合确保 GCC 8 下不遗漏任何目标。

### 2.4 验证修复是否生效

```bash
grep "lstdc++fs" build.log
```

### 2.5 ⚠️ 重要踩坑记录：GCC 12 环境禁止加此参数

> 如果编译机升级到 GCC 9+（如 GCC 12），**必须移除** `-DCMAKE_CXX_STANDARD_LIBRARIES="-lstdc++fs"` 和 `-DCMAKE_SHARED_LINKER_FLAGS="-lstdc++fs"`。
>
> GCC 12 下 `libstdc++fs` 已合并进 `libstdc++`，重复链接会导致符号冲突，生成的内部工具（`comp_err`、`comp_client_err` 等）在运行时 **Segmentation fault**，表现为 `GenError`、`GenClientError` 等 target 崩溃。
>
> **判断标准**：`gcc --version` 输出版本 >= 9，就不能加这两个参数。

---

## 三、编译

### 3.1 标准 Release 编译（最常用）

```bash
cd /data/TXSQL
./build.sh -t release
```

等价于：
- `cmake_build_type = RelWithDebInfo`（带调试符号的优化版本）
- `WITH_DEBUG = 0`
- `WITH_JEMALLOC = 1`（Linux 下默认开启）

编译产物在 `bld-release/` 目录下，日志输出到 `build.log`。

### 3.2 Debug 编译

```bash
./build.sh -t debug
```

等价于：
- `cmake_build_type = Debug`
- `WITH_DEBUG = 1`

编译产物在 `bld-debug/` 目录下。

### 3.3 常用编译参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| `-t` | 构建类型：`debug` 或 `release` | `-t release` |
| `-d` | 安装目标目录 | `-d /usr/local/mysql` |
| `-b` | 指定外部 Boost 目录 | `-b /usr/local/boost_1_77_0` |
| `-s` | server_suffix 标识 | `-s txsql` |
| `-B 0` | 只跑 CMake，不执行 make | `-B 0` |
| `--asan` | 开启 AddressSanitizer | `--asan` |
| `--rocksdb` | 开启 RocksDB 存储引擎 | `--rocksdb` |

### 3.4 只重新 CMake（不重新编译）

```bash
./build.sh -t release -B 0
```

适合修改了 CMake 配置后，只想重新生成构建文件，不触发 make。

### 3.5 增量编译（源码改动后）

如果只改了 C++ 源码，不需要重新跑 CMake，直接增量编译：

```bash
make -C bld-release -j$(nproc) 2>&1 | tee build.log
```

### 3.6 清理重建

如果遇到奇怪的编译错误，建议清理后重建：

```bash
rm -rf bld-release
./build.sh -t release
```

---

## 四、打包

### 4.1 生成安装包（make install 方式）

编译完成后，直接安装到目标目录：

```bash
cd bld-release
make install
```

默认安装到 `/usr/local/mysql`（由 `-DCMAKE_INSTALL_PREFIX` 控制）。

### 4.2 指定安装目录

```bash
./build.sh -t release -d /data/mysql-install
cd bld-release
make install
```

### 4.3 打 tar 包（用于分发）

安装完成后，把安装目录打包：

```bash
cd /usr/local
tar -czf txsql-8.0-$(date +%Y%m%d).tar.gz mysql/
```

---

## 五、安装

### 5.1 初始化数据目录

```bash
# 创建 mysql 用户（如果没有）
useradd -r -s /sbin/nologin mysql

# 创建数据目录
mkdir -p /usr/local/mysql/data
chown -R mysql:mysql /usr/local/mysql/

# 初始化
/usr/local/mysql/bin/mysqld \
  --initialize \
  --user=mysql \
  --basedir=/usr/local/mysql \
  --datadir=/usr/local/mysql/data
```

> ⚠️ 初始化完成后，终端会输出一个**临时 root 密码**，注意保存。

### 5.2 配置文件

创建 `/usr/local/mysql/my.cnf`：

```ini
[mysqld]
basedir=/usr/local/mysql
datadir=/usr/local/mysql/data
socket=/tmp/mysql.sock
port=3306
user=mysql
log-error=/usr/local/mysql/data/mysqld.err
pid-file=/usr/local/mysql/data/mysqld.pid

# 字符集
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# 性能
innodb_buffer_pool_size=1G
max_connections=1000
```

### 5.3 配置系统服务（systemd）

```bash
# 复制 service 文件
cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysql

# 或者创建 systemd service
cat > /etc/systemd/system/mysqld.service << 'EOF'
[Unit]
Description=MySQL Server (TXSQL)
After=network.target

[Service]
Type=forking
User=mysql
Group=mysql
ExecStart=/usr/local/mysql/bin/mysqld_safe --defaults-file=/usr/local/mysql/my.cnf
ExecStop=/usr/local/mysql/bin/mysqladmin -u root shutdown
TimeoutSec=300

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mysqld
```

---

## 六、启动

### 6.1 直接启动

```bash
# 方式一：mysqld_safe（推荐，有守护进程）
/usr/local/mysql/bin/mysqld_safe \
  --defaults-file=/usr/local/mysql/my.cnf \
  --user=mysql &

# 方式二：直接启动 mysqld
/usr/local/mysql/bin/mysqld \
  --defaults-file=/usr/local/mysql/my.cnf \
  --user=mysql &
```

### 6.2 通过 systemd 启动

```bash
systemctl start mysqld
systemctl status mysqld
```

### 6.3 确认启动成功

```bash
# 查看进程
ps aux | grep mysqld

# 查看端口
ss -tlnp | grep 3306

# 查看错误日志
tail -50 /usr/local/mysql/data/mysqld.err
```

### 6.4 首次登录修改密码

```bash
# 使用初始化时生成的临时密码登录
/usr/local/mysql/bin/mysql -u root -p

# 登录后立即修改密码
ALTER USER 'root'@'localhost' IDENTIFIED BY 'your_new_password';
FLUSH PRIVILEGES;
```

### 6.5 停止服务

```bash
/usr/local/mysql/bin/mysqladmin -u root -p shutdown
# 或
systemctl stop mysqld
```

---

## 七、测试

### 7.1 基本连通性测试

```bash
/usr/local/mysql/bin/mysql -u root -p -e "SELECT VERSION();"
```

期望输出包含 `txsql` 后缀，例如：

```
+-----------+
| VERSION() |
+-----------+
| 8.0.xx-txsql |
+-----------+
```

### 7.2 确认 server_suffix

```bash
/usr/local/mysql/bin/mysql -u root -p -e "SELECT @@version_comment;"
```

### 7.3 存储引擎检查

```bash
/usr/local/mysql/bin/mysql -u root -p -e "SHOW ENGINES;"
```

确认以下引擎存在且状态为 `YES` 或 `DEFAULT`：

| 引擎 | 期望状态 |
|------|---------|
| InnoDB | DEFAULT |
| MyISAM | YES |
| ARCHIVE | YES |
| BLACKHOLE | YES |
| FEDERATED | YES |
| PERFORMANCE_SCHEMA | YES |

### 7.4 基本 SQL 功能测试

```bash
/usr/local/mysql/bin/mysql -u root -p << 'EOF'
CREATE DATABASE test_db;
USE test_db;
CREATE TABLE t1 (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(100));
INSERT INTO t1 (name) VALUES ('hello'), ('world');
SELECT * FROM t1;
DROP DATABASE test_db;
EOF
```

### 7.5 单元测试（可选，需要 gmock）

如果编译时开启了 gmock（`-g` 参数），可以运行单元测试：

```bash
cd bld-release
make test
# 或者
ctest --output-on-failure
```

### 7.6 查看编译版本信息

```bash
/usr/local/mysql/bin/mysqld --version
```

---

## 附录：常见编译报错速查

| 报错关键词 | 原因 | 解决方法 |
|-----------|------|---------|
| `undefined reference to 'std::filesystem::...'` | GCC < 9 缺少 `libstdc++fs` 链接（当前 GCC 8.5.0 需要加 `-lstdc++fs` 参数） | 在 `build.sh` 中加 `-DCMAKE_SHARED_LINKER_FLAGS="-lstdc++fs"` 参数 |
| `Boost directory ... not exists` | Boost 路径不对 | 检查 `boost/` 目录是否存在，或用 `-b` 指定路径 |
| `cmake: command not found` | 没有 cmake | 安装 `cmake3`，脚本会自动优先使用 `cmake3` |
| `ld returned 1 exit status` | 链接失败 | 查看 `build.log` 中具体的 `undefined reference` 信息 |
| `Permission denied` | 权限问题 | 确认 `build.sh` 有执行权限：`chmod +x build.sh` |
| `fatal error: tirpc/rpc/rpc.h` | 缺少 libtirpc | `yum install -y libtirpc-devel` |
| `file INSTALL cannot find ".../LICENSE"` | 项目根目录缺少 `LICENSE` 文件 | 创建软链接：`ln -s /data/TXSQL/TXSQL_LICENSE /data/TXSQL/LICENSE` |
