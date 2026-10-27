#!/bin/bash
# ======================================================================
# hci_scan.sh - Quét bảo mật HCI cũ (một script duy nhất)
# Copy vào VM cũ và chạy: bash hci_scan.sh
# ======================================================================

set -u
OUT_DIR="/tmp/hci_scan_$(hostname)_$(date +%s)"
mkdir -p "$OUT_DIR"

SCORE=0
hit() { SCORE=$((SCORE + $1)); echo "[!] [+$1] $2"; }

echo "=============== HCI SCAN $(hostname) - $(date '+%F %T') ==============="
echo "Kết quả: $OUT_DIR"
echo ""

# ====== PHAN 1: PATCH & KERNEL ======
echo "[+] 1. BẢN VÁ & KERNEL"
{
  echo "=== OS ==="
  lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2

  echo "=== Kernel ==="
  uname -r

  echo "=== Updates chưa cài ==="
  apt-get -s upgrade 2>/dev/null | grep -E '^Inst ' | head -10

  echo "=== Security updates ==="
  apt-get -s upgrade 2>/dev/null | grep -i security | wc -l | xargs echo "Số package:"
} | tee "$OUT_DIR/1_patches.txt"

# ====== PHAN 2: TAI KHOAN ======
echo "[+] 2. TÀI KHOẢN & QUY"
{
  echo "=== UID 0 (ngoài root) ==="
  awk -F: '$3 == 0 && $1 != "root" {print}' /etc/passwd | head -10
  [ $(awk -F: '$3 == 0' /etc/passwd | wc -l) -gt 1 ] && hit 5 "Có UID 0 ngoài root"

  echo "=== Shell users (không phải nologin) ==="
  grep -v '/nologin\|/false\|/bin/sync' /etc/passwd | cut -d: -f1,3,7 | head -20

  echo "=== Mật khẩu rỗng? ==="
  awk -F: '$2 == "" {print $1}' /etc/shadow 2>/dev/null
  [ $(awk -F: '$2 == ""' /etc/shadow 2>/dev/null | wc -l) -gt 0 ] && hit 10 "Có tài khoản mật khẩu rỗng"

  echo "=== Groups sudo/docker/lxd ==="
  getent group sudo docker lxd 2>/dev/null

  echo "=== Quyền /etc/passwd, /etc/shadow ==="
  stat /etc/passwd /etc/shadow 2>/dev/null | grep -E 'Uid|Gid|Access:'
} | tee "$OUT_DIR/2_accounts.txt"

