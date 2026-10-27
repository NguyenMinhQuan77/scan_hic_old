# Chạy scan với Ansible

## 📋 Chuẩn bị (1 lần)

### 1. Trên máy setup (192.168.200.195 hoặc máy khác)
```bash
# Cài Ansible
apt-get update
apt-get install -y ansible sshpass python3-yaml

# Hoặc cài từ pip
pip3 install ansible-core sshpass pyyaml
```

### 2. Clone repo này
```bash
git clone http://gitlab-dev.i-com.vn/devsecops/scan_hci_old.git
cd scan_hci_old
chmod +x hci_scan.sh
```

### 3. Cấu hình inventory
Sửa `inventory/hosts.ini`, thêm host cần quét vào `[hci]`:
```ini
[hci]
192.168.200.151
192.168.200.152
192.168.200.153
```

---

## 🖥️ Chạy Ansible

### Quét tất cả host trong `[hci]`
```bash
export SSH_USER=hunghv
export SSH_PASS=Icom@2025

ansible-playbook scan.yml \
  -i inventory/hosts.ini \
  -e "ansible_user=$SSH_USER" \
  -e "ansible_password=$SSH_PASS" \
  -v
```

### Quét 1 host cụ thể
```bash
ansible-playbook scan.yml \
  -i inventory/hosts.ini \
  -l 192.168.200.151 \
  -e "ansible_user=$SSH_USER" \
  -e "ansible_password=$SSH_PASS" \
  -v
```

### Quét 2-3 host
```bash
ansible-playbook scan.yml \
  -i inventory/hosts.ini \
  -l "192.168.200.151,192.168.200.152" \
  -e "ansible_user=$SSH_USER" \
  -e "ansible_password=$SSH_PASS" \
  -v
```

### Xem kết quả
```bash
# Sau khi playbook chạy xong
ls -la results/
find results/ -type f -name "*.txt" | head -20

# Xem chi tiết 1 host
less results/192.168.200.151/tmp/hci_scan_151_*/1_patches.txt

# Nén tất cả kết quả
tar -czf hci_scan_$(date +%Y%m%d_%H%M%S).tar.gz results/
```

---

## 📁 Cấu trúc sau scan

```
scan_hci_old/
├── results/
│   ├── 192.168.200.151/
│   │   └── tmp/hci_scan_151_1730033400/
│   │       ├── 1_patches.txt
│   │       ├── 2_accounts.txt
│   │       ├── 3_ssh.txt
│   │       ├── ... (15 file)
│   │       └── 15_hosts.txt
│   ├── 192.168.200.152/
│   │   └── ...
│   └── ...
└── hci_scan_20241027_133000.tar.gz
```

---

## 🔧 Customize

### Thêm host mới vào scan
```bash
# Edit inventory/hosts.ini
[hci]
192.168.200.151
192.168.200.152
192.168.200.200   # ← Thêm host mới

# Chạy lại playbook
ansible-playbook scan.yml -i inventory/hosts.ini ...
```

### Thay đổi timeout
Sửa `inventory/group_vars/hci.yml`:
```yaml
hci_timeout: 600  # 10 phút thay vì 5 phút
```

---

## 🐛 Troubleshooting

### "ansible-playbook: command not found"
```bash
pip3 install ansible-core
```

### "sshpass: command not found"
```bash
apt-get install -y sshpass
```

### "Permission denied (publickey,password)"
```bash
# Check SSH credentials
sshpass -p 'Icom@2025' ssh -o StrictHostKeyChecking=no \
  hunghv@192.168.200.151 'echo OK'
```

### Test kết nối tới host
```bash
# Ping từ Ansible
ansible all -i inventory/hosts.ini -m ping

# Hoặc SSH tay
ssh hunghv@192.168.200.151 'echo OK'
```

---

## 📊 So sánh 2 lần quét

```bash
# Lần 1 (baseline)
export SSH_USER=hunghv SSH_PASS=Icom@2025
ansible-playbook scan.yml -i inventory/hosts.ini \
  -e "ansible_user=$SSH_USER" -e "ansible_password=$SSH_PASS" -v
cp -r results/ baseline_20241027/

# Lần 2 (kiểm tra sau 1 tuần)
ansible-playbook scan.yml -i inventory/hosts.ini \
  -e "ansible_user=$SSH_USER" -e "ansible_password=$SSH_PASS" -v

# So sánh (xem có gì thay đổi)
diff -r baseline_20241027/ results/
```

---

## ✅ Tóm tắt

**Quy trình chuẩn:**

```bash
# 1️⃣ Clone repo (lần đầu)
git clone http://gitlab-dev.i-com.vn/.../scan_hci_old.git
cd scan_hci_old

# 2️⃣ Chỉnh sửa inventory (lần đầu)
# Sửa inventory/hosts.ini, thêm host cần quét

# 3️⃣ Chạy scan (mỗi lần quét)
export SSH_USER=hunghv SSH_PASS=Icom@2025
ansible-playbook scan.yml -i inventory/hosts.ini \
  -e "ansible_user=$SSH_USER" -e "ansible_password=$SSH_PASS" -v

# 4️⃣ Xem kết quả
ls -la results/
find results/ -name "*.txt"
```

**Done!** 🎯
