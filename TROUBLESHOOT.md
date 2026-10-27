# Troubleshoot kết quả scan

## 📍 Kết quả ở đâu?

### Cách 1: **Trên setup machine** (sau khi chạy playbook)
```bash
cd /root/scan_hic_old
ls -la results/
find results/ -name "*.txt" | head -20
```

### Cách 2: **Trực tiếp trên VMs** (nếu playbook fetch thất bại)
```bash
# SSH vào VM
ssh hunghv@192.168.10.123 'ls -la /tmp/hci_scan_*/'

# Xem kết quả
ssh hunghv@192.168.10.123 'cat /tmp/hci_scan_*/1_patches.txt'

# Copy về setup
scp -r hunghv@192.168.10.123:/tmp/hci_scan_*/ /root/scan_hic_old/results/
```

---

## ⚠️ Lỗi: "MODULE FAILURE: /usr/bin/python: not found"

Ansible cần Python để chạy facts gathering. Các VM không có Python.

### Fix: Cài Python trên VMs
```bash
# SSH vào từng VM lỗi
ssh hunghv@192.168.10.143

# Cài Python
sudo apt-get update
sudo apt-get install -y python3

# Hoặc cài Python2 (cũ)
sudo apt-get install -y python

# Quay lại chạy playbook
```

Hoặc skip facts gathering:
```bash
ansible-playbook scan.yml -i inventory/hosts.ini --skip-tags gather_facts
```

---

## ⚠️ Lỗi: "ImportError: cannot import name 'Mapping' from 'collections'"

Ansible cũ với Python 3.10+ có incompatibility.

### Fix: Upgrade Ansible
```bash
sudo pip3 install --upgrade ansible-core
```

Hoặc chỉ định Python 3.9:
```bash
ansible-playbook scan.yml -i inventory/hosts.ini \
  -e "ansible_python_interpreter=/usr/bin/python3.9"
```

---

## 🔧 Chạy lại (sau khi fix)

Playbook đã fix ở `scan.yml`. Chạy lại:

```bash
cd /root/scan_hic_old

# Chạy toàn bộ
ansible-playbook scan.yml -i inventory/hosts.ini \
  -e "ansible_user=hunghv" \
  -e "ansible_password=Icom@2025" -v

# Hoặc chỉ quét VM thành công trước
ansible-playbook scan.yml -i inventory/hosts.ini \
  -l "192.168.10.123,192.168.10.30" \
  -e "ansible_user=hunghv" \
  -e "ansible_password=Icom@2025" -v
```

Lần này kết quả sẽ copy về `results/` đúng cách.

---

## 📊 Xem kết quả sau chạy

```bash
# Trên setup
cd /root/scan_hic_old/results
ls -la

# Xem chi tiết 1 VM
ls 192.168.10.123/  # Hoặc hostname nếu copy thông qua
cat 192.168.10.123/1_patches.txt
cat 192.168.10.123/2_accounts.txt
cat 192.168.10.123/10_auth.txt

# Nén tất cả
tar -czf scan_$(date +%Y%m%d_%H%M%S).tar.gz results/
```

---

## ✅ Checklist fix

- [ ] Cài Python trên VMs lỗi: `sudo apt-get install -y python3`
- [ ] Upgrade Ansible (nếu cần): `sudo pip3 install --upgrade ansible-core`
- [ ] Chạy playbook lại
- [ ] Kiểm tra kết quả ở `results/`
- [ ] Nén kết quả (nếu cần)
