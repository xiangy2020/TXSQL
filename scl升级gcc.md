使用 SCL（Software Collections）仓库安装高版本 GCC 是 CentOS 7 上最安全、最便捷的方式，它允许你安装多个版本的 GCC 且不会破坏系统原有的编译器环境。
以下是完整的安装与配置步骤：
1. 安装 SCL 仓库与工具
首先，你需要安装 SCL 的官方仓库以及相关的构建工具：
sudo yum install -y centos-release-scl scl-utils-build
2. 配置国内镜像源（关键步骤）
由于 CentOS 7 已经停止官方维护，默认的 SCL 仓库域名可能无法解析（会报 Could not resolve host: mirrorlist.centos.org 错误）。建议将其替换为阿里云或腾讯云镜像源：
# 进入源文件目录
cd /etc/yum.repos.d/

# 1. 修改 CentOS-SCLo-scl.repo
sudo sed -i 's|^mirrorlist=|#mirrorlist=|g' CentOS-SCLo-scl.repo
sudo sed -i 's|^baseurl=.*|baseurl=https://mirrors.aliyun.com/centos/7/sclo/x86_64/sclo/|g' CentOS-SCLo-scl.repo

# 2. 修改 CentOS-SCLo-scl-rh.repo
sudo sed -i 's|^mirrorlist=|#mirrorlist=|g' CentOS-SCLo-scl-rh.repo
sudo sed -i 's|^baseurl=.*|baseurl=https://mirrors.aliyun.com/centos/7/sclo/x86_64/rh/|g' CentOS-SCLo-scl-rh.repo

# 3. 清理并更新缓存
sudo yum clean all && sudo yum makecache
3. 安装指定版本的 GCC
SCL 提供了多个版本的 GCC，你可以根据需求选择（以 GCC 9 为例）：

# 安装 GCC 9 及其 C++ 编译器
sudo yum install -y devtoolset-9-gcc devtoolset-9-gcc-c++
(注：如果需要其他版本，只需将 9 替换为 7, 8, 10, 11 等数字即可)
安装完成后，可以通过 ls /opt/rh/ 验证，能看到 devtoolset-9 目录即表示安装成功。
4. 启用高版本 GCC
SCL 安装的 GCC 默认不会覆盖系统自带的 GCC，你需要手动激活它。
临时启用（仅当前终端会话有效）：

scl enable devtoolset-9 
执行后，输入 gcc --version 即可看到版本已切换为 9.x。关闭终端或重启后会自动恢复为系统默认的 4.8.5 版本。
永久启用（推荐）：
如果你希望每次登录终端都默认使用高版本 GCC，可以将其写入环境变量配置文件：

# 方式一：写入 ~/._profile
echo "source /opt/rh/devtoolset-9/enable" >> ~/._profile
source ~/._profile

# 或者方式二：
echo "scl enable devtoolset-9 " >> ~/.rc
source ~/.rc
配置完成后，再次验证 gcc --version，确认版本已成功升级即可。