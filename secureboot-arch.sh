#!/bin/bash
set -e

# ✅ Check if pacman exists
if ! command -v pacman &> /dev/null; then
    echo -e "\e[31m❌ This system does not use pacman. Not an Arch-based distro.\e[0m"
    exit 1
fi

# 🧠 Detect distro name
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO_NAME="${NAME:-Unknown}"
else
    DISTRO_NAME="Unknown"
fi

# 🖨️ Display distro name
echo ""
echo -e "\e[34m🔧 Secure Boot Setup Script for $DISTRO_NAME\e[0m"
echo "🛠️ Checks system status, creates and enrolls keys, then signs binaries."
echo ""

# 📦 Check required packages
echo "🔍 Checking required packages..."

MISSING=0

for pkg in sbctl; do
    if ! pacman -Q "$pkg" &> /dev/null; then
        echo -e "\e[31m❌ Missing package: $pkg\e[0m"
        MISSING=1
    else
        echo -e "\e[32m✅ Installed: $pkg\e[0m"
    fi
done

if [[ "$MISSING" == 1 ]]; then
    echo "📥 Installing missing packages..."
    sudo pacman -S sbctl --noconfirm
    echo -e "\e[32m✅ Installation complete.\e[0m"
fi

# 🔑 Sudo pre-check
echo ""
echo "🔎 Checking Secure Boot status (sudo required)..."
echo "ℹ️ This step is completely safe — it only reads system status and does not make any changes."
echo "🔐 You will be asked later whether to proceed with key creation and enrollment."
sudo -v

# 🔍 Read sbctl status once
STATUS=$(sudo sbctl status)

# 🔍 Parse Secure Boot and Setup Mode status
SECURE_BOOT_ENABLED=$(echo "$STATUS" | grep -q "Secure Boot:.*Enabled" && echo "yes" || echo "no")
SETUP_MODE_ENABLED=$(echo "$STATUS" | grep -q "Setup Mode:.*Enabled" && echo "yes" || echo "no")

# 🧾 Display with colors
[[ "$SECURE_BOOT_ENABLED" == "yes" ]] && echo -e "\e[32m🔐 Secure Boot: enabled\e[0m" || echo -e "\e[31m🔓 Secure Boot: disabled\e[0m"
[[ "$SETUP_MODE_ENABLED" == "yes" ]] && echo -e "\e[32m🛠️ Setup Mode: enabled\e[0m" || {
    echo -e "\e[31m🛠️ Setup Mode: disabled\e[0m"
    echo ""
    echo "❌ Setup Mode is required to enroll Secure Boot keys."
    echo ""
    echo "🔧 Enter your BIOS and choose 'Reset Secure Boot keys' or 'Clear Secure Boot keys'."
    echo "⚠️ Before exiting BIOS, make sure Secure Boot is in Setup Mode!"
    echo "🔁 Then reboot and re-run this script."
    exit 1
}

# ✅ Confirmation
echo ""
read -p "✅ All good. Proceed with key creation and enrollment? (y/n): " confirm
[[ "$confirm" != "y" ]] && echo -e "\e[31m🚪 Exiting...\e[0m" && exit 1

# 🔐 Create keys
echo ""
echo "🧬 Creating Secure Boot keys..."
sudo sbctl create-keys
echo -e "\e[32m✅ Keys created.\e[0m"

# 📥 Enroll keys
echo ""
echo "📥 Enrolling keys into EFI (including Microsoft keys)..."
sudo sbctl enroll-keys --microsoft
echo -e "\e[32m✅ Keys enrolled.\e[0m"

# 🔍 Verify
echo ""
echo "🔍 Checking unsigned binaries..."
sudo sbctl verify
echo -e "\e[32m✅ Verification complete.\e[0m"

# ✍️ Sign
echo ""
echo "✍️ Signing binaries..."
sudo sbctl-batch-sign
echo -e "\e[32m✅ Binaries signed.\e[0m"

# ✅ Final check
echo ""
echo "🔍 Final verification..."
sudo sbctl verify
echo -e "\e[32m✅ All good.\e[0m"

# 🎉 Summary
echo ""
echo "🎉 Done! Secure Boot is now configured with custom keys."
echo "🔐 In BIOS, you can leave Secure Boot in Setup Mode or switch to User Mode if available."
echo -e "\e[31m❌ Do NOT switch to Standard Mode — it will erase your custom keys and restore factory defaults!\e[0m"
