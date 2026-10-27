#!/bin/bash
# ======================================================================
# RUN.sh - Script chạy scan tất cả VM HCI
# Chạy trên VM setup: bash RUN.sh
# ======================================================================

set -e

# ====== CẤU HÌNH (sửa ở đây) ======
SETUP_IP="73.1.53.252.177"
SSH_USER="hunghv"
SSH_PASS="Icom@2025"  # ← SỬA PASSWORD CỦA BẠN
REPO_PATH="/opt/scan_hci_old"

# HCI VMs cần quét (sửa IP của bạn)
HCI_VMS=(
  "10.9.10.200"
  "10.9.10.201"
  "10.9.10.202"
)

# ====== VALIDATE ======
echo "=============== SCAN HCI SETUP ==============="
echo "Setup IP: $SETUP_IP"
echo "SSH User: $SSH_USER"
echo "Repo: $REPO_PATH"
echo "VMs to scan: ${HCI_VMS[@]}"
echo ""

# ====== SETUP (lần đầu) ======
if [ ! -d "$REPO_PATH" ]; then
  echo "[+] Clone repo..."
  cd /opt
  git clone http://gitlab-dev.i-com.vn/devsecops/scan_hci_old.git
  cd "$REPO_PATH"
else
  echo "[+] Repo đã có, skip clone"
  cd "$REPO_PATH"
fi

# ====== CẬP NHẬT INVENTORY ======
echo "[+] Cập nhật inventory..."
cat > inventory/hosts.ini <<EOF
[scanner]
$SETUP_IP ansible_connection=local

[hci]
$(printf '%s\n' "${HCI_VMS[@]}")

[hci:vars]
ansible_user=$SSH_USER
EOF

echo "[✓] inventory/hosts.ini đã cập nhật"

# ====== KIỂM TRA ANSIBLE ======
echo "[+] Kiểm tra Ansible..."
if ! command -v ansible-playbook &> /dev/null; then
  echo "[!] Ansible chưa cài, cài ngay..."
  sudo apt-get update
  sudo apt-get install -y ansible sshpass
fi

# ====== CHẠY SCAN ======
echo ""
echo "=============== CHẠY SCAN ==============="
export ANSIBLE_HOST_KEY_CHECKING=False

ansible-playbook scan.yml \
  -i inventory/hosts.ini \
  -e "ansible_user=$SSH_USER" \
  -e "ansible_password=$SSH_PASS" \
  -v

# ====== TÓM TẮT ======
echo ""
echo "=============== SCAN HOÀN THÀNH ==============="
echo "[✓] Kết quả lưu ở: $REPO_PATH/results/"
echo ""
echo "[*] Để xem kết quả:"
echo "  ls -la $REPO_PATH/results/"
echo "  find $REPO_PATH/results -name '*.txt' | head -20"
echo ""
echo "[*] Để nén tất cả:"
echo "  cd $REPO_PATH"
echo "  tar -czf hci_scan_\$(date +%Y%m%d_%H%M%S).tar.gz results/"
echo ""
