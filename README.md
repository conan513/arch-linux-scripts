# 🛡️ Arch Security Toolkit

This repository contains a comprehensive Bash script designed for **Arch-based Linux distributions**. It helps automate essential system hardening tasks, improve security posture, and simplify configuration — all from a single interactive menu.

---

## ✅ Features

- 🔐 **Secure Boot Setup** using `sbctl`
- 🔥 **Firewall Management** with optional GUI installer
- 📋 **Auditd Logging** toggle
- 🚫 **Fail2ban Protection** for brute-force attack mitigation
- 🛡️ **Kernel Hardening** via `sysctl`
- 🧹 **Orphaned Package Cleanup**
- 🔍 **Security Audit** with:
  - SSH root login check
  - Sudo privilege analysis
  - Kernel hardening status
  - Auditd, Fail2ban, Firewall, Secure Boot checks
  - CPU mitigation flags detection (`nopti`, `mds=off`, etc.)
  - `mitigations=off` global override detection
  - ⚠️ Performance impact warnings for active mitigations

---

## 📦 Requirements

- Arch-based Linux distribution (e.g. Arch, Manjaro, EndeavourOS)
- `dialog` package (installed automatically if missing)
- `sbctl`, `ufw`, `audit`, `fail2ban` — installed as needed

---

## 🚀 Usage

```bash
git clone https://github.com/yourusername/arch-security-toolkit.git
cd arch-security-toolkit
chmod +x arch-security-toolkit.sh
./arch-security-toolkit.sh
