#!/usr/bin/env bash
# 🚀 2026 Infrastructure Bootstrap - Phase 5 (Backup & Monitoring, Chezmoi-native)

set -euo pipefail

CHEZMOI_DATA="$(chezmoi source-path)/.chezmoidata.yaml"
LOG_FILE="/tmp/bootstrap_phase5_$(date +%s).log"

log_info()    { printf "\n\033[1;34m>> [INFO]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }
log_success() { printf "\n\033[1;32m>> [SUCCESS]\033[0m %s\n" "$1" | tee -a "$LOG_FILE"; }

update_yaml() {
    local key="$1"
    local value="$2"
    # If yq is available, use it; otherwise append manually
    if command -v yq >/dev/null; then
        yq -i ".$key = \"$value\"" "$CHEZMOI_DATA"
    else
        echo "$key: \"$value\"" >> "$CHEZMOI_DATA"
    fi
}

# --- Phase 5.1: Snapshots ---
phase51_snapshots() {
    log_info "Phase 5.1: Configure Btrfs Snapshots"
    read -rp "Enable daily snapshots with Snapper? [y/N]: " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        update_yaml "snapshots.enabled" "true"
        read -rp "How many daily snapshots to keep? [default=2]: " limit
        limit=${limit:-2}
        update_yaml "snapshots.daily_limit" "$limit"
    else
        update_yaml "snapshots.enabled" "false"
    fi
}

# --- Phase 5.2: Backups ---
phase52_backups() {
    log_info "Phase 5.2: Configure Backups"
    echo "Choose backup tool:"
    echo "1) Kopia"
    echo "2) Restic"
    echo "3) Skip backups"
    read -rp "Enter choice [1/2/3]: " choice

    case "$choice" in
        1)
            update_yaml "backup.tool" "kopia"
            ;;
        2)
            update_yaml "backup.tool" "restic"
            ;;
        *)
            update_yaml "backup.tool" "none"
            ;;
    esac

    if [[ "$choice" == "1" || "$choice" == "2" ]]; then
        read -rp "Enter backup repository path (e.g., /mnt/backup): " repo
        update_yaml "backup.repo" "$repo"
        read -rp "Enable nightly backup timer at 03:00? [y/N]: " timer_choice
        if [[ "$timer_choice" =~ ^[Yy]$ ]]; then
            update_yaml "backup.nightly_timer" "true"
        else
            update_yaml "backup.nightly_timer" "false"
        fi
    fi
}

# --- Phase 5.3: Prek Guardrails ---
phase53_prek() {
    log_info "Phase 5.3: Configure Prek pre-commit hooks"
    if command -v prek >/dev/null; then
        read -rp "Enable global Prek hooks? [y/N]: " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            update_yaml "prek.enabled" "true"
        else
            update_yaml "prek.enabled" "false"
        fi
    else
        log_info "Prek not installed (Phase 3 handles installation)."
        update_yaml "prek.enabled" "false"
    fi
}

# --- Phase 5.4: System Monitoring ---
phase54_sysmon() {
    log_info "Phase 5.4: Configure System Monitoring"
    read -rp "Add sysmon function to shell for quick resource checks? [y/N]: " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        update_yaml "monitoring.sysmon_enabled" "true"
    else
        update_yaml "monitoring.sysmon_enabled" "false"
    fi
}

# --- Main ---
main() {
    log_info "Starting Phase 5 Bootstrap..."
    mkdir -p "$(chezmoi source-path)"
    touch "$CHEZMOI_DATA"

    phase51_snapshots
    phase52_backups
    phase53_prek
    phase54_sysmon

    log_info "Applying Chezmoi templates..."
    chezmoi apply

    log_success "Phase 5 complete. Snapshots, backups, guardrails, and monitoring configured via Chezmoi."
}

main

