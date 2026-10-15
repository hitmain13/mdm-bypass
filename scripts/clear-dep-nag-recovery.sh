#!/bin/bash
# Limpeza DEP no Recovery. Sem sudo. Um par Settings+hosts por volume.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

info() { printf '\033[1;34mℹ %s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
err() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; }

if [[ "$(id -u)" -ne 0 ]]; then
  err "Terminal do Recovery já é root. Não use sudo."
  exit 1
fi

mdm_bypass_load_block_domains "$(cd "${SCRIPT_DIR}/.." && pwd)"

SETTINGS_DIRS=()
for vol in /Volumes/*; do
  [[ -d "$vol" ]] || continue
  mdm_bypass_skip_volume "$vol" && continue
  for s in "$vol/private/var/db/ConfigurationProfiles/Settings" "$vol/var/db/ConfigurationProfiles/Settings"; do
    [[ -d "$s" ]] || continue
    # Ignora symlink que sai do volume.
    case "$(cd "$s" && pwd -P)" in
      "$vol"/*) SETTINGS_DIRS+=("$(cd "$s" && pwd -P)") ;;
    esac
  done
done

# Únicos.
uniq=()
while IFS= read -r line; do
  [[ -n "$line" ]] && uniq+=("$line")
done < <(printf '%s\n' "${SETTINGS_DIRS[@]}" | sort -u)
SETTINGS_DIRS=("${uniq[@]}")

if [[ "${#SETTINGS_DIRS[@]}" -eq 0 ]]; then
  err "Nenhum Settings em /Volumes. Monte o disco e rode: ls /Volumes"
  exit 1
fi

info "Volumes com Settings: ${#SETTINGS_DIRS[@]}"
failed=0
stamp="$(date +%Y%m%d-%H%M%S)"

for SETTINGS_DIR in "${SETTINGS_DIRS[@]}"; do
  info "Settings: ${SETTINGS_DIR}"
  vol="${SETTINGS_DIR%/private/var/db/ConfigurationProfiles/Settings}"
  vol="${vol%/var/db/ConfigurationProfiles/Settings}"
  backup="${vol}/private/var/tmp/mdm-bypass-backup-${stamp}"
  mkdir -p "$backup" || { err "Sem pasta de backup em ${vol}"; failed=1; continue; }
  copied=0
  for f in "$SETTINGS_DIR"/* "$SETTINGS_DIR"/.[!.]*; do
    [[ -f "$f" ]] || continue
    cp -X "$f" "$backup/$(basename "$f")" 2>/dev/null && copied=$((copied + 1)) || true
  done
  [[ "$copied" -gt 0 ]] && ok "Backup: ${backup} (${copied} arquivos)" || warn "Backup vazio em ${backup}"

  rm -f \
    "$SETTINGS_DIR/.cloudConfigHasActivationRecord" \
    "$SETTINGS_DIR/.cloudConfigRecordFound" \
    "$SETTINGS_DIR/.cloudConfigTimerCheck" \
    "$SETTINGS_DIR/com.apple.mdm.depnag.plist" \
    "$SETTINGS_DIR/com.apple.mdm.prelogin.plist" \
    || { err "Falha ao remover em ${SETTINGS_DIR}"; failed=1; }

  touch "$SETTINGS_DIR/.cloudConfigProfileInstalled" "$SETTINGS_DIR/.cloudConfigRecordNotFound" \
    || warn "Marcadores não criados em ${SETTINGS_DIR}"

  hosts="$(mdm_bypass_hosts_for_settings "$SETTINGS_DIR" || true)"
  if [[ -n "${hosts:-}" && -w "$hosts" ]]; then
    info "hosts: ${hosts}"
    for domain in "${BLOCK_DOMAINS[@]}"; do
      mdm_bypass_block_domain "$hosts" "$domain" || { err "Falha hosts ${domain}"; failed=1; }
    done
  else
    warn "hosts do volume não gravável (${hosts:-ausente})"
  fi

  if [[ -f "$SETTINGS_DIR/.cloudConfigRecordFound" ]]; then
    err "Ainda existe .cloudConfigRecordFound em ${SETTINGS_DIR}"
    failed=1
  else
    ok "Cloud config ausente em ${SETTINGS_DIR}"
  fi
done

sync || true
if [[ "$failed" -ne 0 ]]; then
  err "Limpeza incompleta."
  exit 1
fi
ok "Concluído. Reinicie o Mac."
