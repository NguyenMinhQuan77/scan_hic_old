# Customize cho VM setup HCI của bạn (73.1.53.252.177)

## 🔧 Cần sửa những gì

### 1️⃣ **inventory/hosts.ini** - QUAN TRỌNG
```ini
[scanner]
73.1.53.252.177 ansible_connection=local   # ← VM setup của bạn

[hci]
# ← Thêm IP các VM HCI cần quét, ví dụ:
10.9.10.200
10.9.10.201
10.9.10.202

[hci:vars]
ansible_user=hunghv   # ← Sửa nếu user SSH khác (trên các VM HCI)
```

### 2️⃣ **ansible.cfg** - Tuỳ chọn
```ini
[ssh_connection]
ssh_args = -o ConnectTimeout=10 -o StrictHostKeyChecking=no
```
Nếu network HCI khác, có thể cần tuỳnh chỉnh SSH args.

### 3️⃣ **inventory/group_vars/hci.yml** - Tuỳ chọn
```yaml
hci_timeout: 300  # Nếu network chậm, tăng lên 600 (10 phút)
```

---

## ⚡ Cách chạy trên VM setup (73.1.53.252.177)

### Bước 1: Clone repo
```bash
cd /opt  # hoặc /tmp tuỳ thích
git clone http://gitlab-dev.i-com.vn/devsecops/scan_hci_old.git
cd scan_hci_old
```

### Bước 2: Cài Ansible & dependencies
```bash
sudo apt-get update
sudo apt-get install -y ansible sshpass python3-yaml

# Hoặc cài từ pip
sudo pip3 install -r requirements.txt
```

### Bước 3: Sửa inventory
```bash
# ← MỘT LẦN DUY NHẤT
nano inventory/hosts.ini
# Thêm IP các VM HCI vào [hci] section
```

### Bước 4: Chạy scan
```bash
# Thiết lập credential SSH
export SSH_USER=hunghv
export SSH_PASS='<password>'  # Password của user hunghv trên các VM HCI

# Chạy playbook
ansible-playbook scan.yml -i inventory/hosts.ini \
  -e "ansible_user=$SSH_USER" \
  -e "ansible_password=$SSH_PASS" \
  -v

# Hoặc nếu SSH key, không cần -e "ansible_password"
ansible-playbook scan.yml -i inventory/hosts.ini -v
```

### Bước 5: Xem kết quả
```bash
# Trên VM setup (73.1.53.252.177)
ls -la results/
find results/ -name "*.txt" | head -20

# Xem chi tiết 1 VM
cat results/10.9.10.200/tmp/hci_scan_*/2_accounts.txt

# Nén tất cả kết quả
tar -czf hci_scan_$(date +%Y%m%d_%H%M%S).tar.gz results/

# Lấy về local (nếu cần)
scp -r user@73.1.53.252.177:/opt/scan_hci_old/results .
```

---

## 📋 Checklist trước chạy

- [ ] Clone repo trên VM setup (73.1.53.252.177)
- [ ] Ansible đã cài: `ansible --version`
- [ ] Sshpass đã cài: `sshpass -V`
- [ ] inventory/hosts.ini có đúng IP các VM HCI
- [ ] ansible_user trong hosts.ini khớp với user SSH trên các VM HCI
- [ ] Test SSH trước: `sshpass -p 'password' ssh -o StrictHostKeyChecking=no hunghv@<ip_vm_hci> 'echo OK'`

---

## 🐛 Nếu có lỗi

### "ansible: command not found"
```bash
sudo apt-get install -y ansible
# hoặc
sudo pip3 install ansible-core
```

### "sshpass: command not found"
```bash
sudo apt-get install -y sshpass
```

### "Permission denied" khi SSH
```bash
# Check credentials
sshpass -p 'password' ssh -o StrictHostKeyChecking=no \
  hunghv@10.9.10.200 'id'

# Nếu lỗi, check:
# 1. IP đúng chưa?
# 2. User/password đúng chưa?
# 3. VM HCI kích hoạt password auth chưa?
```

### "Host không trả lời"
```bash
# Test ping
ping -c 1 10.9.10.200

# Test SSH từ setup
ssh -v hunghv@10.9.10.200 'echo OK'

# Nếu ping OK nhưng SSH timeout, check firewall
```

### Script chạy quá lâu
Tăng timeout trong `inventory/group_vars/hci.yml`:
```yaml
hci_timeout: 600  # Từ 300 (5 phút) → 600 (10 phút)
```

---

## 💡 Ví dụ cụ thể

### Scenario: Quét 3 VM HCI
```bash
# 1. Setup
cd /opt/scan_hci_old
nano inventory/hosts.ini
# [hci]
# 10.9.10.200
# 10.9.10.201
# 10.9.10.202

# 2. Chạy
export SSH_USER=hunghv
export SSH_PASS=Icom@2025
ansible-playbook scan.yml -i inventory/hosts.ini \
  -e "ansible_user=$SSH_USER" \
  -e "ansible_password=$SSH_PASS" -v

# 3. Kết quả
ls results/
# results/10.9.10.200/...
# results/10.9.10.201/...
# results/10.9.10.202/...
```

---

## ✅ Done!

Bây giờ bạn có thể chạy scan từ VM setup (73.1.53.252.177) cho tất cả VM HCI! 🎯