# ====== PHAN 3: SSH ======
echo "[+] 3. SSH CONFIGURATION"
{
  echo "=== sshd -T (config chính) ==="
  sshd -T 2>/dev/null | grep -E 'permitrootlogin|passwordauthentication|permitemptypasswords|pubkeyauthentication|protocol|ciphers|port' || echo "Không lấy được"

  [ "$(sshd -T 2>/dev/null | grep permitrootlogin | cut -d' ' -f2)" = "yes" ] && hit 3 "PermitRootLogin = yes"

  echo "=== SSH keys (authorized_keys) ==="
  for f in /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys; do
    [ -f "$f" ] && echo "-- $f ($(wc -l < "$f") keys) --" && ssh-keygen -lf "$f" 2>/dev/null | head -20 || true
  done

  echo "=== SSH key files riêng (id_rsa, id_ed25519) ==="
  find /root/.ssh /home/*/.ssh -name 'id_*' -type f 2>/dev/null | while read k; do
    stat -c '%a %U:%G %s %y' "$k" 2>/dev/null | xargs echo "$k:"
  done
} | tee "$OUT_DIR/3_ssh.txt"

# ====== PHAN 4: SUDO ======
echo "[+] 4. SUDO CONFIGURATION"
{
  echo "=== Sudoers ==="
  cat /etc/sudoers 2>/dev/null | grep -v '^\s*#' | grep -v '^\s*$'

  echo "=== NOPASSWD rules ==="
  grep 'NOPASSWD' /etc/sudoers /etc/sudoers.d/* 2>/dev/null
  [ $? -eq 0 ] && hit 3 "Có NOPASSWD trong sudoers"

  echo "=== env_keep ==="
  grep 'env_keep' /etc/sudoers /etc/sudoers.d/* 2>/dev/null
} | tee "$OUT_DIR/4_sudo.txt"

# ====== PHAN 5: FIREWALL & NETWORK ======
echo "[+] 5. FIREWALL & MẠNG"
{
  echo "=== UFW ==="
  ufw status 2>/dev/null || echo "UFW không bật"

  echo "=== iptables ==="
  iptables-save 2>/dev/null | grep -E '^-A ' | head -30 || echo "iptables không cài hoặc không quyền"

  echo "=== Listening ports ==="
  ss -tlnp 2>/dev/null | head -30 || netstat -tlnp 2>/dev/null | head -30

  echo "=== Cổng nhạy cảm (6379=Redis, 27017=Mongo, 3306=MySQL, 5432=Postgres) ==="
  ss -tlnp 2>/dev/null | grep -E ':6379|:27017|:3306|:5432'
  [ $? -eq 0 ] && hit 5 "Cổng nhạy cảm mở"
} | tee "$OUT_DIR/5_firewall.txt"

# ====== PHAN 6: CRON & SYSTEMD ======
echo "[+] 6. CRON & SYSTEMD TIMER"
{
  echo "=== /etc/crontab ==="
  grep -v '^\s*#' /etc/crontab 2>/dev/null || echo "Không tìm thấy"

  echo "=== /etc/cron.d/* ==="
  find /etc/cron.d -type f 2>/dev/null | while read f; do
    echo "-- $f --"
    grep -v '^\s*#' "$f"
  done

  echo "=== User crontabs ==="
  for u in $(cut -d: -f1 /etc/passwd | head -20); do
    crontab -u "$u" -l 2>/dev/null && echo "-- user $u --"
  done

  echo "=== Systemd timers ==="
  systemctl list-timers --all 2>/dev/null | head -30

  echo "=== Cron lạ (curl, wget, python, shell) ==="
  (cat /etc/crontab /etc/cron.d/* /var/spool/cron/crontabs/* 2>/dev/null | grep -E 'curl|wget|python|bash -c|nc |ncat') && hit 3 "Cron gọi lệnh lạ"
} | tee "$OUT_DIR/6_cron.txt"

# ====== PHAN 7: PROCESS ======
echo "[+] 7. PROCESS"
{
  echo "=== Process từ /tmp, /dev/shm ==="
  for p in /proc/[0-9]*; do
    e=$(readlink "$p/exe" 2>/dev/null) || continue
    case "$e" in
      /tmp/*|/dev/shm/*|/var/tmp/*|*deleted*)
        echo "PID ${p#/proc/}: $e - $(tr '\0' ' ' < "$p/cmdline" | cut -c1-150)"
        hit 5 "Process lạ từ /tmp hoặc /dev/shm"
        ;;
    esac
  done

  echo "=== Top 10 CPU ==="
  ps aux --sort=-%cpu | head -11

  echo "=== Top 10 Memory ==="
  ps aux --sort=-%mem | head -11

  echo "=== Process giả danh [kworker], [sshd], [cron] ==="
  ps aux | grep -E '\[kworker\]|\[sshd\]|\[cron\]' | grep -v grep
} | tee "$OUT_DIR/7_process.txt"

# ====== PHAN 8: FILE AN / HIDDEN ======
echo "[+] 8. FILE ẨN & SUSPICIOUS"
{
  echo "=== File trong /tmp, /dev/shm (mới nhất 100) ==="
  find /tmp /dev/shm /var/tmp -type f 2>/dev/null | head -100 | while read f; do
    stat -c '%y %a %U:%G %s' "$f" 2>/dev/null | xargs echo "$f:"
  done

  echo "=== File ẩn (bắt đầu .) trong /etc, /usr, /lib ==="
  find /etc /usr/bin /usr/sbin /lib /lib64 -maxdepth 2 -name '.*' -type f 2>/dev/null | head -50
  [ $(find /etc /usr/bin /usr/sbin /lib /lib64 -maxdepth 2 -name '.*' -type f 2>/dev/null | wc -l) -gt 5 ] && hit 3 "Quá nhiều file ẩn"

  echo "=== File SUID/SGID lạ ==="
  find / -xdev -type f \( -perm -04000 -o -perm -02000 \) 2>/dev/null | head -50

  echo "=== /usr/bin, /usr/sbin mới thêm ==="
  find /usr/bin /usr/sbin -type f -mtime -7 2>/dev/null
} | tee "$OUT_DIR/8_files.txt"

# ====== PHAN 9: FILE THAY DOI ======
echo "[+] 9. FILE THAY ĐỔI 7 NGÀY GẦN ĐÂY"
{
  echo "=== /etc ==="
  find /etc -type f -mtime -7 2>/dev/null | head -50

  echo "=== /root, /home ==="
  find /root /home -type f -mtime -7 2>/dev/null | head -50

  echo "=== /usr/local ==="
  find /usr/local -type f -mtime -7 2>/dev/null
} | tee "$OUT_DIR/9_changed_files.txt"

# ====== PHAN 10: LOG DANG NHAP ======
echo "[+] 10. LOG ĐĂNG NHẬP SSH & SUDO"
{
  echo "=== SSH login (20 dòng gần nhất) ==="
  grep 'Accepted' /var/log/auth.log 2>/dev/null | tail -20 || echo "Không tìm"

  echo "=== Brute-force attempts (Failed password > 5 IP) ==="
  grep 'Failed password' /var/log/auth.log* 2>/dev/null | awk '{print $11}' | sort | uniq -c | sort -rn | head -20
  [ $(grep 'Failed password' /var/log/auth.log* 2>/dev/null | awk '{print $11}' | sort | uniq -c | awk '$1 > 5' | wc -l) -gt 0 ] && hit 3 "Brute-force SSH"

  echo "=== Root login ==="
  grep 'Accepted.*root' /var/log/auth.log 2>/dev/null | tail -10
  [ $(grep 'Accepted.*root' /var/log/auth.log 2>/dev/null | wc -l) -gt 0 ] && hit 2 "Root đăng nhập SSH"

  echo "=== sudo commands ==="
  grep 'sudo:' /var/log/auth.log 2>/dev/null | tail -20
} | tee "$OUT_DIR/10_auth.txt"

# ====== PHAN 11: BASH HISTORY ======
echo "[+] 11. BASH HISTORY (lệnh lạ)"
{
  echo "=== /root/.bash_history ==="
  [ -f /root/.bash_history ] && grep -nE 'curl |wget |ssh |nc |ncat |socat |python.*-c|base64 -d|chmod \+x|rm -rf' /root/.bash_history | tail -30 || echo "Không tìm"

  echo "=== /home/*/.bash_history ==="
  for h in /home/*/.bash_history; do
    [ -f "$h" ] && grep -nE 'curl |wget |ssh |nc |socat |python' "$h" | tail -20 | sed "s|^|$h:|"
  done
} | tee "$OUT_DIR/11_bash_history.txt"

# ====== PHAN 12: PERSISTENCE (backdoor) ======
echo "[+] 12. PERSISTENCE MECHANISMS (cửa sau)"
{
  echo "=== .bashrc, .profile (alias hijack) ==="
  for f in /root/.bashrc /root/.profile /home/*/.bashrc /home/*/.profile; do
    [ -f "$f" ] && grep -E 'alias|export|eval' "$f" && echo "-- $f --"
  done

  echo "=== /etc/ld.so.preload ==="
  cat /etc/ld.so.preload 2>/dev/null || echo "Không tìm"

  echo "=== /etc/environment ==="
  cat /etc/environment 2>/dev/null

  echo "=== rc.local ==="
  [ -f /etc/rc.local ] && grep -v '^\s*#' /etc/rc.local || echo "Không tìm"

  echo "=== systemd units lạ ==="
  find /etc/systemd/system -name '*.service' -o -name '*.timer' 2>/dev/null | while read f; do
    grep -E 'ExecStart|ExecStartPre' "$f" | grep -qE 'curl|wget|python|nc|bash' && echo "SUSPICIOUS: $f" && hit 3 "Systemd unit lạ"
  done
} | tee "$OUT_DIR/12_persistence.txt"

# ====== PHAN 13: KNOWN_HOSTS (SSH ra ngoài?) ======
echo "[+] 13. KNOWN_HOSTS (đăng nhập tới máy nào?)"
{
  for k in /root/.ssh/known_hosts /home/*/.ssh/known_hosts; do
    [ -f "$k" ] && { echo "-- $k --"; cat "$k" | grep -v '^|' | head -30; }
  done
} | tee "$OUT_DIR/13_known_hosts.txt"

