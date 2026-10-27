#!/bin/bash
# ======================================================================
# analyze_results.sh - Phân tích kết quả scan để phát hiện hacker
# Chạy: bash analyze_results.sh <thư_mục_kết_quả>
# Ví dụ: bash analyze_results.sh results/192.168.10.123
# ======================================================================

set -e

RESULTS_DIR="${1:-.}"

if [ ! -d "$RESULTS_DIR" ]; then
  echo "❌ Thư mục không tồn tại: $RESULTS_DIR"
  exit 1
fi

echo "=============== PHÂN TÍCH KẾT QUẢ SCAN ==============="
echo "Thư mục: $RESULTS_DIR"
echo ""

RISK_SCORE=0
WARNINGS=()

# ====== 1. TÀI KHOẢN ======
echo "[CHECK] 1. TÀI KHOẢN"
if [ -f "$RESULTS_DIR/2_accounts.txt" ]; then
  UID0=$(grep "^[^:]*:x:0:" "$RESULTS_DIR/2_accounts.txt" 2>/dev/null | grep -v "^root:" | wc -l)
  if [ "$UID0" -gt 0 ]; then
    echo "  🚨 NGUY HIỂM: Có UID 0 ngoài root!"
    WARNINGS+=("UID 0 ngoài root (có thể backdoor)")
    RISK_SCORE=$((RISK_SCORE + 20))
  else
    echo "  ✅ OK: Chỉ root có UID 0"
  fi

  EMPTY_PASS=$(grep "^[^:]*::\|^[^:]*:$" "$RESULTS_DIR/2_accounts.txt" 2>/dev/null | wc -l)
  if [ "$EMPTY_PASS" -gt 0 ]; then
    echo "  🚨 NGUY HIỂM: Mật khẩu rỗng!"
    WARNINGS+=("Có tài khoản mật khẩu rỗng")
    RISK_SCORE=$((RISK_SCORE + 15))
  fi
else
  echo "  ❓ Không tìm file accounts"
fi
echo ""

# ====== 2. SSH ======
echo "[CHECK] 2. SSH KEYS (xâm nhập)"
if [ -f "$RESULTS_DIR/3_ssh.txt" ]; then
  # Tìm SSH key lạ (quá nhiều keys)
  KEY_COUNT=$(grep -c "^ssh-" "$RESULTS_DIR/3_ssh.txt" 2>/dev/null || echo "0")
  if [ "$KEY_COUNT" -gt 3 ]; then
    echo "  ⚠️  LỰA CHỌN: Có $KEY_COUNT SSH keys (quá nhiều?)"
    WARNINGS+=("$KEY_COUNT SSH keys (kiểm tra xem key nào lạ)")
    RISK_SCORE=$((RISK_SCORE + 5))
  else
    echo "  ✅ OK: $KEY_COUNT SSH keys (bình thường)"
  fi
else
  echo "  ❓ Không tìm file ssh"
fi
echo ""

# ====== 3. PROCESS ======
echo "[CHECK] 3. PROCESS (mã độc)"
if [ -f "$RESULTS_DIR/7_process.txt" ]; then
  # Tìm process từ /tmp, /dev/shm
  SUSPICIOUS_PROCS=$(grep -i "PID.*:/tmp/\|/dev/shm/\|/var/tmp/" "$RESULTS_DIR/7_process.txt" 2>/dev/null | wc -l)
  if [ "$SUSPICIOUS_PROCS" -gt 0 ]; then
    echo "  🚨 NGUY HIỂM: Có process lạ từ /tmp, /dev/shm!"
    echo "    $(grep -i 'PID.*:/tmp/\|/dev/shm/' "$RESULTS_DIR/7_process.txt" 2>/dev/null | head -3)"
    WARNINGS+=("Process lạ từ /tmp hoặc /dev/shm (mã độc?)")
    RISK_SCORE=$((RISK_SCORE + 30))
  else
    echo "  ✅ OK: Không có process lạ"
  fi
else
  echo "  ❓ Không tìm file process"
fi
echo ""

