# Inception 專案技術詳解

## 1. Secrets 目錄 - 四個密碼的用途

### 📁 `/secrets/db_root_password.txt`
**內容:** `rootpassword123`

**用途:** MariaDB 資料庫的 **root 超級管理員密碼**

**使用位置:**
- 📍 `srcs/requirements/mariadb/tools/docker-entrypoint.sh` (第 29 行)
  ```bash
  ROOT_PASS=$(cat /run/secrets/db_root_password)
  # 用於設置 MariaDB root 用戶密碼
  ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASS}';
  ```

**作用:**
- 保護 MariaDB 資料庫的最高權限訪問
- 只有 root 用戶可以創建/刪除資料庫、管理用戶權限
- **安全性:** 這個密碼不應該被 WordPress 使用,只用於資料庫管理

---

### 📁 `/secrets/db_password.txt`
**內容:** `password123`

**用途:** WordPress 連接 MariaDB 的 **資料庫用戶密碼**

**使用位置:**
1. **MariaDB 端** - `mariadb/tools/docker-entrypoint.sh` (第 35 行)
   ```bash
   WP_DB_PASS=$(cat /run/secrets/db_password)
   # 創建 WordPress 資料庫用戶
   CREATE USER 'wp_user'@'%' IDENTIFIED BY '${WP_DB_PASS}';
   ```

2. **WordPress 端** - `wordpress/tools/docker-entrypoint.sh` (第 18 行)
   ```bash
   DB_PASS=$(cat /run/secrets/db_password)
   # 寫入 wp-config.php
   sed -i "s/password_here/${DB_PASS}/" wp-config.php
   ```

**作用:**
- WordPress 使用這個密碼連接到 MariaDB
- 對應的用戶名是 `wp_user`
- 只有訪問 `wordpress` 資料庫的權限,沒有 root 權限

**數據流:**
```
WordPress 容器 --[wp_user:password123]--> MariaDB 容器
```

---

### 📁 `/secrets/wp_admin_password.txt`
**內容:** `adminpassword123`

**用途:** WordPress 網站的 **管理員登入密碼**

**使用位置:**
- 📍 `wordpress/tools/docker-entrypoint.sh` (第 43 行)
  ```bash
  ADMIN_PASS=$(cat /run/secrets/wp_admin_password)
  # 安裝 WordPress 時創建管理員帳號
  wp core install --admin_user="ykai_admin" \
                  --admin_password="$ADMIN_PASS"
  ```

**作用:**
- 用於登入 WordPress 後台 (`https://ykai-yua.42.fr/wp-admin`)
- 管理員用戶名: `ykai_admin` (來自 `.env`)
- 擁有 WordPress 網站的完全控制權

**登入資訊:**
```
URL: https://ykai-yua.42.fr/wp-admin
用戶名: ykai_admin
密碼: adminpassword123
```

---

### 📁 `/secrets/wp_user_password.txt`
**內容:** `editor123`

**用途:** WordPress 網站的 **第二個用戶密碼**

**使用位置:**
- 📍 `wordpress/tools/docker-entrypoint.sh` (第 49 行)
  ```bash
  USER_PASS=$(cat /run/secrets/wp_user_password)
  # 創建第二個 WordPress 用戶
  wp user create "ykai_editor" "editor@ykai-yua.42.fr" \
                 --user_pass="$USER_PASS" --role=author
  ```

**作用:**
- 滿足專案要求:「至少 2 個 WordPress 用戶」
- 用戶名: `ykai_editor` (來自 `.env`)
- 角色: `author` (作者,可以發布文章但權限較低)

**登入資訊:**
```
URL: https://ykai-yua.42.fr/wp-admin
用戶名: ykai_editor
密碼: editor123
```

---

## 2. 三個 .sh 腳本的作用

### 🔧 `mariadb/tools/docker-entrypoint.sh`

**執行時機:** MariaDB 容器啟動時

