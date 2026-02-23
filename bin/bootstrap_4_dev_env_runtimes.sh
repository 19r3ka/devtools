#!/usr/bin/env bash
# 🚀 2026 Infrastructure Bootstrap - Phase 4 (Developer Environment & Runtimes)

set -euo pipefail

LOG_FILE="/tmp/bootstrap_phase4_$(date +%s).log"

log_info()    { printf "\n\033[1;34m>> [INFO]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_warn()    { printf "\n\033[1;33m>> [WARN]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_success() { printf "\n\033[1;32m>> [SUCCESS]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_err()     { printf "\n\033[1;31m>> [ERROR]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }

trap 'log_err "Bootstrap interrupted"; exit 1' INT TERM

# --- Phase 4.1: Node.js via fnm ---
phase41_fnm() {
    log_info "Phase 4.1: Installing fnm (Fast Node Manager)"
    if ! command -v fnm >/dev/null; then
        curl -fsSL https://fnm.vercel.app/install | bash
        log_success "fnm installed."
    else
        log_info "fnm already installed."
    fi
}

# --- Phase 4.2: Python via uv ---
phase42_uv() {
    log_info "Phase 4.2: Installing uv (Python environment manager)"
    if ! command -v uv >/dev/null; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
        log_success "uv installed."
    else
        log_info "uv already installed."
    fi
}

# --- Phase 4.3: Global Utilities ---
phase43_utilities() {
    log_info "Phase 4.3: Installing global utilities (jq, yq)"
    sudo apt-get update
    sudo apt-get install -y jq yq
    log_success "jq and yq installed globally."
}

# --- Phase 4.4: Editors ---
phase44_editors() {
    log_info "Phase 4.4: Installing editors"

    # Helix
    if ! command -v hx >/dev/null; then
        curl -Ls https://github.com/helix-editor/helix/releases/latest/download/helix-$(uname -m)-linux.tar.xz \
          | tar -xJ -C /tmp && sudo mv /tmp/helix*/hx /usr/local/bin/
        log_success "Helix installed."
    else
        log_info "Helix already installed."
    fi

    # Micro
    if ! command -v micro >/dev/null; then
        curl https://getmic.ro | bash
        sudo mv micro /usr/local/bin/
        log_success "Micro installed."
    else
        log_info "Micro already installed."
    fi

    # Zed (only if GUI available)
    if command -v xhost >/dev/null; then
        if ! command -v zed >/dev/null; then
            curl -fsSL https://zed.dev/install.sh | bash
            log_success "Zed installed (GUI environment detected)."
        else
            log_info "Zed already installed."
        fi
    else
        log_info "No GUI detected, skipping Zed."
    fi
}

# --- Phase 4.5: Podman Rootless Setup ---
phase45_podman() {
    log_info "Phase 4.5: Installing and configuring Podman for rootless use"

    sudo apt-get install -y podman

    # Configure subordinate UID/GID ranges
    if ! grep -q "$USER" /etc/subuid; then
        echo "$USER:100000:65536" | sudo tee -a /etc/subuid
    fi
    if ! grep -q "$USER" /etc/subgid; then
        echo "$USER:100000:65536" | sudo tee -a /etc/subgid
    fi

    # Enable user socket
    systemctl --user enable --now podman.socket || true

    log_success "Podman installed and configured for rootless execution."
}

# --- Phase 4.6: Validation ---
phase46_validation() {
    log_info "Phase 4.6: Validation Checklist"
    command -v fnm && fnm --version | tee -a "$LOG_FILE"
    command -v uv && uv --version | tee -a "$LOG_FILE"
    command -v jq && jq --version | tee -a "$LOG_FILE"
    command -v yq && yq --version | tee -a "$LOG_FILE"
    command -v hx && hx --version | tee -a "$LOG_FILE"
    command -v micro && micro --version | tee -a "$LOG_FILE"
    command -v podman && podman --version | tee -a "$LOG_FILE"
    log_success "Validation complete."
}

# --- Main ---
main() {
    log_info "Starting Phase 4 Bootstrap..."
    phase41_fnm
    phase42_uv
    phase43_utilities
    phase44_editors
    phase45_podman
    phase46_validation
    log_success "Phase 4 complete. Developer runtimes, editors, and rootless Podman configured."
}

main

