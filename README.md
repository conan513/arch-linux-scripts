# Arch Linux Scripts

This repository contains a growing collection of scripts designed for Arch-based Linux distributions. Each script is built to automate common system tasks, improve security, or simplify configuration.

## ✅ Available Scripts

### 🔐 Secure Boot Setup (`secureboot-arch.sh`)

A fully automated Bash script to configure Secure Boot using [`sbctl`](https://github.com/Foxboron/sbctl). It works across any Arch-based distro that uses `pacman`.

#### Features

- Detects current distro and verifies it's Arch-based
- Checks Secure Boot and Setup Mode status
- Ensures required packages are installed
- Creates and enrolls Secure Boot keys (including Microsoft keys)
- Signs unsigned EFI binaries
- Provides final verification and summary
- Color-coded output for clarity

#### Requirements

- Arch-based Linux distro (uses `pacman`)
- `sbctl` installed (`pacman -S sbctl`)
- Secure Boot must be in **Setup Mode**

#### Usage

```bash
chmod +x secureboot-arch.sh
./secureboot-arch.sh