**主要任務:**
1. **初始化資料庫** (如果是第一次運行)
   ```bash
   mariadb-install-db --user=mysql --datadir="/var/lib/mysql"
   ```

2. **配置網路監聽**
   ```bash
   # 讓 MariaDB 監聽所有網路接口,而不只是 localhost
   sed -i 's/bind-address\s*=.*/bind-address = 0.0.0.0/'
   ```

3. **創建 WordPress 資料庫和用戶** (僅第一次)
   ```bash
   CREATE DATABASE wordpress;
   CREATE USER 'wp_user'@'%' IDENTIFIED BY 'password123';
   GRANT ALL PRIVILEGES ON wordpress.* TO 'wp_user'@'%';
   ```

4. **設置 root 密碼**
   ```bash
   ALTER USER 'root'@'localhost' IDENTIFIED BY 'rootpassword123';
   ```

5. **啟動 MariaDB 服務**
   ```bash
   exec mysqld --user=mysql --bind-address=0.0.0.0
   ```

**關鍵特性:**
- 使用標誌文件 `.initialized` 避免重複初始化
- 只在第一次啟動時執行 SQL 命令

---

### 🔧 `wordpress/tools/docker-entrypoint.sh`

**執行時機:** WordPress 容器啟動時

**主要任務:**
1. **下載 WordPress** (如果目錄為空)
   ```bash
   wget https://wordpress.org/latest.tar.gz
   tar -xzf latest.tar.gz
   ```

2. **創建 wp-config.php** (配置資料庫連接)
   ```bash
   # 設置資料庫連接資訊
   DB_NAME: wordpress
   DB_USER: wp_user
   DB_PASSWORD: password123
   DB_HOST: mariadb:3306
   ```

3. **配置 PHP-FPM**
   ```bash
   # 讓 PHP-FPM 監聽 TCP 端口 9000
   sed -i 's/listen = .*/listen = 9000/'
   ```

4. **安裝 WordPress** (背景執行)
   ```bash
   wp core install --url="https://ykai-yua.42.fr" \
                   --admin_user="ykai_admin" \
                   --admin_password="adminpassword123"
   ```

5. **創建第二個用戶**
   ```bash
   wp user create "ykai_editor" "editor@ykai-yua.42.fr" \
                  --user_pass="editor123"
   ```

6. **啟動 PHP-FPM**
   ```bash
   exec php-fpm8.2 -F
   ```

**關鍵特性:**
- WordPress 安裝在背景進行,不阻塞 PHP-FPM 啟動
- 使用 `wp-cli` 自動化安裝和用戶創建

---

### 🔧 `nginx/tools/docker-entrypoint.sh`

**執行時機:** Nginx 容器啟動時

**主要任務:**
```bash
#!/bin/bash
set -e

exec "$@"
```

**作用:**
- 非常簡單,只是執行傳入的命令 (nginx)
- 使用 `exec` 確保 nginx 成為 PID 1 進程

**為什麼這麼簡單?**
- Nginx 不需要複雜的初始化
- 所有配置都在 `nginx.conf` 中
- SSL 證書已經預先生成

---

## 3. SSL 證書和私鑰

### 🔐 `server.crt` (SSL 證書)

**內容:** X.509 證書
```
Common Name (CN): ykai-yua.42.fr
Organization: ykai-yua
Valid From: 2025-10-09
Valid Until: 2026-10-09
```

**用途:**
- 向瀏覽器證明網站身份
- 包含公鑰,用於加密通信

**應用位置:**
📍 `nginx/conf/nginx.conf` (第 22 行)
```nginx
ssl_certificate /etc/nginx/ssl/server.crt;
```

---

### 🔑 `server.key` (私鑰)

**內容:** RSA 私鑰 (2048 位)

**用途:**
- 解密瀏覽器發送的加密數據
- 證明服務器擁有證書的所有權

