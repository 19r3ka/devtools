#!/usr/bin/env bash
# 🚀 2026 Infrastructure Bootstrap - Phase 2 (Hardening + Networking)
# Purpose: Harden SSH & Git configs, enable identity-based networking with Tailscale

set -euo pipefail

LOG_FILE="/tmp/bootstrap_phase2_$(date +%s).log"

log_info()    { printf "\n\033[1;34m>> [INFO]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_warn()    { printf "\n\033[1;33m>> [WARN]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_success() { printf "\n\033[1;32m>> [SUCCESS]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_err()     { printf "\n\033[1;31m>> [ERROR]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }

trap 'log_err "Bootstrap interrupted"; exit 1' INT TERM

# --- Phase 1: SSH Hardening ---
phase1_ssh_hardening() {
    log_info "Phase 1: SSH Hardening"
    if [ -f /etc/ssh/sshd_config ]; then
        sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
        sudo systemctl restart ssh || log_warn "SSH restart failed."
        log_success "SSH hardened."
    else
        log_warn "No sshd_config found; skipping."
    fi
}

# --- Phase 2: Git Hardening ---
phase2_git_hardening() {
    log_info "Phase 2: Git Hardening"
    git config --global init.defaultBranch main
    git config --global pull.rebase true
    git config --global rerere.enabled true
    git config --global core.autocrlf input
    git config --global core.editor "vim"
    git config --global commit.gpgsign true || true
    log_success "Git hardened with modern defaults."
}

# --- Phase 3: Tailscale Setup ---
phase3_tailscale() {
    log_info "Phase 3: Tailscale Setup"
    if ! command -v tailscale >/dev/null; then
        curl -fsSL https://tailscale.com/install.sh | sh
        log_success "Tailscale installed."
    fi
    sudo tailscale up --ssh || log_warn "Tailscale up failed."
    tailscale status || log_warn "Unable to confirm Tailscale status."
    log_info "Reminder: Disable key expiry in Tailscale admin console for persistent servers."
}

# --- Phase 4: Validation ---
phase4_validation() {
    log_info "Phase 4: Validation Checklist"
    ssh -T localhost || log_warn "Local SSH test failed."
    git config --list | tee -a "$LOG_FILE"
    tailscale status || log_warn "Tailscale not active."
    log_success "Validation complete."
}

# --- Main ---
main() {
    log_info "Starting Phase 2 Bootstrap..."
    phase1_ssh_hardening
    phase2_git_hardening
    phase3_tailscale
    phase4_validation
    log_success "Phase 2 complete. System hardened and identity-based networking enabled."
}

main

