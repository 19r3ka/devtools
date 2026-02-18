#!/usr/bin/env bash
# 🚀 2026 Standard: Chezmoi Bootstrap & Orchestration
# Purpose: Idempotent installation and initialization of dotfiles
# Logic: Preflight -> SSH Key Setup -> Repo Validation -> Init -> Diff -> Apply -> Validate

set -euo pipefail

CHEZMOI_BIN="$HOME/.local/bin/chezmoi"
LOG_FILE="/tmp/chezmoi_bootstrap_$(date +%s).log"
REPO_URL=""
REPO_STATE=""
SSH_KEY_NAME=""

# --- Logging ---
log_info()    { printf "\033[1;34m>> [INFO]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_warn()    { printf "\033[1;33m>> [WARN]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_success() { printf "\033[1;32m>> [SUCCESS]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_err()     { printf "\033[1;31m>> [ERROR]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }

trap 'log_err "Bootstrap interrupted"; exit 1' INT TERM

# --- Preflight Dependencies ---
check_deps() {
    log_info "Pre-flight: Checking dependencies..."
    local deps=(git curl tee sed awk gpg ssh)
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_err "Missing dependency: $cmd. Please install it first."
            exit 1
        fi
    done
}

# --- SSH Key Setup ---
setup_ssh_key() {
    log_info "Pre-flight: SSH key setup"

    read -rp ">> Enter a name for your SSH key (e.g., id_github, id_gitlab): " SSH_KEY_NAME
    local key_path="$HOME/.ssh/$SSH_KEY_NAME"

    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

    if [ ! -f "$key_path" ]; then
        log_info "Generating new Ed25519 key: $SSH_KEY_NAME"
        ssh-keygen -t ed25519 -f "$key_path" -N "" -C "bootstrap-$(date +%F)"
    else
        log_info "Key $SSH_KEY_NAME already exists."
    fi

    # Start agent if not running
    if [ -z "${SSH_AUTH_SOCK:-}" ]; then
        log_info "Starting ssh-agent..."
        eval "$(ssh-agent -s)"
    fi

    # Add key to agent if not already loaded
    if ! ssh-add -l | grep -q "$key_path"; then
        log_info "Adding key to ssh-agent..."
        ssh-add "$key_path"
    fi

    log_success "SSH key ready: $key_path"
    log_info "Public key:"
    cat "$key_path.pub"
    if command -v xclip >/dev/null 2>&1; then
        cat "$key_path.pub" | xclip -selection clipboard
        log_success "Public key copied to clipboard."
    elif command -v pbcopy >/dev/null 2>&1; then
        cat "$key_path.pub" | pbcopy
        log_success "Public key copied to clipboard."
    else
        log_warn "Clipboard tool not found. Copy manually."
    fi
    echo ">> Add this public key to your GitHub/GitLab account before continuing."
}

# --- Install Chezmoi ---
install_chezmoi() {
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

# --- Repo Validation ---
get_and_validate_repo() {
    while true; do
        read -rp ">> Enter your Dotfiles Repo URL (e.g., git@github.com:user/dotfiles.git): " REPO_URL
        if [ -z "$REPO_URL" ]; then
            log_warn "URL cannot be empty."
            continue
        fi

        log_info "Testing access to $REPO_URL..."
        if git ls-remote "$REPO_URL" &>/dev/null; then
            log_success "Repository access confirmed."
            REPO_STATE="EXISTING"
            break
        else
            log_warn "Unable to access repository."
            echo "   - If using SSH: ensure your key ($SSH_KEY_NAME) is added to GitHub/GitLab."
            echo "   - If using HTTPS: prepare username/token."
            read -rp ">> Is this a brand new, empty repository to populate? (y/n): " response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                REPO_STATE="NEW"
                break
            else
                log_warn "Please fix access settings and try again."
            fi
        fi
    done
}

# --- Baseline Templates ---
create_baseline_templates() {
    log_info "Creating baseline templates..."
    local source_dir
    source_dir=$("$CHEZMOI_BIN" source-path)
    mkdir -p "$source_dir"

    cat <<'EOF' > "$source_dir/.chezmoi.toml.tmpl"
[data]
    email = "your-email@example.com"
    is_wsl = {{ if (env "WSL_DISTRO_NAME") }}true{{ else }}false{{ end }}
    is_pi = {{ if (eq .chezmoi.arch "arm64") }}true{{ else }}false{{ end }}
EOF

    cat <<'EOF' > "$source_dir/dot_zshrc.tmpl"
# 2026 Standard Zshrc
export PATH="$HOME/.local/bin:$PATH"

{{ if .is_wsl }}
alias open="wslview"
{{ end }}

eval "$(starship init zsh)"
EOF

    cat <<'EOF' > "$source_dir/.gitignore"
.DS_Store
.env.local
*.swp
EOF

    echo "# Dotfiles Repo - Managed by Chezmoi" > "$source_dir/README.md"
}

# --- Initialization ---
initialize_dotfiles() {
    if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
        log_info "Chezmoi already initialized. Updating..."
        "$CHEZMOI_BIN" update
        return
    fi

    if [ "$REPO_STATE" = "EXISTING" ]; then
        log_info "Initializing from existing remote..."
        "$CHEZMOI_BIN" init --apply "$REPO_URL"
    else
        log_info "Initializing fresh local state..."
        "$CHEZMOI_BIN" init
        create_baseline_templates
        cd "$("$CHEZMOI_BIN" source-path)"
        git init
        git add .
        git commit -m "feat: initial 2026 infrastructure bootstrap"
        git branch -M main
        if ! git remote | grep -q origin; then
            git remote add origin "$REPO_URL"
        fi
        git push --set-upstream origin main
    fi
}

# --- Diff & Apply ---
apply_changes() {
    log_info "Running diff check..."
    "$CHEZMOI_BIN" diff || true
    echo ""
    read -rp ">> Apply these changes to your home directory? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        "$CHEZMOI_BIN" apply
        log_success "Configuration applied."
    else
        log_warn "Changes skipped. Run 'chezmoi apply' later."
    fi
}

# --- Validation ---
validate_environment() {
    log_info "Validation checklist..."
    command -v chezmoi >/dev/null && log_success "Chezmoi installed: $("$CHEZMOI_BIN" --version)" || log_err "Chezmoi not found."
    [ -d "$HOME/.local/share/chezmoi" ] && log_success "Chezmoi source directory exists." || log_err "Source directory missing."
    git -C "$("$CHEZMOI_BIN" source-path)" status &>/dev/null && log_success "Dotfiles repo initialized." || log_warn "Dotfiles repo not initialized."
    grep -q ".local/bin" "$HOME/.zshrc" 2>/dev/null && log_success "PATH includes ~/.local/bin." || log_warn "PATH missing ~/.local/bin."
}

# --- Main ---
main() {
    log_info "Starting Chezmoi Bootstrap..."
    check_deps
    setup_ssh_key
    install_chezmoi
    get_and_validate_repo
    initialize_dotfiles
    apply_changes
    validate_environment
    log_success "Bootstrap complete. Welcome to your 2026 Environment."
}

main

