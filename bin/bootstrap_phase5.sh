#!/usr/bin/env bash
# 🚀 2026 Infrastructure Standard - Phase 5
# Purpose: Implement zero-trust mesh networking with Tailscale + SSH hardening
# Applies to WSL2 and Raspberry Pi nodes

set -euo pipefail

LOG_FILE="/tmp/tailscale_bootstrap_$(date +%s).log"

log_info()    { printf "\033[1;34m>> [INFO]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_warn()    { printf "\033[1;33m>> [WARN]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_success() { printf "\033[1;32m>> [SUCCESS]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_err()     { printf "\033[1;31m>> [ERROR]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }

trap 'log_err "Bootstrap interrupted"; exit 1' INT TERM

# --- Phase 1: Tailscale Installation and Mesh Initialization ---
phase1_tailscale() {
    log_info "Phase 1: Installing Tailscale and joining mesh"

    if ! command -v tailscale >/dev/null; then
        curl -fsSL https://tailscale.com/install.sh | sh
        log_success "Tailscale installed."
    else
        log_info "Tailscale already installed."
    fi

    # Bring node into mesh with SSH enabled
    sudo tailscale up --ssh || log_warn "Tailscale up failed, check configuration."

    # Confirm mesh status
    tailscale status || log_warn "Unable to confirm Tailscale status."

    log_info "Reminder: For headless nodes (e.g., Raspberry Pi), disable key expiry in Tailscale admin console."
}

# --- Phase 2: Platform-Specific Network Optimization ---
phase2_platform() {
    log_info "Phase 2: Platform-specific optimization"

    if grep -qi raspberrypi /proc/device-tree/model 2>/dev/null; then
        log_info "Detected Raspberry Pi: configuring as subnet router..."
        sudo sysctl -w net.ipv4.ip_forward=1
        sudo tailscale up --advertise-routes=192.168.1.0/24 --ssh
        log_success "Pi configured to advertise LAN routes."
    elif grep -qi microsoft /proc/version; then
        log_info "Detected WSL2: ensure systemd is enabled in /etc/wsl.conf"
        log_info "Add the following to /etc/wsl.conf and restart WSL:"
        echo "[boot]" | sudo tee /etc/wsl.conf
        echo "systemd=true" | sudo tee -a /etc/wsl.conf
        log_warn "WSL2 requires systemd enabled for tailscaled to run properly."
    else
        log_info "Generic Linux detected: no special optimization applied."
    fi
}

# --- Phase 3: SSH Hardening ---
phase3_ssh() {
    log_info "Phase 3: SSH Hardening"

    sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

    if command -v systemctl >/dev/null; then
        sudo systemctl restart ssh || log_warn "SSH restart failed."
    else
        log_warn "Systemctl not available (WSL2 without systemd). Restart sshd manually if needed."
    fi

    log_success "SSH hardening applied."
}

# --- Phase 4: Final Validation Checklist ---
phase4_validation() {
    log_info "Phase 4: Validation Checklist"

    echo "--------------------------------------------------"
    echo "📋 Tailscale + SSH Hardening Report"
    echo "--------------------------------------------------"

    # Mesh reachability
    tailscale status | grep 100. || log_warn "No Tailscale IP assigned."

    # Service health
    if command -v systemctl >/dev/null; then
        systemctl is-active tailscaled || log_warn "tailscaled not active"
    else
        log_warn "Systemctl not available; check tailscaled manually."
    fi

    echo "--------------------------------------------------"
    log_success "Validation complete. System is 2026-compliant if checks passed."
    log_info "Recovery note: Ensure at least one machine has SSH keys backed up in dotfiles."
}

# --- Main ---
main() {
    phase1_tailscale
    phase2_platform
    phase3_ssh
    phase4_validation
    log_success "Phase 2 bootstrap complete."
}

main

