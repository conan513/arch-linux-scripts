#!/usr/bin/env bash

# 🎨 Színek
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 🚫 Ne fusson rootként
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}⚠️ Do not run this script as root! Use sudo when necessary.${NC}"
    exit 1
fi

# 📘 Funkcióleírások
declare -A DESCRIPTIONS=(
    ["Secure Boot"]="Secure Boot protects the boot process by allowing only signed binaries. It helps prevent rootkits and bootkits."
    ["Firewall"]="The firewall blocks unwanted incoming connections. By default, all outgoing traffic is allowed."
    ["Auditd"]="Auditd logs system events and helps trace suspicious activity."
    ["Fail2ban"]="Fail2ban detects and blocks brute-force attacks, especially on services like SSH."
    ["Orphan Cleanup"]="Removes orphaned packages to reduce attack surface and keep the system clean."
    ["Kernel Hardening"]="Restricts kernel logs and pointer access, and protects symlinks/hardlinks from abuse."
)

# 📁 Naplófájl
LOG_FILE="$HOME/arch-security-toolkit.log"

log_action() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" >> "$LOG_FILE"
    echo -e "${GREEN}✔ $1${NC}"
}

# 📦 Csomagellenőrzés
ensure_package() {
    if ! pacman -Q "$1" &> /dev/null; then
        sudo pacman -S "$1" --noconfirm
        log_action "Installed package: $1"
    fi
}

# 📦 Dialog szükséges
ensure_package dialog

# 🎉 Üdvözlő képernyő
dialog --clear --msgbox "Welcome to the Arch Security Toolkit 🛡️\n\nThis tool helps you harden your Arch Linux system by configuring key security features like Secure Boot, Firewall, Auditd, and more.\n\nUse the arrow keys to navigate and Enter to select." 12 70
clear

# 🧼 Üzenetmegjelenítő
show_message() {
    dialog --clear --msgbox "$1" 8 60
    clear
}
# 🔍 Funkció állapotellenőrzése
check_status() {
    case "$1" in
        "Secure Boot")
            if command -v sbctl &> /dev/null; then
                sbctl status 2>/dev/null | grep -q "Secure Boot:.*Enabled" && echo "Enabled" || echo "Disabled"
            else
                echo "Not installed"
            fi
            ;;
        "Firewall")
            systemctl is-active ufw &> /dev/null && echo "Enabled" || echo "Disabled"
            ;;
        "Auditd")
            systemctl is-enabled auditd &> /dev/null && echo "Enabled" || echo "Disabled"
            ;;
        "Fail2ban")
            systemctl is-active fail2ban &> /dev/null && echo "Enabled" || echo "Disabled"
            ;;
        "Orphan Cleanup")
            pacman -Qtdq &> /dev/null && echo "Needed" || echo "Clean"
            ;;
        "Kernel Hardening")
            [[ -f /etc/sysctl.d/99-hardening.conf ]] && echo "Enabled" || echo "Disabled"
            ;;
    esac
}

# 🔐 Secure Boot konfigurálása
toggle_secure_boot() {
    ensure_package sbctl
    sudo -v
    STATUS=$(sudo sbctl status)
    SETUP_MODE_ENABLED=$(echo "$STATUS" | grep -q "Setup Mode:.*Enabled" && echo "yes" || echo "no")

    if [[ "$SETUP_MODE_ENABLED" != "yes" ]]; then
        show_message "Setup Mode is disabled. To enroll Secure Boot keys, enable Setup Mode in BIOS (Clear Secure Boot keys)."
        return
    fi

    dialog --clear --yesno "Set up Secure Boot and generate keys?" 8 50
    clear
    [[ $? -ne 0 ]] && return

    sudo sbctl create-keys
    sudo sbctl enroll-keys --microsoft
    sudo sbctl sign -s
    log_action "Secure Boot keys created and enrolled"

    sudo tee /etc/pacman.d/hooks/sbctl-batch-sign.hook > /dev/null <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *linux*
Target = *kernel*
Target = *firmware*

[Action]
Description = Automatically signing Secure Boot binaries after kernel-related package changes
When = PostTransaction
Exec = /usr/bin/sbctl-batch-sign
NeedsTargets
EOF

    show_message "Secure Boot configured. Automatic signing hook activated."
}

