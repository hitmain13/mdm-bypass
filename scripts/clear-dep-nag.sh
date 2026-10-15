#!/bin/bash
# Remove estado DEP/Cloud Config local (aviso nos Ajustes).
# macOS 15+: flag "restricted" → use Recovery (recovery-clear).

set -euo pipefail

SETTINGS_DIR="/var/db/ConfigurationProfiles/Settings"
HOSTS_FILE="/etc/hosts"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

RED='\033[1;31m'
GRN='\033[1;32m'
YEL='\033[1;33m'
BLU='\033[1;34m'
NC='\033[0m'

log() { printf '%b\n' "$1"; }
info() { log "${BLU}ℹ $*${NC}"; }
ok() { log "${GRN}✓ $*${NC}"; }
warn() { log "${YEL}⚠ $*${NC}"; }
err() { log "${RED}✗ $*${NC}" >&2; }

if [[ -d /System/Installation ]]; then
  err "Isto é o Recovery. Não use clear-nag. Rode recovery-clear (sem sudo)."
  exit 2
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  err "Execute como root ou: sudo $0 (no Recovery não existe sudo — use recovery-clear)."
  exit 1
fi

[[ -d "$SETTINGS_DIR" ]] || { err "Diretório não encontrado: $SETTINGS_DIR"; exit 1; }

settings_protected=0
if ls -laO "$SETTINGS_DIR" 2>/dev/null | grep -q restricted; then
  settings_protected=1
  warn "Arquivos com flag 'restricted': remoção local ignorada; use Modo de Recuperação."
fi

if [[ -n "${SUDO_USER:-}" ]]; then
  USER_HOME="$(eval echo "~${SUDO_USER}")"
else
  USER_HOME="${HOME}"
fi
BACKUP_DIR="${USER_HOME}/Documents/mdm-bypass-backups/Settings-${TIMESTAMP}"

backup_settings() {
  local src="$1" dest="$2" f base copied=0
  mkdir -p "$dest" || return 1
  for f in "$src"/* "$src"/.[!.]* "$src"/..?*; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    if cp -X "$f" "$dest/$base" 2>/dev/null; then
      copied=$((copied + 1))
    elif cat "$f" >"$dest/$base" 2>/dev/null; then
      copied=$((copied + 1))
    fi
  done
  [[ "$copied" -gt 0 ]]
}

info "Criando backup em ${BACKUP_DIR}..."
backup_settings "$SETTINGS_DIR" "$BACKUP_DIR" && ok "Backup criado." || warn "Backup parcial."

if [[ "$settings_protected" -eq 0 ]]; then
  info "Removendo registros de Cloud Config / DEP..."
  if ! rm -f \
    "$SETTINGS_DIR/.cloudConfigHasActivationRecord" \
    "$SETTINGS_DIR/.cloudConfigRecordFound" \
    "$SETTINGS_DIR/.cloudConfigTimerCheck" \
    "$SETTINGS_DIR/com.apple.mdm.depnag.plist" \
    "$SETTINGS_DIR/com.apple.mdm.prelogin.plist"; then
    warn "Falha ao remover arquivos — use recovery-clear no Modo de Recuperação."
  fi
  touch \
    "$SETTINGS_DIR/.cloudConfigProfileInstalled" \
    "$SETTINGS_DIR/.cloudConfigRecordNotFound" 2>/dev/null || true
fi

mdm_bypass_load_block_domains "$REPO_ROOT"

info "Bloqueando domínios no ${HOSTS_FILE}..."
[[ -f "$HOSTS_FILE" ]] || touch "$HOSTS_FILE"
for domain in "${BLOCK_DOMAINS[@]}"; do
  mdm_bypass_block_domain "$HOSTS_FILE" "$domain" && ok "Bloqueado: ${domain}" || warn "Falha: ${domain}"
done

launchctl kickstart -k system/com.apple.remotemanagementd 2>/dev/null || true
killall "System Settings" 2>/dev/null || true

echo ""
if [[ -f "$SETTINGS_DIR/.cloudConfigRecordFound" ]]; then
  err "Cloud config DEP ainda presente."
  info "No Recovery (sem sudo), execute:"
  echo "  curl -fsSL https://raw.githubusercontent.com/hitmain13/mdm-bypass/main/remote-bootstrap.sh | bash -s -- recovery-clear"
  exit 2
fi

ok "Concluído. Reinicie o Mac."
exit 0
