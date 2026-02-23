#!/usr/bin/env bash
# 🚀 2026 Infrastructure Bootstrap - Phase 3 (Shell Apex & Developer UX)

set -euo pipefail

LOG_FILE="/tmp/bootstrap_phase3_$(date +%s).log"

log_info()    { printf "\n\033[1;34m>> [INFO]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_warn()    { printf "\n\033[1;33m>> [WARN]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_success() { printf "\n\033[1;32m>> [SUCCESS]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_err()     { printf "\n\033[1;31m>> [ERROR]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }

trap 'log_err "Bootstrap interrupted"; exit 1' INT TERM

ALIASES_FILE="$HOME/.aliases"
BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"

# --- Phase 1: Mandatory Modern Tooling ---
phase1_modern_tools() {
    log_info "Phase 1: Installing modern tooling via apt/scripts"

    sudo apt-get update
    sudo apt-get install -y fzf ripgrep fd-find tmux eza bat zoxide

    if ! command -v atuin >/dev/null; then
        curl https://raw.githubusercontent.com/atuinsh/atuin/main/install.sh | bash
    fi

    touch "$ALIASES_FILE"
    for rc in "$BASHRC" "$ZSHRC"; do
        if ! grep -q "source ~/.aliases" "$rc" 2>/dev/null; then
            echo '[ -f ~/.aliases ] && source ~/.aliases' >> "$rc"
            log_info "Linked $ALIASES_FILE into $rc"
        fi
    done

    if ! grep -q "zoxide init" "$ZSHRC" 2>/dev/null; then
        echo 'eval "$(zoxide init zsh)"' >> "$ZSHRC"
    fi
    if ! grep -q "atuin init" "$ZSHRC" 2>/dev/null; then
        echo 'eval "$(atuin init zsh)"' >> "$ZSHRC"
    fi

    log_info "Zsh is installed. To set it as your default shell, run: chsh -s $(which zsh)"
    log_success "Modern tooling installed and aliases centralized."
}

# --- Phase 2: Shell Framework Choice ---
phase2_shell_framework() {
    log_info "Phase 2: Shell Framework Setup"
    echo "Choose your shell framework:"
    echo "1) Zinit (advanced, async, turbo mode)"
    echo "2) Zim (simple, fast, modular)"
    read -rp "Enter choice [1/2]: " choice

    if [[ "$choice" == "1" ]]; then
        sh -c "$(curl -fsSL https://git.io/zinit-install)"
        log_success "Zinit installed."
    else
        export ZIM_HOME="${ZIM_HOME:-$HOME/.zim}"
        if [[ -d "$ZIM_HOME" ]]; then
            log_warn "$ZIM_HOME already exists. Skipping re-install."
        else
            curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh
            log_success "Zim installed at $ZIM_HOME."
        fi
    fi
}

# --- Phase 3: Prompt Choice ---
phase3_prompt() {
    log_info "Phase 3: Prompt Setup"
    echo "Choose your prompt:"
    echo "1) Starship"
    echo "2) Powerlevel10k"
    read -rp "Enter choice [1/2]: " choice

    if [[ "$choice" == "1" ]]; then
        curl -fsSL https://starship.rs/install.sh | sh
        echo 'eval "$(starship init zsh)"' >> "$ZSHRC"
        log_success "Starship installed and configured."
    else
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
            ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
        echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> "$ZSHRC"
        log_success "Powerlevel10k installed and configured."
    fi
}

# --- Phase 4: UX Utilities ---
phase4_ux_utilities() {
    log_info "Phase 4: Installing UX utilities"
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git \
        ${ZSH_CUSTOM:-$HOME/.zsh/custom}/plugins/fast-syntax-highlighting || true
    echo 'source ~/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh' >> "$ZSHRC"

    git clone https://github.com/zsh-users/zsh-autosuggestions \
        ${ZSH_CUSTOM:-$HOME/.zsh/custom}/plugins/zsh-autosuggestions || true
    echo 'source ~/zsh-autosuggestions/zsh-autosuggestions.zsh' >> "$ZSHRC"

    echo 'bindkey "^R" fzf-history-widget' >> "$ZSHRC"

    log_success "UX utilities installed."
}

# --- Phase 5: Developer Guardrails ---
phase5_guardrails() {
    log_info "Phase 5: Installing developer guardrails"
    if ! command -v prek >/dev/null; then
        curl --proto '=https' --tlsv1.2 -LsSf \
          https://github.com/j178/prek/releases/download/v0.3.3/prek-installer.sh | sh
        log_success "Prek installed via official installer script."
    else
        log_info "Prek already installed."
    fi
    log_info "Ruff (Python) and Biome (JS) should be installed project-specific."
}

# --- Phase 6: Chezmoi Integration ---
phase6_chezmoi() {
    log_info "Phase 6: Chezmoi templating integration"
    if command -v chezmoi >/dev/null; then
        chezmoi apply
        log_success "Chezmoi applied dotfiles."
    else
        log_warn "Chezmoi not found. Skipping."
    fi
}

# --- Phase 7: Validation ---
phase7_validation() {
    log_info "Phase 7: Validation Checklist"
    alias | tee -a "$LOG_FILE"
    git config --list | tee -a "$LOG_FILE"
    log_success "Validation complete."
}

# --- Phase 8: Tmux Setup ---
phase8_tmux() {
    log_info "Phase 8: Installing and configuring tmux"
    echo "Choose your tmux configuration style:"
    echo "1) Minimal"
    echo "2) Power-user"
    echo "3) Custom (Chezmoi)"
    read -rp "Enter choice [1/2/3]: " choice

    TMUX_CONF="$HOME/.tmux.conf"

    case "$choice" in
        1)
            cat > "$TMUX_CONF" <<'EOF'
set -g history-limit 10000
setw -g mode-keys vi
EOF
            log_success "Minimal tmux config applied."
            ;;
        2)
            cat > "$TMUX_CONF" <<'EOF'
set -g prefix C-a
unbind C-b
bind C-a send-prefix
set -g mouse on
set -g history-limit 20000
setw -g mode-keys vi
set -g status-bg black
set -g status-fg white
set -g status-interval 60
EOF
            log_success "Power-user tmux config applied."
            ;;
        3)
            if command -v chezmoi >/dev/null; then
                chezmoi apply --include=dot_tmux.conf
                log_success "Chezmoi tmux template applied."
            else
                log_warn "Chezmoi not found. Skipping custom config."
            fi
            ;;
        *)
            log_warn "Invalid choice. Skipping tmux configuration."
            ;;
    esac
}

# --- Phase 9: Sync fnm/uv logic ---
phase9_sync_env() {
    log_info "Phase 9: Syncing fnm/uv init logic from bashrc to zshrc"
    for tool in fnm uv atuin; do
        if grep -q "$tool" "$BASHRC" 2>/dev/null; then
            if ! grep -q "$tool" "$ZSHRC" 2>/dev/null; then
                grep "$tool" "$BASHRC" >> "$ZSHRC"
                log_info "Copied $tool init logic from bashrc to zshrc"
            fi
        fi
    done
    log_success "Environment sync complete."
}

# --- Main ---
main() {
    log_info "Starting Phase 3 Bootstrap..."
    phase1_modern_tools
    phase2_shell_framework
    phase3_prompt
    phase4_ux_utilities
    phase5_guardrails
    phase6_chezmoi
    phase7_validation
    phase8_tmux
    phase9_sync_env
    log_success "Phase 3 complete. Shell apex, developer UX, tmux, and unified aliases configured."
}

main