**應用位置:**
📍 `nginx/conf/nginx.conf` (第 23 行)
```nginx
ssl_certificate_key /etc/nginx/ssl/server.key;
```

---

### 🔄 SSL/TLS 工作流程

```
1. 瀏覽器訪問 https://ykai-yua.42.fr
   ↓
2. Nginx 發送 server.crt 給瀏覽器
   ↓
3. 瀏覽器驗證證書 (會顯示警告,因為是自簽證書)
   ↓
4. 瀏覽器使用證書中的公鑰加密數據
   ↓
5. Nginx 使用 server.key 解密數據
   ↓
6. 建立 HTTPS 加密連接
```

---

## 4. 筆電 vs 學校 VM - 證書差異

### ❓ 這兩個文件在不同環境是一樣的嗎?

**答案:** 取決於證書的 Common Name (CN)

#### 當前證書分析:
```bash
# 查看證書資訊
openssl x509 -in server.crt -text -noout | grep "Subject:"
```

你的證書 CN 是 `ykai-yua.42.fr`,但你的 `.env` 使用 `ykai-yua.42.fr`

### 🔄 兩種情況:

#### 情況 1: 域名相同 → 證書可以共用
```
筆電: ykai-yua.42.fr
學校 VM: ykai-yua.42.fr
→ 證書不需要改變 ✅
```

#### 情況 2: 域名不同 → 需要重新生成證書
```
筆電: ykai-yua.42.fr
學校 VM: ykai-yua.42.fr (不同格式)
→ 需要重新生成證書 ⚠️
```

### 🛠️ 如何重新生成證書 (如果需要)

```bash
cd /home/ykai-yua/42-inception/srcs/requirements/nginx/conf/ssl

# 生成新的私鑰和證書
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout server.key \
  -out server.crt \
  -subj "/C=FR/ST=Paris/L=Paris/O=42/OU=42/CN=ykai-yua.42.fr"
  
# 注意: 把 CN=ykai-yua.42.fr 改成你實際使用的域名
```

### 📊 環境對照表

| 項目 | 開發筆電 | 學校 VM | 是否相同? |
|------|---------|---------|----------|
| `db_root_password.txt` | rootpassword123 | rootpassword123 | ✅ 相同 |
| `db_password.txt` | password123 | password123 | ✅ 相同 |
| `wp_admin_password.txt` | adminpassword123 | adminpassword123 | ✅ 相同 |
| `wp_user_password.txt` | editor123 | editor123 | ✅ 相同 |
| `server.crt` | CN=ykai-yua.42.fr | ? | ⚠️ 取決於域名 |
| `server.key` | RSA 2048 | ? | ⚠️ 取決於域名 |

### 💡 建議

**如果域名格式相同:**
- ✅ 所有文件都可以直接使用,不需要改變

**如果域名格式不同:**
- ✅ Secrets 文件保持不變
- ⚠️ 重新生成 SSL 證書和私鑰
- ⚠️ 更新 `.env` 中的 `DOMAIN_NAME`
- ⚠️ 更新 `nginx.conf` 中的 `server_name`

---

## 總結

### 密碼層級結構
```
系統層級:
├─ db_root_password.txt → MariaDB 超級管理員
└─ db_password.txt → WordPress 資料庫訪問

應用層級:
├─ wp_admin_password.txt → WordPress 管理員
└─ wp_user_password.txt → WordPress 普通用戶
```

### 安全性最佳實踐
1. ✅ 密碼存儲在 secrets/ 目錄,不在代碼中
2. ✅ 使用 Docker secrets 機制掛載
3. ✅ `.gitignore` 應該忽略 secrets/ 目錄
4. ✅ 每個服務使用不同的密碼
5. ⚠️ 生產環境應使用更強的密碼

### 證書注意事項
- 自簽證書會在瀏覽器顯示警告(正常現象)
- 證書的 CN 必須匹配域名
- 私鑰必須保密,不應該提交到 Git
