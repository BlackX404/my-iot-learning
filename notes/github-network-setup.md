# GitHub 网络配置全记录

> 2026-06-26 ~ 2026-06-27（核心排查，约 7 小时）
> 2026-07-02（hosts 清理 + SSH 优化，约 1 小时）
> 最终状态：✅ 网页稳定、Git SSH 满速、连接复用生效

---

## 问题背景

国内校园网/宽带环境下访问 GitHub：
- 网页偶尔能打开，多数时候打不开
- `ping github.com` 能通（300ms+），但浏览器无法加载
- `git clone/push` 极慢或超时

---

## 完整排查时间线

### 阶段 1：hosts 初步配置

**做了什么：**
```bash
sudo nano /etc/hosts
```

**添加的内容（后来发现 IP 已过时）：**
```
140.82.114.4    github.com
140.82.114.4    www.github.com
140.82.113.3    gist.github.com
185.199.108.153 assets-cdn.github.com
185.199.109.153 assets-cdn.github.com
185.199.110.153 assets-cdn.github.com
185.199.111.153 assets-cdn.github.com
185.199.108.154 github.githubassets.com
185.199.109.154 github.githubassets.com
185.199.110.154 github.githubassets.com
185.199.111.154 github.githubassets.com
140.82.112.21   central.github.com
185.199.108.133 raw.githubusercontent.com
185.199.109.133 raw.githubusercontent.com
185.199.110.133 raw.githubusercontent.com
185.199.111.133 raw.githubusercontent.com
```

**结果：** ❌ `nslookup` 显示 IP 正确，`ping` 通，但浏览器还是打不开

**学到的：**
- `nslookup` / `ping` 通 ≠ 网站能访问
- `ping` 走 ICMP，浏览器走 HTTPS（443 端口 TCP + TLS）
- 这是 GFW 的典型干扰：DNS 解析不封、ICMP 不封、TCP 443 端口能连，但 TLS 握手被干扰

---

### 阶段 2：Watt Toolkit 尝试

**做了什么：**
```bash
# 官网下载 Steam++_v3.1.0_linux_x64.tgz
cd ~/Downloads
tar -xzf Steam++_v3.1.0_linux_x64.tgz
cd Steam++_v3.1.0_linux_x64
./Steam++.sh
```

**遇到的错误：**
- `TrustRootCertificateFail` — NSS 证书数据库损坏
- `cannot open display: :1` — sudo 启动导致 X11 权限隔离
- `Resource temporarily unavailable` — api.steampp.net 自身被墙
- 图形界面认证窗口请输入密码后仍然失败

**尝试的修复（均失败）：**
```bash
# 重建 NSS 数据库
cd ~/.pki/nssdb
certutil -d sql:. -N --empty-password

# sudo 启动
sudo ./Steam++.sh

# 命令行模式
./Steam++ --cli
./Steam++ --no-gui
```

**结论：** ❌ Watt Toolkit v3.1.0 在 Ubuntu 24.04 下证书系统不兼容，放弃。

**学到的：**
- NSS 证书数据库位置：`~/.pki/nssdb`
- X11 图形界面权限隔离：普通用户启动的图形程序不能被 root 操作
- Linux 下遇到图形界面故障时，先试命令行模式

---

### 阶段 3：TLS 降级 ← 关键突破

**诊断过程：**
```bash
# 发现 TCP 443 端口能通
nc -zv 140.82.114.4 443
# Connection succeeded!

# HTTP 80 能 301 重定向
curl -I http://github.com --connect-timeout 10
# HTTP/1.1 301 Moved Permanently

# 但 HTTPS 卡在 TLS 握手
curl -v https://github.com --connect-timeout 10 2>&1 | head -30
# TLSv1.3 Client Hello → Server Hello → Encrypted Extensions → 卡住 → SSL connection timeout
```

**关键发现：TLS 1.3 被 GFW 深度包检测干扰，TLS 1.2 能过。**

**解决方案：**
```bash
# 强制使用 TLS 1.2
git config --global http.sslVersion tlsv1.2

# 同时降级 HTTP 版本（避免 HTTP/2 被干扰）
git config --global http.version HTTP/1.1
```

**验证：**
```bash
curl -I https://github.com --tlsv1.2 --connect-timeout 10
# HTTP/2 200  ← 通了！
```

**结果：** ✅ 浏览器能打开 GitHub 网页，但不稳定，需要刷新

---

### 阶段 4：ghproxy 尝试与清理

**错误操作：**
```bash
git config --global url."https://ghproxy.com/https://github.com".insteadOf https://github.com
```

**结果：** ❌ ghproxy.com 在 2026 年 6 月已不可用（连接超时），导致后续所有 Git 操作都失败

**清理：**
```bash
git config --global --unset url.https://ghproxy.com/https://github.com.insteadof
```

**学到的：**
- 镜像站不稳定，配置前先测试
- 配置了 `insteadOf` 后所有 GitHub URL 都会被改写，排查问题时先 `git config --global --list | grep url`

---

### 阶段 5：SSH 方案 ← 最终解决方案

**生成密钥：**
```bash
ssh-keygen -t ed25519 -C "qazsedcftgb2007@163.com"
# 公钥：ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKE7jmEw+Xgh9zEf3oCTHfD1NOlWb1JpYMKeXxBm8DAw
```

**测试端口连通性：**
```bash
nc -zv github.com 22          # Connection succeeded!
nc -zv ssh.github.com 443     # Connection succeeded!
```

**绑定公钥到 GitHub：**
- Settings → SSH and GPG keys → New SSH key → 粘贴公钥