# 🖼️ Firewall GUI választó
offer_firewall_gui() {
    dialog --clear --yesno "Would you like to install a graphical firewall interface?" 8 60
    clear
    [[ $? -ne 0 ]] && return

    GUI_OPTIONS=(
        1 "plasma-firewall (recommended for KDE)"
        2 "gufw (UFW GUI for most desktops)"
        3 "firewall-config (Firewalld GUI)"
        4 "Cancel"
    )

    GUI_CHOICE=$(dialog --clear \
        --title "Firewall GUI Options" \
        --menu "Choose a graphical firewall interface to install:" 15 60 4 \
        "${GUI_OPTIONS[@]}" \
        3>&1 1>&2 2>&3)
    clear

    case $GUI_CHOICE in
        1) ensure_package plasma-firewall ;;
        2) ensure_package gufw ;;
        3) ensure_package firewall-config ;;
        4) return ;;
    esac
}

# 🔥 Firewall be/ki kapcsolása
toggle_firewall() {
    if systemctl is-active ufw &> /dev/null; then
        dialog --clear --yesno "Firewall is enabled. Do you want to disable it?" 8 50
        clear
        [[ $? -ne 0 ]] && return
        sudo systemctl disable --now ufw
        log_action "Firewall disabled"
        show_message "Firewall disabled."
    else
        dialog --clear --yesno "Firewall is disabled. Do you want to enable it?" 8 50
        clear
        [[ $? -ne 0 ]] && return
        ensure_package ufw
        sudo systemctl enable --now ufw
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw enable
        log_action "Firewall enabled and configured"
        show_message "Firewall enabled."
        offer_firewall_gui
    fi
}
# 📋 Auditd be/ki kapcsolása
toggle_auditd() {
    if systemctl is-enabled auditd &> /dev/null; then
        dialog --clear --yesno "Auditd is enabled. Disable it? (requires reboot to fully stop)" 8 60
        clear
        [[ $? -ne 0 ]] && return
        sudo systemctl disable auditd
        log_action "Auditd disabled"
        show_message "Auditd disabled. Reboot required to fully stop the service."
    else
        dialog --clear --yesno "Auditd is disabled. Do you want to enable it?" 8 50
        clear
        [[ $? -ne 0 ]] && return
        ensure_package audit
        sudo systemctl enable --now auditd
        log_action "Auditd enabled"
        show_message "Auditd enabled."
    fi
}

# 🚫 Fail2ban be/ki kapcsolása
toggle_fail2ban() {
    if systemctl is-active fail2ban &> /dev/null; then
        dialog --clear --yesno "Fail2ban is enabled. Do you want to disable it?" 8 50
        clear
        [[ $? -ne 0 ]] && return
        sudo systemctl disable --now fail2ban
        log_action "Fail2ban disabled"
        show_message "Fail2ban disabled."
    else
        dialog --clear --yesno "Fail2ban is disabled. Do you want to enable it?" 8 50
        clear
        [[ $? -ne 0 ]] && return
        ensure_package fail2ban
        sudo systemctl enable --now fail2ban
        log_action "Fail2ban enabled"
        show_message "Fail2ban enabled."
    fi
}

