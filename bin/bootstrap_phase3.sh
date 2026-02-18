#!/usr/bin/env bash
# 🚀 2026 Hardened Git Bootstrap - Phase 3
# Purpose: Idempotent setup of Git environment with flexible provisioners
# Logic: Preflight -> Provisioner Loop -> Git Config -> Chezmoi -> Tooling -> Validation

set -euo pipefail

LOG_FILE="/tmp/git_bootstrap_$(date +%s).log"
CHEZMOI_BIN="$HOME/.local/bin/chezmoi"
SSH_MANAGER="$HOME/.local/bin/ssh-manager"
DEVTOOLS_DIR="$HOME/devtools"
PREK_INSTALLER_URL="https://github.com/j178/prek/releases/download/v0.3.3/prek-installer.sh"

# --- Logging helpers ---
log_info()    { printf "\033[1;34m>> [INFO]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_warn()    { printf "\033[1;33m>> [WARN]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_success() { printf "\033[1;32m>> [SUCCESS]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_err()     { printf "\033[1;31m>> [ERROR]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }

trap 'log_err "Bootstrap interrupted"; exit 1' INT TERM

# --- Phase 1: Installation ---
phase1_installation() {
    log_info "Phase 1: Updating system and installing essentials..."
    sudo apt-get update -qq && sudo apt-get upgrade -y -qq
    sudo apt-get install -y git build-essential curl keychain
}

# --- Phase 2: Provisioner Setup via ssh-manager ---
phase2_provisioners() {
    log_info "Phase 2: Configure Git provisioners using ssh-manager"
    while true; do
        read -rp "Alias (e.g., github, gitlab, gitea) [Enter to stop]: " alias
        [ -z "$alias" ] && break
        read -rp "Hostname (e.g., github.com): " hostname
        read -rp "User (usually 'git'): " user
        read -rp "Identity file (filename or full path): " identityfile

        "$SSH_MANAGER" "$alias" "$hostname" "$user" "$identityfile"
    done
}

# --- Phase 3: Modern Git Configuration ---
phase3_git_config() {
    log_info "Phase 3: Configuring modern Git defaults..."
    git config --global init.defaultBranch main
    git config --global pull.rebase true
    git config --global rerere.enabled true
    git config --global core.editor "vim"
    log_success "Git defaults configured."
}

# --- Phase 4: Chezmoi Dotfiles ---
phase4_dotfiles() {
    log_info "Phase 4: Chezmoi Dotfiles"
    if ! command -v chezmoi >/dev/null; then
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    fi
    export PATH="$HOME/.local/bin:$PATH"

    read -rp "Dotfiles repo URL (e.g., git@alias:user/dotfiles.git): " repo
    if [ -n "$repo" ]; then
        if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
            "$CHEZMOI_BIN" update
        else
            "$CHEZMOI_BIN" init --apply "$repo"
        fi
    fi
}

# --- Phase 5: Tooling ---
phase5_tooling() {
    log_info "Phase 5: Installing modern tooling..."
    if ! command -v prek >/dev/null; then
        curl --proto '=https' --tlsv1.2 -LsSf "$PREK_INSTALLER_URL" | sh
    fi
}

# --- Phase 6: Validation ---
phase6_validation() {
    log_info "Phase 6: Validation Checklist"
    "$SSH_MANAGER" --repair
    grep -E "^Host " "$HOME/.ssh/config" | awk '{print $2}' | while read -r alias; do
        log_info "Testing SSH connectivity for alias: $alias"
        ssh -T "$alias" || log_warn "SSH test failed for $alias"
    done
    "$CHEZMOI_BIN" status || log_warn "Chezmoi not tracking state."
    command -v prek >/dev/null && log_success "prek installed: $(prek --version)" || log_warn "prek not installed."
    log_info "Re-run this script; it should make zero changes if idempotent."
}

# --- Ensure ssh-manager exists ---
ensure_ssh_manager() {
    if [ ! -f "$SSH_MANAGER" ]; then
        log_warn "ssh-manager not found in ~/.local/bin. Creating in ~/devtools/bin instead..."
        mkdir -p "$DEVTOOLS_DIR/bin"
        SSH_MANAGER="$DEVTOOLS_DIR/bin/ssh-manager"
        cat <<'EOF' > "$SSH_MANAGER"
#!/usr/bin/env bash
# ssh-manager: Manage SSH identities and config entries
# Usage:
#   ssh-manager <alias> <hostname> <user> <identityfile>
#   ssh-manager --repair | -r
# If params are missing, prompts interactively.

set -euo pipefail

CONFIG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"
touch "$CONFIG"
chmod 600 "$CONFIG"

# --- Ensure ssh-agent is running ---
if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    eval "$(ssh-agent -s)"
fi

copy_pubkey() {
    local pubfile="$1"
    if command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard < "$pubfile"
        echo ">> Public key copied to clipboard."
    elif command -v pbcopy >/dev/null 2>&1; then
        pbcopy < "$pubfile"
        echo ">> Public key copied to clipboard."
    else
        echo ">> Copy this public key manually:"
        cat "$pubfile"
    fi
}

generate_and_add_key() {
    local identityfile="$1"
    if [ ! -f "$identityfile" ]; then
        echo ">> Generating new Ed25519 key: $identityfile"
        ssh-keygen -t ed25519 -f "$identityfile" -N "" -C "ssh-manager-$(date +%F)"
    fi
    ssh-add "$identityfile" || true
    copy_pubkey "${identityfile}.pub"
}

repair_mode() {
    echo ">> Repair mode: scanning $CONFIG"
    while read -r line; do
        case "$line" in
            IdentityFile*)
                file=$(echo "$line" | awk '{print $2}')
                file="${file/#\~/$HOME}" # expand ~
                generate_and_add_key "$file"
                ;;
        esac
    done < "$CONFIG"
    exit 0
}

if [[ "${1:-}" == "--repair" || "${1:-}" == "-r" ]]; then
    repair_mode
fi

ALIAS="${1:-}"
HOSTNAME="${2:-}"
USER="${3:-}"
IDENTITYFILE="${4:-}"

if [ -z "$ALIAS" ]; then read -rp "Alias (e.g., github): " ALIAS; fi
if [ -z "$HOSTNAME" ]; then read -rp "Hostname (e.g., github.com): " HOSTNAME; fi
if [ -z "$USER" ]; then read -rp "User (usually 'git'): " USER; fi
if [ -z "$IDENTITYFILE" ]; then read -rp "Identity file (e.g., id_github): " IDENTITYFILE; fi

case "$IDENTITYFILE" in
    /*) ;; # absolute path
    *) IDENTITYFILE="$HOME/.ssh/$IDENTITYFILE" ;;
esac

if grep -q "Host $ALIAS" "$CONFIG"; then
    sed -i "/Host $ALIAS/,+3d" "$CONFIG"
fi

cat <<EOC >> "$CONFIG"
Host $ALIAS
    HostName $HOSTNAME
    User $USER
    IdentityFile $IDENTITYFILE
EOC

generate_and_add_key "$IDENTITYFILE"

echo ">> Host $ALIAS configured and key loaded."
EOF
        chmod +x "$SSH_MANAGER"
        log_success "ssh-manager created at $SSH_MANAGER"
    else
        log_info "ssh-manager already exists at ~/.local/bin."
    fi
}

# --- Main ---
main() {
    phase1_installation
    ensure_ssh_manager
    phase2_provisioners
    phase3_git_config
    phase4_dotfiles
    phase5_tooling
    phase6_validation
    log_success "Bootstrap Phase 3 complete."
}

main

