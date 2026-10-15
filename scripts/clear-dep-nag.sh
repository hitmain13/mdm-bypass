#!/bin/bash
# Remove estado DEP/Cloud Config local (aviso nos Ajustes).
# macOS 15+: arquivos com flag "restricted" só podem ser alterados no Modo de Recuperação.

set -euo pipefail

SETTINGS_DIR="/var/db/ConfigurationProfiles/Settings"
HOSTS_FILE="/etc/hosts"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECOVERY_SCRIPT="${SCRIPT_DIR}/clear-dep-nag-recovery.sh"

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

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  err "Execute com privilégios de administrador: sudo $0"
  exit 1
fi

if [[ ! -d "$SETTINGS_DIR" ]]; then
  err "Diretório não encontrado: $SETTINGS_DIR"
  exit 1
fi

settings_protected=0
if ls -lO "$SETTINGS_DIR" 2>/dev/null | grep -q restricted; then
  settings_protected=1
  warn "Arquivos DEP com flag 'restricted' + SIP ativo: não é possível apagar com o macOS ligado."
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
if backup_settings "$SETTINGS_DIR" "$BACKUP_DIR"; then
  ok "Backup criado (${BACKUP_DIR})."
else
  warn "Backup parcial — continuando."
fi

if [[ "$settings_protected" -eq 0 ]]; then
  info "Removendo registros de Cloud Config / DEP..."
  rm -f \
    "$SETTINGS_DIR/.cloudConfigHasActivationRecord" \
    "$SETTINGS_DIR/.cloudConfigRecordFound" \
    "$SETTINGS_DIR/.cloudConfigTimerCheck" \
    "$SETTINGS_DIR/com.apple.mdm.depnag.plist" \
    "$SETTINGS_DIR/com.apple.mdm.prelogin.plist"
  touch \
    "$SETTINGS_DIR/.cloudConfigProfileInstalled" \
    "$SETTINGS_DIR/.cloudConfigRecordNotFound" 2>/dev/null || true
else
  info "Pulando remoção local (protegido). Use Modo de Recuperação."
fi

declare -a BLOCK_DOMAINS=(
  deviceenrollment.apple.com
  mdmenrollment.apple.com
  iprofiles.apple.com
  experian.jamfcloud.com
)

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXTRA_HOSTS="${REPO_ROOT}/config/extra-hosts.txt"
if [[ -f "$EXTRA_HOSTS" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -n "$line" ]] && BLOCK_DOMAINS+=("$line")
  done <"$EXTRA_HOSTS"
fi

info "Bloqueando domínios de inscrição no ${HOSTS_FILE}..."
[[ -f "$HOSTS_FILE" ]] || touch "$HOSTS_FILE"
for domain in "${BLOCK_DOMAINS[@]}"; do
  if ! grep -qE "[[:space:]]${domain}([[:space:]]|$)" "$HOSTS_FILE" 2>/dev/null; then
    echo "0.0.0.0 ${domain}" >>"$HOSTS_FILE" && ok "Bloqueado: ${domain}" || warn "Falha ao bloquear ${domain}"
  fi
done

launchctl kickstart -k system/com.apple.remotemanagementd 2>/dev/null || true
killall "System Settings" 2>/dev/null || killall "Ajustes do Sistema" 2>/dev/null || true

echo ""
if [[ -f "$SETTINGS_DIR/.cloudConfigRecordFound" ]]; then
  err "Cloud config DEP ainda presente — o aviso nos Ajustes deve continuar."
  echo ""
  info "Próximo passo (obrigatório no macOS 15+ com SIP):"
  echo "  1. Modo de Recuperação > Wi‑Fi > Utilitários > Terminal"
  echo "  2. Execute (ajuste o volume com: ls /Volumes):"
  echo ""
  echo "     curl -fsSL https://raw.githubusercontent.com/hitmain13/mdm-bypass/main/remote-bootstrap.sh | bash -s -- recovery-clear"
  echo ""
  echo "  Ou, com o disco de dados montado:"
  echo "     sh \"/Volumes/<SEU-DISCO-DE-DADOS>/Users/$(logname 2>/dev/null || echo macbook)/Documents/Projects/mdm-bypass/scripts/clear-dep-nag-recovery.sh\""
  exit 2
fi

ok "Concluído. Reinicie o Mac."
exit 0
