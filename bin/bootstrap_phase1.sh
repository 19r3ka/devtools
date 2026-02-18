#!/usr/bin/env bash
# 🚀 2026 Infrastructure Bootstrap - Phase 1
# Version: 4.1 (WSL Hardened)
# Target: WSL2 / Headless Raspberry Pi
# Principle: Idempotent, Modular, Interactive, Safe

set -euo pipefail

# --- 0. Global Variables ---
GIT_USER=""
GIT_EMAIL=""
DOTFILES_REPO=""
DEVTOOLS_REPO=""
TARGET_HOSTNAME=""
LOG_FILE="/tmp/bootstrap_phase1_$(date +%F).log"

# --- 1. Logging Helper ---
log_info() { echo -e "\033[1;34m>> [INFO]\033[0m $1" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "\033[1;33m>> [WARN]\033[0m $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "\033[1;32m>> [SUCCESS]\033[0m $1" | tee -a "$LOG_FILE"; }
log_err() { echo -e "\033[1;31m>> [ERROR]\033[0m $1" | tee -a "$LOG_FILE"; }

# --- 2. Interactive Prompts ---
prompt_user_data() {
    log_info "Input Required: Configure your environment"
    while [[ -z "${GIT_USER// }" ]]; do read -p "   Enter Git Username: " GIT_USER; done
    while [[ -z "${GIT_EMAIL// }" ]]; do read -p "   Enter Git Email: " GIT_EMAIL; done
    while [[ -z "${DOTFILES_REPO// }" ]]; do read -p "   Enter Dotfiles Repo URL: " DOTFILES_REPO; done
    read -p "   Enter Devtools Repo URL (optional): " DEVTOOLS_REPO
    
    local current_host=$(hostname)
    read -p "   Set System Hostname (current: $current_host): " TARGET_HOSTNAME
    TARGET_HOSTNAME="${TARGET_HOSTNAME:-$current_host}"
}

# --- 3. Context Sniffer ---
get_platform_context() {
    if grep -qi microsoft /proc/version 2>/dev/null; then echo "wsl2"
    elif grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then echo "pi-headless"
    else echo "linux-generic"; fi
}

# --- 4. System Refresh (With User's WSL Workaround) ---
update_and_upgrade() {
    local ctx="$1"
    log_info "Phase 1: System Refresh ($ctx)"

    # WSL-Specific Hostname Persistence via wsl.conf
    if [[ "$ctx" == "wsl2" && "$(hostname)" != "$TARGET_HOSTNAME" ]]; then
        log_info "Updating hostname in /etc/wsl.conf..."
        if ! grep -q "\[network\]" /etc/wsl.conf 2>/dev/null; then
            printf "\n[network]\nhostname=$TARGET_HOSTNAME\ngenerateHosts=true\n" | sudo tee -a /etc/wsl.conf >/dev/null
        fi
    fi

    # The Subshell Shim Workaround
    (
        if [[ "$ctx" == "wsl2" ]]; then
            # Check both /bin and /usr/bin for systemd-sysusers
            local sysuser_path=$(which systemd-sysusers || echo "/usr/bin/systemd-sysusers")
            if [ -f "$sysuser_path" ] && [ ! -L "$sysuser_path" ]; then
                sudo mv "$sysuser_path" "${sysuser_path}.bak"
                sudo ln -s /bin/echo "$sysuser_path"
                log_info "Applied systemd workaround for WSL (Shimmed $sysuser_path)"
                trap "sudo mv ${sysuser_path}.bak $sysuser_path && log_info 'Restored original systemd-sysusers'" EXIT
            fi
        fi

        log_info "Fixing broken package locks..."
        set +e
        sudo dpkg --configure -a
        DPKG_EXIT=$?
        set -e

        if [ $DPKG_EXIT -ne 0 ]; then
            log_err "Standard repair failed. Please run 'wsl --shutdown' in PowerShell."
            exit 1
        fi

        sudo apt-get install -f -y -qq
        sudo apt-get update -qq
        sudo apt-get upgrade -y -qq
        sudo apt-get install -y build-essential curl git unzip zsh wslu
    )
}

# --- 5. Git & 6. Hardware Optimization ---
# (Logic remains as per v4 to maintain consistency)
setup_git() {
    log_info "Configuring Git defaults..."
    git config --global user.name "$GIT_USER"
    git config --global user.email "$GIT_EMAIL"
    git config --global init.defaultBranch main
}

optimize_system() {
    local ctx="$1"
    if [[ "$ctx" == "wsl2" ]]; then
        if ! grep -q "systemd=true" /etc/wsl.conf 2>/dev/null; then
            printf "\n[boot]\nsystemd=true\n" | sudo tee -a /etc/wsl.conf >/dev/null
        fi
    fi
}

# --- 7. Secrets Strategy (Updated for .env Template Philosophy) ---
setup_secrets_strategy() {
    log_info "Phase 1: Secrets & Env Templates"
    local template_dir="$HOME/.templates"
    mkdir -p "$template_dir"

    # Create .env template if missing
    if [ ! -f "$template_dir/.env.template" ]; then
        echo "API_KEY=your_key_here" > "$template_dir/.env.template"
        log_info "Created .env.template in $template_dir"
    fi

    # Interactive key check
    if [ ! -f "$HOME/.env" ]; then
        read -p ">> Missing .env. Enter your primary API Key (or press enter to skip): " USER_KEY
        if [[ -n "$USER_KEY" ]]; then
            echo "API_KEY=$USER_KEY" > "$HOME/.env"
            chmod 600 "$HOME/.env"
        fi
    fi
}

# --- 8. Runtimes & 9. Resiliency ---
setup_runtimes() {
    log_info "Installing uv and fnm..."
    command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
    command -v fnm >/dev/null || curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
}

main() {
    prompt_user_data
    local ctx=$(get_platform_context)
    update_and_upgrade "$ctx"
    setup_git
    optimize_system "$ctx"
    setup_secrets_strategy
    setup_runtimes
    log_success "Phase 1 Complete. Restarting WSL is recommended if systemd was just enabled."
}

main