# 🛡️ Kernel Hardening konfigurálása
configure_kernel_hardening() {
    if [[ -f /etc/sysctl.d/99-hardening.conf ]]; then
        dialog --clear --yesno "Kernel hardening is currently enabled.\n\nDo you want to disable it?" 10 60
        clear
        if [[ $? -eq 0 ]]; then
            sudo rm /etc/sysctl.d/99-hardening.conf
            sudo sysctl --system
            log_action "Kernel hardening settings removed"
            show_message "Kernel hardening settings have been disabled."
        else
            show_message "No changes made."
        fi
    else
        dialog --clear --yesno "Apply recommended kernel hardening settings?\n\nThis will restrict access to kernel logs, pointers, and protect symlinks/hardlinks." 10 60
        clear
        [[ $? -ne 0 ]] && return

        sudo tee /etc/sysctl.d/99-hardening.conf > /dev/null <<EOF
# Kernel hardening settings
kernel.kptr_restrict = 1
kernel.dmesg_restrict = 1
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
EOF

        sudo sysctl --system
        log_action "Applied kernel hardening settings"
        show_message "Kernel hardening settings applied successfully."
    fi
}
run_security_audit() {
    RESULTS="🔍 Security Audit Results:\n\n"

    if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
        RESULTS+="❌ SSH allows root login (PermitRootLogin yes)\n"
        RESULTS+="   → Risk: Attackers can brute-force root directly, gaining full control if successful.\n\n"
    else
        RESULTS+="✅ SSH root login is disabled\n\n"
    fi

    if sudo -l | grep -q "NOPASSWD:"; then
        RESULTS+="❌ Passwordless sudo detected\n"
        RESULTS+="   → Risk: Any local user can execute privileged commands without authentication.\n\n"
    else
        RESULTS+="✅ Sudo requires password\n\n"
    fi

    MISSING_SYSCTL=()
    for key in kernel.kptr_restrict kernel.dmesg_restrict fs.protected_symlinks fs.protected_hardlinks; do
        if ! sysctl -n "$key" 2>/dev/null | grep -q "1"; then
            MISSING_SYSCTL+=("$key")
        fi
    done
    if [[ ${#MISSING_SYSCTL[@]} -gt 0 ]]; then
        RESULTS+="❌ Missing kernel hardening settings:\n"
        for item in "${MISSING_SYSCTL[@]}"; do
            RESULTS+="   - $item\n"
        done
        RESULTS+="   → Risk: Attackers may access kernel logs, pointers, or exploit symlink/hardlink vulnerabilities.\n\n"
    else
        RESULTS+="✅ Kernel hardening settings are in place\n\n"
    fi

    if systemctl is-enabled auditd &> /dev/null; then
        RESULTS+="✅ Auditd is enabled\n\n"
    else
        RESULTS+="❌ Auditd is not enabled\n"
        RESULTS+="   → Risk: Suspicious system activity may go undetected without audit logging.\n\n"
    fi

    if systemctl is-active fail2ban &> /dev/null; then
        RESULTS+="✅ Fail2ban is active\n\n"
    else
        RESULTS+="❌ Fail2ban is not active\n"
        RESULTS+="   → Risk: Brute-force attacks (e.g. SSH login attempts) may go undetected and unblocked.\n\n"
    fi

    if command -v sbctl &> /dev/null && sbctl status 2>/dev/null | grep -q "Secure Boot:.*Enabled"; then
        RESULTS+="✅ Secure Boot is enabled\n\n"
    else
        RESULTS+="❌ Secure Boot is not enabled\n"
        RESULTS+="   → Risk: Boot process may be vulnerable to rootkits or unsigned kernel tampering.\n\n"
    fi

    if systemctl is-active ufw &> /dev/null; then
        RESULTS+="✅ Firewall is active\n\n"
    else
        RESULTS+="❌ Firewall is not active\n"
        RESULTS+="   → Risk: System may be exposed to unsolicited network traffic and remote attacks.\n\n"
    fi

    CMDLINE=$(cat /proc/cmdline)

    if echo "$CMDLINE" | grep -qw "mitigations=off"; then
        RESULTS+="❌ Global CPU mitigations disabled (mitigations=off)\n"
        RESULTS+="   → Risk: All speculative execution protections are turned off\n"
        RESULTS+="   → Benefit: Maximum performance, but vulnerable to Spectre, Meltdown, MDS, L1TF, etc.\n\n"
    else
        declare -A MITIGATION_EXPLAIN=(
            ["nopti"]="⚠️ Risk: Vulnerable to Meltdown (kernel memory disclosure)\n🚀 Benefit: Faster syscall and context switch performance"
            ["nospectre_v1"]="⚠️ Risk: Vulnerable to Spectre v1 (bounds check bypass)\n🚀 Benefit: Slightly improved performance"
            ["nospectre_v2"]="⚠️ Risk: Vulnerable to Spectre v2 (branch target injection)\n🚀 Benefit: Reduced overhead in indirect branches"
            ["spectre_v2_user=off"]="⚠️ Risk: User-space Spectre v2 attacks possible\n🚀 Benefit: Faster context switching between user processes"
            ["spec_store_bypass_disable=off"]="⚠️ Risk: Vulnerable to Speculative Store Bypass\n🚀 Benefit: Improved memory access performance"
            ["l1tf=off"]="⚠️ Risk: Vulnerable to L1 Terminal Fault (hypervisor leakage)\n🚀 Benefit: Better virtualization performance"
            ["mds=off"]="⚠️ Risk: Vulnerable to Microarchitectural Data Sampling\n🚀 Benefit: Reduced CPU overhead in data access"
        )

        MITIGATION_FLAGS=(nopti nospectre_v1 nospectre_v2 spectre_v2_user=off spec_store_bypass_disable=off l1tf=off mds=off)
        FOUND_FLAGS=()
        for flag in "${MITIGATION_FLAGS[@]}"; do
            echo "$CMDLINE" | grep -qw "$flag" && FOUND_FLAGS+=("$flag")
        done

        if [[ ${#FOUND_FLAGS[@]} -gt 0 ]]; then
            RESULTS+="❌ Specific CPU mitigation flags disabled:\n"
            for f in "${FOUND_FLAGS[@]}"; do
                RESULTS+="   - $f\n"
                RESULTS+="     → ${MITIGATION_EXPLAIN[$f]}\n\n"
            done
        fi

        for flag in "${MITIGATION_FLAGS[@]}"; do
            if ! echo "$CMDLINE" | grep -qw "$flag"; then
                SHORT_WARN=$(echo "${MITIGATION_EXPLAIN[$flag]}" | grep "🚀" | sed 's/🚀 Benefit:/⚠️ May impact:/')
                RESULTS+="✅ ${flag} mitigation is active\n"
                RESULTS+="   $SHORT_WARN\n\n"
            fi
        done
    fi

    dialog --clear --msgbox "$RESULTS" 25 80
    clear
}

# 🧹 Orphan Cleanup
cleanup_orphans() {
    ORPHANS=$(pacman -Qtdq || true)
    if [[ -z "$ORPHANS" ]]; then
        show_message "No orphaned packages to remove."
    else
        dialog --clear --yesno "Remove the following orphaned packages?\n\n$ORPHANS" 15 60
        clear
        [[ $? -ne 0 ]] && return
        sudo pacman -Rns $ORPHANS
        log_action "Removed orphaned packages: $ORPHANS"
        show_message "Orphaned packages removed."
    fi
}

# 🧭 Főmenü
main_menu() {
    while true; do
        MENU_ITEMS=(
            1 "Secure Boot [$(check_status 'Secure Boot')]"
            2 "Firewall [$(check_status 'Firewall')]"
            3 "Auditd [$(check_status 'Auditd')]"
            4 "Fail2ban [$(check_status 'Fail2ban')]"
            5 "Kernel Hardening [$(check_status 'Kernel Hardening')]"
            "" "-----------------------------"
            6 "🔍 Security Audit"
            7 "Orphan Cleanup [$(check_status 'Orphan Cleanup')]"
            8 "Exit"
        )

        CHOICE=$(dialog --clear \
            --title "Arch Security Toolkit 🛡️" \
            --menu "🔐 Harden your Arch Linux system with essential security tools.\n\nSelect a feature to configure or review its status:" 25 80 10 \
            "${MENU_ITEMS[@]}" \
            3>&1 1>&2 2>&3)
        clear

        case $CHOICE in
            1) show_message "${DESCRIPTIONS["Secure Boot"]}"; toggle_secure_boot ;;
            2) show_message "${DESCRIPTIONS["Firewall"]}"; toggle_firewall ;;
            3) show_message "${DESCRIPTIONS["Auditd"]}"; toggle_auditd ;;
            4) show_message "${DESCRIPTIONS["Fail2ban"]}"; toggle_fail2ban ;;
            5) show_message "${DESCRIPTIONS["Kernel Hardening"]}"; configure_kernel_hardening ;;
            6) run_security_audit ;;
            7) show_message "${DESCRIPTIONS["Orphan Cleanup"]}"; cleanup_orphans ;;
            8)
                show_message "Thank you for using the Arch Security Toolkit! 👋\n\n⚠️ Note: This toolkit modifies system security settings. Use with administrative awareness."
                log_action "Exited toolkit"
                clear
                exit 0
                ;;
        esac
    done
}

# 🚀 Indítás
main_menu