# ====== PHAN 14: KERNEL MODULES ======
echo "[+] 14. KERNEL MODULES (LKM rootkit?)"
{
  echo "=== Loaded modules ==="
  lsmod | head -50

  echo "=== Modules lạ (không từ /lib/modules) ==="
  for m in $(lsmod | tail -n +2 | awk '{print $1}'); do
    [ ! -f "/lib/modules/$(uname -r)/kernel/$m.ko" ] && [ ! -f "/lib/modules/$(uname -r)/kernel/$m.ko.xz" ] && echo "Module lạ: $m"
  done
} | tee "$OUT_DIR/14_kernel.txt"

# ====== PHAN 15: /etc/hosts ======
echo "[+] 15. /etc/hosts (DNS hijack?)"
{
  echo "=== /etc/hosts ==="
  grep -v '^\s*#\|^\s*$' /etc/hosts

  echo "=== DNS resolvers ==="
  cat /etc/resolv.conf | head -20
} | tee "$OUT_DIR/15_hosts.txt"

# ====== TONG HOP ======
echo ""
echo "=============== TÓM TẮT ==============="
echo "Điểm nghi vấn: $SCORE"
if [ $SCORE -ge 10 ]; then
  echo "⚠️  NGHI VẤN CAO - CẦN KIỂM TRA KỸ"
elif [ $SCORE -ge 5 ]; then
  echo "⚠️  NGHI VẤN TRUNG - HỄ TÌMHIỂU"
else
  echo "✅ Bình thường (chưa phát hiện dấu hiệu)"
fi
echo ""
echo "📁 Kết quả: $OUT_DIR"
echo "📄 File:"
ls -lh "$OUT_DIR"/*.txt 2>/dev/null | awk '{print "   "$NF" ("$5")"}'
echo ""
echo "📦 Để tải về local:"
echo "  scp -r $(hostname):$OUT_DIR ."
