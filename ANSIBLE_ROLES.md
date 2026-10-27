# Chạy quét với Ansible Roles (không cần Python trên VM)

## 🎯 Cách hoạt động

Thay vì copy script bash, ta dùng **Ansible tasks** (shell commands) để quét trực tiếp.

```
Không cần Python trên VM!
Chỉ cần SSH + shell
```

---

## 📋 Chuẩn bị

### 1. Trên setup machine (73.1.53.252.177)
```bash
# Cài Ansible
apt-get install -y ansible python3-jinja2

# Hoặc từ pip
pip3 install -r requirements.txt
```

### 2. Cấu hình inventory
```bash
# Sửa inventory/hosts.ini
[hci]
192.168.10.123
192.168.10.30
192.168.10.181

[hci:vars]
ansible_user=root
# Dùng SSH key (không cần password)
```

---

## 🚀 Chạy

### Nhanh nhất
```bash
cd ~/scan_hci_old
ansible-playbook scan.yml -i inventory/hosts.ini
```

### Nếu dùng password SSH
```bash
ansible-playbook scan.yml -i inventory/hosts.ini \
  --ask-pass
```

### Chạy chỉ 1 VM
```bash
ansible-playbook scan.yml -i inventory/hosts.ini \
  -l 192.168.10.123
```

---

## 📁 Cấu trúc

```
scan_hci_old/
├── roles/secscan/
│   └── tasks/
│       └── main.yml        ← 15 tasks quét
├── inventory/
│   ├── hosts.ini           ← Danh sách VM
│   └── group_vars/
│       └── hci.yml
├── scan.yml                ← Playbook
├── requirements.txt        ← Ansible deps
└── results/                ← Kết quả (fetch về)
```

---

## ✅ Lợi ích so với script bash

| | Bash script | Ansible roles |
|---|---|---|
| **Python cần** | Cần | ❌ Không |
| **Copy file** | Cần | ❌ Tự động |
| **Fetch kết quả** | Thủ công | ✅ Tự động |
| **Modular** | 1 file lớn | ✅ 15 tasks |
| **Idempotent** | Không | ✅ Có |
| **Retry** | Không | ✅ Có |

---

## 📊 Output

Sau playbook chạy xong:

```bash
# Trên controller (setup machine)
cd ~/scan_hci_old
ls results/
# results/192.168.10.123/
# results/192.168.10.30/
# results/192.168.10.181/

# Mỗi thư mục có 15 file
ls results/192.168.10.123/
# 1_patches.txt
# 2_accounts.txt
# ... (15 file)
```

---

## 🔍 Phân tích kết quả

```bash
# Dùng script analyze_results.sh
bash analyze_results.sh results/192.168.10.123

# Hoặc check nhanh
grep "^[^:]*:x:0:" results/192.168.10.123/2_accounts.txt | grep -v "^root:"
```

---

## ⚠️ Nếu lỗi

### "FAILED! => ... Shared connection closed"
→ VM down hoặc network issue

**Fix:** Skip VM đó, chạy chỉ VM OK
```bash
ansible-playbook scan.yml -i inventory/hosts.ini \
  -l "192.168.10.123,192.168.10.30"
```

### "ERROR! unexpected keyword: gather_facts"
→ Ansible quá cũ

**Fix:**
```bash
pip3 install --upgrade ansible-core
```

### Results folder trống
→ Playbook thất bại ở task nào đó

**Fix:** Check debug output
```bash
ansible-playbook scan.yml -i inventory/hosts.ini -vvv
```

---

## 📖 So sánh với script bash

**Trước (bash):**
```bash
scp hci_scan.sh root@vm:/tmp/
ssh root@vm 'bash /tmp/hci_scan.sh'
scp -r root@vm:/tmp/hci_scan_* .
```

**Giờ (Ansible roles):**
```bash
ansible-playbook scan.yml -i inventory/hosts.ini
# ✅ Tất cả tự động!
```

---

## 💡 Thêm VM mới

```bash
# Edit inventory/hosts.ini
[hci]
192.168.10.123
192.168.10.30
192.168.10.200   # ← Thêm

# Chạy lại
ansible-playbook scan.yml -i inventory/hosts.ini
```

---

## ✅ Done!

Bây giờ bạn có:
- ✅ Không cần Python trên VM
- ✅ Ansible roles (15 tasks)
- ✅ Tự động fetch kết quả
- ✅ Giống reference security-scan repo

Chỉ cần:
```bash
ansible-playbook scan.yml -i inventory/hosts.ini
```

🎯