# ====== 4. CRON LẠ ======
echo "[CHECK] 4. CRON LẠ (tự động chạy mã độc)"
if [ -f "$RESULTS_DIR/6_cron.txt" ]; then
  CRON_MALICIOUS=$(grep -i "curl\|wget\|nc\|ncat\|python.*-c\|bash -c" "$RESULTS_DIR/6_cron.txt" 2>/dev/null | grep -v "^#\|^===" | wc -l)
  if [ "$CRON_MALICIOUS" -gt 0 ]; then
    echo "  🚨 NGUY HIỂM: Có cron gọi lệnh lạ (curl, wget, nc, python...)!"
    echo "    $(grep -i 'curl\|wget\|nc\|python.*-c' "$RESULTS_DIR/6_cron.txt" 2>/dev/null | head -2)"
    WARNINGS+=("Cron lạ (có thể C2 command)")
    RISK_SCORE=$((RISK_SCORE + 25))
  else
    echo "  ✅ OK: Không có cron lạ"
  fi
else
  echo "  ❓ Không tìm file cron"
fi
echo ""

# ====== 5. BASH HISTORY ======
echo "[CHECK] 5. BASH HISTORY (lệnh nghi vấn)"
if [ -f "$RESULTS_DIR/11_bash_history.txt" ]; then
  HISTORY_MALICIOUS=$(grep -c "curl \|wget \|nc \|ncat \|python.*-c\|base64" "$RESULTS_DIR/11_bash_history.txt" 2>/dev/null || echo "0")
  if [ "$HISTORY_MALICIOUS" -gt 10 ]; then
    echo "  🚨 NGUY HIỂM: Có nhiều lệnh lạ trong history!"
    echo "    $(head -5 "$RESULTS_DIR/11_bash_history.txt" 2>/dev/null)"
    WARNINGS+=("Lệnh lạ trong bash history ($HISTORY_MALICIOUS dòng)")
    RISK_SCORE=$((RISK_SCORE + 20))
  elif [ "$HISTORY_MALICIOUS" -gt 0 ]; then
    echo "  ⚠️  LỰA CHỌN: Có lệnh lạ trong history ($HISTORY_MALICIOUS dòng)"
    RISK_SCORE=$((RISK_SCORE + 5))
  else
    echo "  ✅ OK: Không có lệnh lạ"
  fi
else
  echo "  ❓ Không tìm file history"
fi
echo ""

# ====== 6. PERSISTENCE (cửa sau) ======
echo "[CHECK] 6. PERSISTENCE (cửa sau)"
if [ -f "$RESULTS_DIR/12_persistence.txt" ]; then
  # Tìm backdoor
  BACKDOOR=$(grep -c "SUSPICIOUS\|alias\|export\|eval" "$RESULTS_DIR/12_persistence.txt" 2>/dev/null || echo "0")
  if [ "$BACKDOOR" -gt 3 ]; then
    echo "  🚨 NGUY HIỂM: Phát hiện backdoor tiềm ẩn!"
    echo "    $(grep "SUSPICIOUS" "$RESULTS_DIR/12_persistence.txt" 2>/dev/null | head -2)"
    WARNINGS+=("Backdoor tiềm ẩn trong .bashrc, rc.local, systemd")
    RISK_SCORE=$((RISK_SCORE + 30))
  else
    echo "  ✅ OK: Không phát hiện backdoor"
  fi
else
  echo "  ❓ Không tìm file persistence"
fi
echo ""

# ====== 7. FILE ẨN / SUID ======
echo "[CHECK] 7. FILE ẨN / SUID (mã độc)"
if [ -f "$RESULTS_DIR/8_files.txt" ]; then
  HIDDEN_FILES=$(grep "^/" "$RESULTS_DIR/8_files.txt" 2>/dev/null | grep -E "^\./\.|/\.|hidden" | wc -l)
  SUID_COUNT=$(grep -c "4755\|4750" "$RESULTS_DIR/8_files.txt" 2>/dev/null || echo "0")

  if [ "$HIDDEN_FILES" -gt 5 ]; then
    echo "  ⚠️  LỰA CHỌN: Có $HIDDEN_FILES file ẩn (kiểm tra)"
    RISK_SCORE=$((RISK_SCORE + 5))
  fi

  if [ "$SUID_COUNT" -gt 5 ]; then
    echo "  ⚠️  LỰA CHỌN: Có $SUID_COUNT file SUID (kiểm tra)"
    RISK_SCORE=$((RISK_SCORE + 5))
  else
    echo "  ✅ OK: File SUID bình thường"
  fi
