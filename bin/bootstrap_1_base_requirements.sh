#!/usr/bin/env bash
# 🚀 2026 Infrastructure Bootstrap - Phase 1 (Base Requirements)
# Target: WSL2 / Raspberry Pi / Generic Linux
# Principle: Idempotent, Modular, Focused, Safe

set -euo pipefail

CHEZMOI_BIN="$HOME/.local/bin/chezmoi"
LOG_FILE="/tmp/bootstrap_phase1_$(date +%s).log"
DEVTOOLS_REPO=""
DOTFILES_REPO=""
SSH_KEY_NAME=""
REPO_STATE=""

# --- Logging ---
log_info()    { printf "\n\033[1;34m>> [INFO]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_warn()    { printf "\n\033[1;33m>> [WARN]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_success() { printf "\n\033[1;32m>> [SUCCESS]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_err()     { printf "\n\033[1;31m>> [ERROR]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }

trap 'log_err "Bootstrap interrupted"; exit 1' INT TERM

# --- Preflight Dependencies ---
check_deps() {
    log_info "Pre-flight: Checking dependencies..."
    local deps=(git curl tee sed awk ssh)
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_err "Missing dependency: $cmd. Please install it first."
            exit 1
        fi
    done
}

# --- System Refresh ---
update_and_upgrade() {
    log_info "Phase 1: System Refresh"
    sudo dpkg --configure -a || true
    sudo apt-get install -f -y -qq
    sudo apt-get update -qq
    sudo apt-get upgrade -y -qq
    sudo apt-get install -y build-essential curl git unzip zsh \
        openssh-client openssh-server inotify-tools
}

# --- Git Identity ---
setup_git_identity() {
    log_info "Phase 2: Git Identity"
    read -p "   Enter Git Username: " GIT_USER
    read -p "   Enter Git Email: " GIT_EMAIL
    git config --global user.name "$GIT_USER"
    git config --global user.email "$GIT_EMAIL"
    git config --global init.defaultBranch main
}

# --- Devtools Repo ---
setup_devtools_repo() {
    log_info "Phase 3: Devtools Repo Setup"
    read -rp ">> Enter your Devtools Repo URL (e.g., git@github.com:user/devtools.git): " DEVTOOLS_REPO
    if [[ -z "$DEVTOOLS_REPO" ]]; then
        log_warn "No devtools repo provided. Skipping."
        return
    fi

    # Prompt for SSH key for devtools
    read -rp ">> Enter SSH key name for Devtools repo (e.g., id_github): " SSH_KEY_NAME
    local key_path="$HOME/.ssh/$SSH_KEY_NAME"
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    if [ ! -f "$key_path" ]; then
        log_info "Generating new Ed25519 key: $SSH_KEY_NAME"
        ssh-keygen -t ed25519 -f "$key_path" -N "" -C "devtools-bootstrap-$(date +%F)"
    fi
    eval "$(ssh-agent -s)"
    ssh-add "$key_path"
    log_info "Public key for Devtools:"
    cat "$key_path.pub"
    echo ">> Add this public key to your Git provider before continuing."

    if [ -d "$HOME/devtools/.git" ]; then
        log_info "Devtools repo already exists. Pulling latest changes..."
        cd "$HOME/devtools" && git pull --rebase
    elif [ -d "$HOME/devtools" ]; then
        log_warn "Devtools directory exists but is not a git repo. Skipping clone."
    else
        if git ls-remote "$DEVTOOLS_REPO" &>/dev/null; then
            git clone "$DEVTOOLS_REPO" "$HOME/devtools"
            log_success "Devtools repo cloned."
        else
            mkdir -p "$HOME/devtools"
            cd "$HOME/devtools"
            git init
            git branch -M main
            git remote add origin "$DEVTOOLS_REPO"
            git add .
            git commit -m "Initial devtools commit"
            git push -u origin main
            log_success "Devtools repo created and pushed."
        fi
    fi
}

# --- Install Chezmoi ---
install_chezmoi() {
    log_info "Phase 4: Install Chezmoi"
    if command -v chezmoi >/dev/null 2>&1; then
        log_info "Chezmoi already installed."
    else
        log_info "Installing Chezmoi..."
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    fi
    export PATH="$HOME/.local/bin:$PATH"
    if ! grep -q ".local/bin" "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi
}

# --- Dotfiles Repo ---
setup_dotfiles_repo() {
    log_info "Phase 5: Dotfiles Repo Setup"
    read -rp ">> Enter your Dotfiles Repo URL (e.g., git@github.com:user/dotfiles.git): " DOTFILES_REPO
    if [[ -z "$DOTFILES_REPO" ]]; then
        log_warn "No dotfiles repo provided. Skipping."
        return
    fi

    log_info "Testing access to $DOTFILES_REPO..."
    if git ls-remote "$DOTFILES_REPO" &>/dev/null; then
        log_success "Repository access confirmed."
        chezmoi init --apply "$DOTFILES_REPO"
        log_success "Dotfiles applied from $DOTFILES_REPO"
    else
        log_warn "Unable to access repository. Ensure SSH key is registered."
        log_info "Initializing fresh local state..."
        "$CHEZMOI_BIN" init
        cd "$("$CHEZMOI_BIN" source-path)"
        git init
        git add .
        git commit -m "feat: initial 2026 infrastructure bootstrap"
        git branch -M main
        git remote add origin "$DOTFILES_REPO"
        git push --set-upstream origin main
    fi
}

# --- System Tweaks ---
optimize_system() {
    log_info "Phase 6: System Tweaks"
    if grep -qi microsoft /proc/version 2>/dev/null; then
        if ! grep -q "systemd=true" /etc/wsl.conf 2>/dev/null; then
            printf "\n[boot]\nsystemd=true\n" | sudo tee -a /etc/wsl.conf >/dev/null
            log_info "Enabled systemd in /etc/wsl.conf (restart WSL required)."
        fi
    elif grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        log_info "Applying Raspberry Pi optimizations..."
        sudo apt-get purge -y triggerhappy logrotate dphys-swapfile || true
        sudo systemctl disable bluetooth || true
        log_success "Pi services trimmed for performance."
    fi
}

# --- Runtimes ---
setup_runtimes() {
    log_info "Phase 7: Installing uv and fnm managers"
    command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
    command -v fnm >/dev/null || curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
}

# --- Validation ---
validate_environment() {
    log_info "Phase 8: Validation Checklist"
    command -v git >/dev/null && log_success "Git installed." || log_err "Git missing."
    command -v ssh >/dev/null && log_success "SSH installed." || log_err "SSH missing."
    command -v chezmoi >/dev/null && log_success "Chezmoi installed." || log_err "Chezmoi missing."
    ssh-add -l || log_warn "No keys currently loaded in ssh-agent."
    [ -d "$HOME/devtools" ] && log_success "Devtools repo present." || log_warn "Devtools repo missing."
    [ -d "$HOME/.local/share/chezmoi" ] && log_success "Dotfiles repo initialized." || log_warn "Dotfiles repo not initialized."
}

# --- Main ---
main() {
    log_info "Starting Phase 1 Bootstrap..."
    check_deps
    update_and_upgrade
    setup_git_identity
    setup_devtools_repo
    install_chezmoi
    setup_dotfiles_repo
    optimize_system
    setup_runtimes
    validate_environment
    log_success "Phase 1 Complete. System ready for next phases."
}

main