**验证：**
```bash
ssh -T git@github.com
# Hi BlackX404! You've successfully authenticated, but GitHub does not provide shell access.
```

**配置 Git 走 SSH：**
```bash
git config --global url."git@github.com:".insteadOf https://github.com/
```

**结果：** ✅ Git clone/push 正常，速度可接受

---

### 阶段 6：账户问题

**遇到的问题：**
- 旧账号 BleakX404 被强制 2FA，电脑浏览器无法登录（需要 Passkey/Authenticator App）
- 手机 GitHub App 可以登录（已保存 session）
- 尝试找回密码、账户恢复均失败

**最终操作：**
- 手机注销旧账号
- 重新注册新账号（用户名 BlackX404，注意大写 B）
- 重新绑定 SSH 公钥

**学到的：**
- GitHub 2023 年后强制 2FA，新账户或用密码登录会触发
- 手机 App 已登录的 session 不受影响
- 注销账户需要手机上操作：Settings → Account → Delete account

---

### 阶段 7：hosts 清理 ← 今天的优化

**问题：** 2026-07-02 测试发现：
- hosts 里绑的旧 IP `140.82.114.4` ping 平均 **348ms**
- DNS 自然解析到的新 IP `20.205.243.166`（Azure 机房）ping 平均 **198ms**，快了 43%
- hosts 里 `github.githubassets.com` 指向 `185.199.*.154`，实际 DNS 已迁移到 `185.199.*.215`，导致 CSS/JS 加载失败
- `assets-cdn.github.com` 可能已被 GitHub 废弃（DNS 无返回）

**hosts 文件里的过期 IP vs 当前 DNS 解析：**

| 域名 | hosts 旧 IP | DNS 当前 IP | 状态 |
|---|---|---|---|
| github.com | 140.82.114.4 (348ms) | 20.205.243.166 (198ms) | 旧 IP 慢 43% |
| github.githubassets.com | 185.199.*.154 | 185.199.*.215 | 过期，CSS 加载失败 |
| raw.githubusercontent.com | 185.199.*.133 | 185.199.*.133 | 碰巧一致 |

**修复：**
```bash
# 备份原文件
sudo cp /etc/hosts /etc/hosts.bak

# 删除所有 GitHub 相关行
sudo sed -i '/github/d' /etc/hosts

# 还有一行注释残留
sudo sed -i '/# The GitHub IP/d' /etc/hosts

# 刷新 DNS 缓存
sudo resolvectl flush-caches
```

**验证：**
```bash
# DNS 解析正确
nslookup github.com 114.114.114.114
# Address: 20.205.243.166

# 网页正常加载
curl -I https://github.com --connect-timeout 10
# HTTP/2 200
```

**结论：** ✅ hosts 方案本质是创可贴——IP 会变、CDN 会迁移。DNS 自然解析才是长期方案。如果以后 DNS 被污染再考虑 hosts，否则不要手动绑 IP。

---

### 阶段 8：SSH 连接复用优化

**配置 `~/.ssh/config`：**
```
Host github.com
    HostName github.com
    User git
    ControlMaster auto
    ControlPath ~/.ssh/ssh_mux_%h_%p_%r
    ControlPersist 600
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
```

**效果：** 第一次 `git push` 正常握手，10 分钟内后续操作几乎零延迟。

---

## 最终生效的配置

### Git 全局配置
```bash
git config --global --list | grep -E 'ssl|http|url'
# http.sslversion=tlsv1.2
# http.version=HTTP/1.1
# url.git@github.com:.insteadof=https://github.com/
```

### SSH 配置
- `~/.ssh/id_ed25519` + `~/.ssh/id_ed25519.pub`
- 公钥已绑定到 GitHub 账号 BlackX404
- `~/.ssh/config` 已配置连接复用

### 远程仓库
```bash
git remote -v
# origin  git@github.com:BlackX404/my-iot-learning.git (fetch)
# origin  git@github.com:BlackX404/my-iot-learning.git (push)
```

---

## 排查方法论总结

| 层级 | 诊断命令 | 能发现的问题 |
|---|---|---|
| DNS | `nslookup github.com` | DNS 污染/劫持 |
| IP | `ping github.com` | IP 层连通性 |
| TCP 端口 | `nc -zv github.com 443` | 端口是否被封 |
| TLS 握手 | `curl -v https://github.com` | TLS 版本/SNI 干扰 |
| HTTP | `curl -I https://github.com` | HTTP 层是否正常 |
| SSH | `ssh -T git@github.com` | SSH 认证是否正常 |

**排查原则：** 从底层往上层，每一层通了才测下一层，不要跳过。

---

## 如果以后又出问题

### 快速诊断三步
```bash
# 1. TCP 通不通？
nc -zv github.com 22 && nc -zv github.com 443

# 2. SSH 通不通？
ssh -T git@github.com

# 3. Git clone 通不通？
git clone git@github.com:BlackX404/my-iot-learning.git /tmp/test-clone && rm -rf /tmp/test-clone
```

### 快速修复
```bash
# 检查 Git 配置是否被覆盖
git config --global --list

# 检查 hosts 是否过时
nslookup github.com 114.114.114.114

# 检查 SSH 密钥是否还在
ssh -T git@github.com
```

---

> 7 小时死磕 GitHub 网络，看似是在"浪费时间"，实际上你走完了：
> DNS 解析 → hosts 配置 → TCP 端口诊断 → TLS 握手分析 → GFW 干扰识别 →
> SSH 协议切换 → 证书数据库修复 → 图形界面权限排查 → 账户恢复流程
> 
> 这是一次完整的 Linux 网络工程实战，比任何教程都深刻。
