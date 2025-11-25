# Inception 專案部署指南

## 🎉 當前狀態

**合規率:** 97% (38/39) - **HIGHLY COMPLIANT!**

唯一失敗的檢查是 `/etc/hosts` 域名設置,這是**環境相關**的問題,不影響專案核心功能。

## 環境差異對照表

| 項目 | 開發環境 (WSL2) | 學校 VM (Debian 12) |
|------|----------------|-------------------|
| 域名 | `ykaiyua.42.fr` | `ykai-yua.42.fr` (根據你的 login) |
| `/etc/hosts` | 需手動添加 | 需手動添加 |
| 資料目錄 | `/home/ykaiyua/data` | `/home/login/data` |
| Docker | Docker Desktop (WSL2) | 原生 Docker Engine |
| 網路 | WSL2 虛擬網路 | 原生 Linux 網路 |

## 部署到學校 VM 的步驟

### 1. 準備工作

```bash
# 在學校 VM 上,確認你的 login
whoami  # 假設輸出是 ykaiyua

# 更新 .env 檔案中的域名(如果需要)
# 如果學校要求使用 ykai-yua.42.fr 格式
cd ~/42-inception
nano srcs/.env
# 修改: DOMAIN_NAME=ykai-yua.42.fr
```

### 2. 設置 /etc/hosts

```bash
# 添加域名映射
sudo sh -c 'echo "127.0.0.1 ykaiyua.42.fr" >> /etc/hosts'

# 或者如果使用不同格式
sudo sh -c 'echo "127.0.0.1 ykai-yua.42.fr" >> /etc/hosts'

# 驗證
grep "42.fr" /etc/hosts
```

### 3. 部署專案

```bash
# 確保資料目錄存在
sudo mkdir -p /home/ykaiyua/data/{mariadb,wordpress}
sudo chown -R $USER:$USER /home/ykaiyua/data

# 構建並啟動
make all

# 等待 WordPress 安裝完成(約 30 秒)
sleep 30

# 運行評估
./eval.sh
```

### 4. 驗證部署

```bash
# 檢查容器狀態
docker ps

# 檢查 WordPress 是否可訪問
curl -k https://ykaiyua.42.fr

# 測試 WordPress 登入
# 在瀏覽器打開: https://ykaiyua.42.fr/wp-admin
# 用戶名: ykai_admin
# 密碼: (secrets/wp_admin_password.txt 中的內容)
```

## 當前環境 (WSL2) 的修復

如果你想在當前環境達到 100%,只需添加 `/etc/hosts` 條目:

```bash
sudo sh -c 'echo "127.0.0.1 ykaiyua.42.fr" >> /etc/hosts'
```

然後重新運行評估:
```bash
./eval.sh
```

## 需要微調的配置

### 如果學校 VM 使用不同的域名格式

1. **更新 `.env`:**
   ```bash
   DOMAIN_NAME=ykai-yua.42.fr  # 改成學校要求的格式
   ```

2. **更新 Nginx 配置:**
   ```bash
   # srcs/requirements/nginx/conf/nginx.conf
   server_name ykai-yua.42.fr;  # 改成對應的域名
   ```

3. **重新構建:**
   ```bash
   make clean
   sudo rm -rf /home/ykaiyua/data/*
   make all
   ```

### 如果資料目錄路徑不同

1. **更新 `.env`:**
   ```bash
   HOST_DATA_DIR=/path/to/data  # 改成實際路徑
   ```

2. **確保目錄存在:**
   ```bash
   sudo mkdir -p /path/to/data/{mariadb,wordpress}
   sudo chown -R $USER:$USER /path/to/data
   ```

## 故障排除

### WordPress 無法訪問

```bash
# 檢查容器日誌
docker logs wordpress
docker logs mariadb
docker logs nginx

# 檢查網路連接
docker exec wordpress ping -c 2 mariadb
docker exec wordpress mysql -h mariadb -u wp_user -p$(cat secrets/db_password.txt) -e "SELECT 1;"
```

### 容器不斷重啟

```bash
# 查看詳細日誌
docker logs --tail 100 <container_name>

# 檢查資料目錄權限
ls -la /home/ykaiyua/data/
```

### SSL 證書警告

這是正常的!專案使用自簽憑證,瀏覽器會顯示警告。點擊"繼續訪問"即可。

## 總結

你的專案已經 **97% 完成**,所有核心功能都正常運作!

**部署到學校 VM 時:**
1. ✅ 代碼不需要改動(如果域名格式相同)
2. ✅ 只需設置 `/etc/hosts`
3. ✅ 確保資料目錄權限正確
4. ✅ 運行 `make all`

**如果域名格式不同:**
1. 修改 `.env` 中的 `DOMAIN_NAME`
2. 修改 `nginx.conf` 中的 `server_name`
3. 重新構建

恭喜你完成了這個專案!🎊
