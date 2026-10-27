# Hướng dẫn dùng hci_scan.sh

## 🚀 Nhanh gọn (3 dòng)

```bash
# 1. Copy script vào VM
scp hci_scan.sh hunghv@192.168.200.151:/tmp/

# 2. SSH vào VM
ssh hunghv@192.168.200.151

# 3. Chạy
bash /tmp/hci_scan.sh

# Kết quả lưu ở /tmp/hci_scan_<hostname>_<timestamp>/
```

---

## 📋 Script check những gì?

| Phần | Nội dung | Check gì |
|------|---------|----------|
| **1. Patches** | Bản vá, kernel | Update chưa cài, security updates |
| **2. Accounts** | Tài khoản | UID 0, mật khẩu rỗng, groups sudo/docker |
| **3. SSH** | SSH config | PermitRootLogin, SSH keys, authorized_keys |
| **4. Sudo** | Sudo rules | NOPASSWD, env_keep LD_PRELOAD |
| **5. Firewall** | Mạng | UFW, iptables, ports mở (Redis, MySQL, Mongo...) |
| **6. Cron** | Scheduled tasks | Cron lạ, curl/wget trong cron |
| **7. Process** | Process đang chạy | Process từ /tmp/dev/shm, top CPU/RAM |
| **8. Files** | File ẩn/SUID | File trong /tmp, SUID files, file ẩn |
| **9. Changed files** | File mới 7 ngày | /etc, /root, /usr/local |
| **10. Auth** | SSH/sudo logs | Brute-force, root login, sudo commands |
| **11. Bash history** | Lệnh chạy trước | curl, wget, ssh, nc, python -c |
| **12. Persistence** | Backdoor | .bashrc, ld.so.preload, rc.local, systemd units |
| **13. Known_hosts** | SSH remote | Máy khác mà VM này SSH tới |
| **14. Kernel** | LKM rootkit | Modules lạ |
| **15. /etc/hosts** | DNS hijack | /etc/hosts, /etc/resolv.conf |

---

## 📊 Kết quả output

Sau khi chạy, sẽ có **15 file** trong `/tmp/hci_scan_<hostname>_<timestamp>/`:

```
1_patches.txt          # Bản vá chưa cài
2_accounts.txt         # Tài khoản, quyền
3_ssh.txt              # SSH config, keys
4_sudo.txt             # Sudo rules
5_firewall.txt         # Firewall, ports
6_cron.txt             # Cron jobs
7_process.txt          # Processes
8_files.txt            # File ẩn, SUID
9_changed_files.txt    # File mới 7 ngày
10_auth.txt            # Login logs
11_bash_history.txt    # Bash history
12_persistence.txt     # Backdoor
13_known_hosts.txt     # SSH remote
14_kernel.txt          # Kernel modules
15_hosts.txt           # /etc/hosts, DNS
```

---

## ⚠️ Điểm nghi vấn (Scoring)

Script tính **SCORE** (điểm nghi vấn):
- **SCORE 0-4**: ✅ Bình thường
- **SCORE 5-9**: ⚠️ Nghi vấn trung (check kỹ)
- **SCORE >= 10**: 🚨 Nghi vấn cao (cần kiểm tra ngay)

Các tình huống +điểm:
- UID 0 ngoài root: +5
- Mật khẩu rỗng: +10
- PermitRootLogin=yes: +3
- Root SSH login: +2
- Brute-force SSH: +3
- Process từ /tmp: +5
- Cron lạ: +3
- File ẩn quá nhiều: +3
- Systemd unit lạ: +3

---

## 💡 Ví dụ dùng

### Copy script nhanh vào nhiều VM
```bash
for host in 192.168.200.151 192.168.200.152 192.168.200.153; do
  echo "[*] Copy vào $host..."
  sshpass -p 'Icom@2025' scp -o StrictHostKeyChecking=no \
    hci_scan.sh hunghv@$host:/tmp/
done
```

### Chạy trên tất cả VM
```bash
for host in 192.168.200.151 192.168.200.152 192.168.200.153; do
  echo "[*] Quét $host..."
  sshpass -p 'Icom@2025' ssh -o StrictHostKeyChecking=no \
    hunghv@$host 'bash /tmp/hci_scan.sh' > /tmp/${host##*.}_scan.log 2>&1 &
done
wait
```

### Lấy tất cả kết quả về local
```bash
mkdir -p ~/hci_scan_results
for host in 192.168.200.151 192.168.200.152 192.168.200.153; do
  echo "[*] Fetch từ $host..."
  sshpass -p 'Icom@2025' scp -o StrictHostKeyChecking=no -r \
    hunghv@$host:/tmp/hci_scan_* ~/hci_scan_results/
done
```

### Xem 1 file kết quả
```bash
# Trên VM (sau khi chạy)
less /tmp/hci_scan_*/2_accounts.txt    # Tài khoản
less /tmp/hci_scan_*/3_ssh.txt         # SSH keys
less /tmp/hci_scan_*/10_auth.txt       # Login attempts

# Hoặc lấy về local
cat ~/hci_scan_results/hci_scan_151_*/2_accounts.txt
```

---

## 🔍 Nếu thấy "SCORE cao"

1. **Check 2_accounts.txt**: UID 0 ngoài root?
2. **Check 3_ssh.txt**: SSH keys bất thường?
3. **Check 7_process.txt**: Process từ /tmp?
4. **Check 10_auth.txt**: Brute-force? Root login?
5. **Check 11_bash_history.txt**: Lệnh nghi vấn?
6. **Check 12_persistence.txt**: Backdoor trong .bashrc, systemd?

---

## 📝 Ghi chú

- Script không sửa gì, chỉ đọc
- Chạy 1-2 phút tùy kích thước log
- Cần `sshpass` trên máy copy script (hoặc dùng password SSH)
- Nếu VM lớn, check 9_changed_files.txt có thể chậm
- File kết quả có thể > 100MB nếu log nhiều

---

## 🎯 Các file quan trọng nhất

Nếu bận, chỉ cần xem:
1. **2_accounts.txt** - UID 0, mật khẩu rỗng
2. **3_ssh.txt** - SSH key có lạ không
3. **7_process.txt** - Process lạ từ /tmp
4. **10_auth.txt** - Brute-force, root login
5. **11_bash_history.txt** - Lệnh nghi vấn (curl, nc, python...)
6. **12_persistence.txt** - Backdoor

**DONE!** Chỉ cần 1 file `hci_scan.sh` thôi. Copy vào VM, chạy `bash hci_scan.sh`, check kết quả 😊
