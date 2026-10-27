# scan_hci_old

**Script + Ansible** quét an toàn hệ thống Ubuntu (HCI cũ).

Phát hiện:
- 🚨 **Dấu hiệu xâm nhập** (backdoor, rootkit, SSH key lạ)
- 🔴 **Tấn công đang diễn ra** (brute-force, process lạ, cron lạ)
- ⚙️ **Cấu hình bảo mật** (bản vá, SSH, firewall, accounts, logs)

---

## 📋 File

```
scan_hci_old/
├── hci_scan.sh              ← Script quét (15 checks)
├── scan.yml                 ← Ansible playbook
├── ansible.cfg              ← Ansible config
├── inventory/
│   ├── hosts.ini            ← Danh sách VM [hci]
│   └── group_vars/
│       └── hci.yml          ← Tham số
├── requirements.txt
├── HOW_TO_USE.md            ← Hướng dẫn script
├── ANSIBLE.md               ← Hướng dẫn Ansible
└── README.md
```

---

## 🚀 2 cách dùng

### 1️⃣ **SSH + Script (1 VM)**
```bash
scp hci_scan.sh hunghv@192.168.200.151:/tmp/
ssh hunghv@192.168.200.151
bash /tmp/hci_scan.sh
```
👉 Chi tiết: **[HOW_TO_USE.md](HOW_TO_USE.md)**

### 2️⃣ **Ansible (nhiều VM - TỪ SETUP)**
```bash
# Clone repo lên máy setup
git clone http://gitlab-dev.i-com.vn/.../scan_hci_old.git
cd scan_hci_old

# Sửa inventory/hosts.ini, thêm VM cần quét
[hci]
192.168.200.151
192.168.200.152
192.168.200.153

# Chạy playbook
export SSH_USER=hunghv SSH_PASS=Icom@2025
ansible-playbook scan.yml -i inventory/hosts.ini \
  -e "ansible_user=$SSH_USER" -e "ansible_password=$SSH_PASS" -v

# Xem kết quả
ls -la results/
```
👉 Chi tiết: **[ANSIBLE.md](ANSIBLE.md)**

---

## 📊 Kết quả

Mỗi VM có **15 file** check trong `/tmp/hci_scan_<hostname>_<timestamp>/`:
- `1_patches.txt` - Bản vá chưa cài
- `2_accounts.txt` - Tài khoản, UID 0
- `3_ssh.txt` - SSH config, keys
- `4_sudo.txt` - Sudo rules
- `5_firewall.txt` - Firewall, ports mở
- `6_cron.txt` - Cron lạ
- `7_process.txt` - Process từ /tmp, /dev/shm
- `8_files.txt` - File ẩn, SUID
- `9_changed_files.txt` - File mới 7 ngày
- `10_auth.txt` - Login log, brute-force
- `11_bash_history.txt` - Lệnh nghi vấn (curl, wget, nc...)
- `12_persistence.txt` - Backdoor (.bashrc, rc.local, systemd)
- `13_known_hosts.txt` - SSH remote
- `14_kernel.txt` - Kernel modules
- `15_hosts.txt` - /etc/hosts, DNS
