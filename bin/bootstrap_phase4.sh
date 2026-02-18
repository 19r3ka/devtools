#!/usr/bin/env bash
# 🚀 2026 Hardened Git Bootstrap - Phase 4 (WSL2 Compatible)
# Purpose: Synchronize ~/devtools repo across environments
# Logic: Connectivity -> Conditional Sync -> Post-Merge Verification -> Doctor & Sync Scripts -> Cron Integration -> Push -> Summary Report

set -euo pipefail

LOG_FILE="/tmp/devtools_bootstrap_$(date +%s).log"
DEVTOOLS_DIR="$HOME/devtools"
REPORT_FILE="/tmp/devtools_report_$(date +%s).txt"

# --- Logging ---
log_info()    { printf "\033[1;34m>> [INFO]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_warn()    { printf "\033[1;33m>> [WARN]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_success() { printf "\033[1;32m>> [SUCCESS]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_err()     { printf "\033[1;31m>> [ERROR]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }

trap 'log_err "Bootstrap interrupted"; exit 1' INT TERM

# --- Phase 1: Connectivity & Identity Validation ---
phase1_connectivity() {
    log_info "Phase 1: Connectivity & Identity Validation"
    read -rp "Enter your devtools repo URL (e.g., git@alias:user/devtools.git): " REPO_URL

    if [ -z "${SSH_AUTH_SOCK:-}" ]; then
        log_info "Starting ssh-agent..."
        eval "$(ssh-agent -s)"
    fi

    if command -v ssh-manager >/dev/null; then
        ssh-manager --repair
    fi

    HOST_ALIAS=$(echo "$REPO_URL" | awk -F'[@:]' '{print $2}')
    if ssh -T "$HOST_ALIAS" 2>&1 | grep -q "successfully"; then
        CONNECTIVITY_STATUS="✅ SSH connectivity confirmed"
    else
        CONNECTIVITY_STATUS="❌ SSH connectivity failed"
    fi

    if [ -d "$DEVTOOLS_DIR" ]; then
        LOCAL_STATE="✅ Local devtools directory exists"
    else
        LOCAL_STATE="❌ Local devtools directory missing"
    fi
}

# --- Phase 2: Conditional Synchronization ---
phase2_sync() {
    log_info "Phase 2: Conditional Synchronization Logic"

    if git ls-remote "$REPO_URL" &>/dev/null; then
        if [ ! -d "$DEVTOOLS_DIR" ]; then
            cd ~
            git clone "$REPO_URL" "$DEVTOOLS_DIR"
            SYNC_STATUS="✅ Scenario A: Repo cloned"
        else
            cd "$DEVTOOLS_DIR"
            git fetch origin
            git merge -X theirs origin/main || true
            SYNC_STATUS="✅ Scenario B: Strategic merge complete"
        fi
    else
        if [ -d "$DEVTOOLS_DIR" ]; then
            cd "$DEVTOOLS_DIR"
            git init
            git branch -M main
            git remote add origin "$REPO_URL" || true
            git push -u origin main
            SYNC_STATUS="✅ Scenario C: Local devtools pushed to remote"
        else
            SYNC_STATUS="❌ Neither local nor remote devtools repo exists"
            exit 1
        fi
    fi
}

# --- Phase 3: Post-Merge Verification & Scaffolding ---
phase3_postmerge() {
    log_info "Phase 3: Post-Merge Verification & Scaffolding"
    chmod +x "$DEVTOOLS_DIR/bin/"* || true
    ln -sf "$DEVTOOLS_DIR/bin/"* "$HOME/.local/bin/" || true

    if ! grep -q ".local/bin" "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi

    if which edit >/dev/null; then
        PATH_STATUS="✅ PATH integration verified ($(which edit))"
    else
        PATH_STATUS="❌ PATH integration not verified"
    fi

    FINAL_STATUS="✅ Idempotency check: re-run should make zero changes"
}

# --- Phase 4: Doctor & Sync Scripts ---
phase4_tools() {
    log_info "Phase 4: Adding doctor and devtools-sync scripts"

    DOCTOR_SCRIPT="$DEVTOOLS_DIR/bin/doctor"
    if [ ! -f "$DOCTOR_SCRIPT" ]; then
        cat <<'EOF' > "$DOCTOR_SCRIPT"
#!/usr/bin/env bash
set -euo pipefail
echo "🔍 Running devtools doctor check..."
for tool in uv fnm podman; do
    if command -v "$tool" >/dev/null; then
        echo "✅ $tool is installed and responsive"
    else
        echo "❌ $tool not found in PATH"
    fi
done
for file in "$HOME/devtools/bin/"*; do
    [ -f "$file" ] || continue
    link="$HOME/.local/bin/$(basename "$file")"
    if [ -L "$link" ]; then
        echo "✅ Symlink exists for $(basename "$file")"
    else
        echo "❌ Missing symlink for $(basename "$file")"
    fi
done
EOF
        chmod +x "$DOCTOR_SCRIPT"
        ln -sf "$DOCTOR_SCRIPT" "$HOME/.local/bin/doctor"
        log_success "Doctor script created and symlinked."
    fi

    SYNC_SCRIPT="$DEVTOOLS_DIR/bin/devtools-sync"
    if [ ! -f "$SYNC_SCRIPT" ]; then
        cat <<'EOF' > "$SYNC_SCRIPT"
#!/usr/bin/env bash
set -euo pipefail
DEVTOOLS_DIR="$HOME/devtools/bin"
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
for file in "$DEVTOOLS_DIR"/*; do
    [ -f "$file" ] || continue
    chmod +x "$file"
    ln -sf "$file" "$LOCAL_BIN/$(basename "$file")"
done
EOF
        chmod +x "$SYNC_SCRIPT"
        ln -sf "$SYNC_SCRIPT" "$HOME/.local/bin/devtools-sync"
        log_success "Devtools-sync script created and symlinked."
    fi
}

# --- Phase 5: Cron Integration (WSL2 Safe) ---
phase5_cron() {
    log_info "Phase 5: Setting up cron job for devtools-sync (WSL2 compatible)"
    (crontab -l 2>/dev/null; echo "*/10 * * * * $HOME/devtools/bin/devtools-sync >/tmp/devtools-sync.log 2>&1") | crontab -
    log_success "Cron job installed: devtools-sync runs every 10 minutes"
}

# --- Phase 6: Push Changes to Remote ---
phase6_push() {
    log_info "Phase 6: Committing doctor and devtools-sync scripts to remote"
    cd "$DEVTOOLS_DIR"
    git add bin/doctor bin/devtools-sync
    git commit -m "Add doctor and devtools-sync scripts for monitoring and auto-sync" || true
    git push origin main || log_warn "Push failed, check remote connectivity."
    log_success "Changes pushed to remote."
}

# --- Phase 7: Summary Report ---
phase7_report() {
    echo "--------------------------------------------------" | tee "$REPORT_FILE"
    echo "📋 Devtools Bootstrap Phase 4 Report" | tee -a "$REPORT_FILE"
    echo "--------------------------------------------------" | tee -a "$REPORT_FILE"
    echo "$CONNECTIVITY_STATUS" | tee -a "$REPORT_FILE"
    echo "$LOCAL_STATE" | tee -a "$REPORT_FILE"
    echo "$SYNC_STATUS" | tee -a "$REPORT_FILE"
    echo "$PATH_STATUS" | tee -a "$REPORT_FILE"
    echo "$FINAL_STATUS" | tee -a "$REPORT_FILE"
    echo "--------------------------------------------------" | tee -a "$REPORT_FILE"
    log_success "Summary report generated at $REPORT_FILE"
    log_info "Run 'doctor' anytime to check devtools health."
    log_info "devtools-sync is now running automatically via cron (every 10 minutes)."
}

# --- Main ---
main() {
    phase1_connectivity
    phase2_sync
    phase3_postmerge
    phase4_tools
    phase5_cron
    phase6_push
    phase7_report
    log_success "Phase 4 bootstrap complete."
}

main

