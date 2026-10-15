#!/bin/bash
# Limpeza DEP/Cloud Config no Modo de Recuperação.
# Necessário quando arquivos em Settings têm flag "restricted" (macOS 15+ com SIP).

set -euo pipefail

RED='\033[1;31m'
GRN='\033[1;32m'
YEL='\033[1;33m'
BLU='\033[1;34m'
NC='\033[0m'

info() { printf '%b\n' "${BLU}ℹ $*${NC}"; }
ok() { printf '%b\n' "${GRN}✓ $*${NC}"; }
warn() { printf '%b\n' "${YEL}⚠ $*${NC}"; }
err() { printf '%b\n' "${RED}✗ $*${NC}" >&2; }

declare -a BLOCK_DOMAINS=(
  deviceenrollment.apple.com
  mdmenrollment.apple.com
  iprofiles.apple.com
  experian.jamfcloud.com
)

find_settings_dirs() {
  local vol
  for vol in /Volumes/*; do
    [[ -d "$vol" ]] || continue
    [[ "$vol" == *Recovery* ]] && continue
    if [[ -d "$vol/var/db/ConfigurationProfiles/Settings" ]]; then
      echo "$vol/var/db/ConfigurationProfiles/Settings"
    fi
    if [[ -d "$vol/private/var/db/ConfigurationProfiles/Settings" ]]; then
      echo "$vol/private/var/db/ConfigurationProfiles/Settings"
    fi
  done
}

find_hosts_file() {
  local vol
  for vol in /Volumes/*; do
    [[ -d "$vol" ]] || continue
    [[ "$vol" == *Recovery* ]] && continue
    if [[ -f "$vol/etc/hosts" ]] && [[ -d "$vol/System" ]]; then
      echo "$vol/etc/hosts"
      return 0
    fi
  done
  for vol in /Volumes/*; do
    [[ -f "$vol/etc/hosts" ]] && echo "$vol/etc/hosts" && return 0
  done
  return 1
}

if [[ "$(id -u)" -ne 0 ]]; then
  err "No Recovery, o Terminal já roda como root. Se não estiver no Recovery: sudo $0"
  exit 1
fi

SETTINGS_DIRS=()
while IFS= read -r _line; do
  [[ -n "$_line" ]] && SETTINGS_DIRS+=("$_line")
done < <(find_settings_dirs | sort -u)

if [[ "${#SETTINGS_DIRS[@]}" -eq 0 ]]; then
  err "Nenhum .../ConfigurationProfiles/Settings em /Volumes/*"
  err "Monte o disco no Utilitário de Disco e rode: ls /Volumes"
  exit 1
fi

for SETTINGS_DIR in "${SETTINGS_DIRS[@]}"; do
  info "Processando: ${SETTINGS_DIR}"
  rm -f \
    "$SETTINGS_DIR/.cloudConfigHasActivationRecord" \
    "$SETTINGS_DIR/.cloudConfigRecordFound" \
    "$SETTINGS_DIR/.cloudConfigTimerCheck" \
    "$SETTINGS_DIR/com.apple.mdm.depnag.plist" \
    "$SETTINGS_DIR/com.apple.mdm.prelogin.plist" \
    && ok "Registros DEP removidos." || warn "Falha parcial em ${SETTINGS_DIR}"

  touch \
    "$SETTINGS_DIR/.cloudConfigProfileInstalled" \
    "$SETTINGS_DIR/.cloudConfigRecordNotFound" \
    && ok "Marcadores de bypass criados." || warn "Falha ao criar marcadores."
done

HOSTS_FILE="$(find_hosts_file || true)"
if [[ -n "${HOSTS_FILE:-}" ]]; then
  info "Atualizando hosts: ${HOSTS_FILE}"
  for domain in "${BLOCK_DOMAINS[@]}"; do
    grep -qE "[[:space:]]${domain}([[:space:]]|$)" "$HOSTS_FILE" 2>/dev/null || echo "0.0.0.0 ${domain}" >>"$HOSTS_FILE"
  done
  ok "Domínios bloqueados."
else
  warn "etc/hosts do sistema não encontrado em /Volumes/*"
fi

echo ""
ok "Limpeza no Recovery concluída. Reinicie o Mac."