else
  echo "  ❓ Không tìm file files"
fi
echo ""

# ====== 8. AUTH LOG ======
echo "[CHECK] 8. SSH LOGS (brute-force, đăng nhập lạ)"
if [ -f "$RESULTS_DIR/10_auth.txt" ]; then
  BRUTE_FORCE=$(grep -c "Failed password\|Invalid user" "$RESULTS_DIR/10_auth.txt" 2>/dev/null || echo "0")
  ROOT_LOGIN=$(grep -c "Accepted.*root" "$RESULTS_DIR/10_auth.txt" 2>/dev/null || echo "0")

  if [ "$BRUTE_FORCE" -gt 100 ]; then
    echo "  🚨 NGUY HIỂM: Brute-force SSH ($BRUTE_FORCE failed attempts)!"
    WARNINGS+=("Brute-force SSH ($BRUTE_FORCE lần)")
    RISK_SCORE=$((RISK_SCORE + 25))
  elif [ "$BRUTE_FORCE" -gt 20 ]; then
    echo "  ⚠️  LỰA CHỌN: Có $BRUTE_FORCE failed login attempts"
    RISK_SCORE=$((RISK_SCORE + 5))
  else
    echo "  ✅ OK: Không có brute-force"
  fi

  if [ "$ROOT_LOGIN" -gt 5 ]; then
    echo "  ⚠️  LỰA CHỌN: Root đăng nhập SSH $ROOT_LOGIN lần (bình thường?)"
    RISK_SCORE=$((RISK_SCORE + 3))
  fi
else
  echo "  ❓ Không tìm file auth"
fi
echo ""

# ====== 9. FIREWALL ======
echo "[CHECK] 9. FIREWALL (cổng mở)"
if [ -f "$RESULTS_DIR/5_firewall.txt" ]; then
  EXPOSED=$(grep -c ":6379\|:27017\|:3306\|:5432" "$RESULTS_DIR/5_firewall.txt" 2>/dev/null || echo "0")
  if [ "$EXPOSED" -gt 0 ]; then
    echo "  🚨 NGUY HIỂM: Cổng nhạy cảm mở (Redis, Mongo, MySQL, Postgres)!"
    WARNINGS+=("Cổng nhạy cảm mở ra ngoài")
    RISK_SCORE=$((RISK_SCORE + 20))
  else
    echo "  ✅ OK: Cổng bảo mật"
  fi
else
  echo "  ❓ Không tìm file firewall"
fi
echo ""

# ====== TỔNG KÊTQUẢ ======
echo "=============== KẾT QUẢ ==============="
echo "Risk Score: $RISK_SCORE/100"
echo ""

if [ $RISK_SCORE -ge 50 ]; then
  echo "🚨 🚨 🚨 ĐỀ XUẤT CAO: CÓ DẤU HIỆU BỊ XÂM NHẬP 🚨 🚨 🚨"
  echo ""
  echo "Kiểm tra ngay:"
elif [ $RISK_SCORE -ge 30 ]; then
  echo "⚠️  ⚠️  ⚠️  ĐỀ XUẤT TRUNG: CẦN KIỂM TRA KỸ ⚠️  ⚠️  ⚠️"
  echo ""
  echo "Kiểm tra file:"
elif [ $RISK_SCORE -ge 10 ]; then
  echo "ℹ️  CẢNH BÁO THẤP: KIỂM TRA THÊM"
  echo ""
else
  echo "✅ BÌNH THƯỜNG: Không phát hiện dấu hiệu xâm nhập"
  echo ""
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "⚠️  Cảnh báo:"
  for w in "${WARNINGS[@]}"; do
    echo "  • $w"
  done
  echo ""
fi

echo "📖 Để xem chi tiết:"
echo "  cat $RESULTS_DIR/2_accounts.txt   # Tài khoản"
echo "  cat $RESULTS_DIR/3_ssh.txt        # SSH keys"
echo "  cat $RESULTS_DIR/6_cron.txt       # Cron lạ"
echo "  cat $RESULTS_DIR/7_process.txt    # Process lạ"
echo "  cat $RESULTS_DIR/10_auth.txt      # SSH logs"
echo "  cat $RESULTS_DIR/11_bash_history.txt  # Command history"
echo "  cat $RESULTS_DIR/12_persistence.txt   # Backdoor"
