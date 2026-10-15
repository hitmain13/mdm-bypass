#!/bin/bash
# Limpeza DEP/Cloud Config no Modo de Recuperação (sem sudo).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

RED='\033[1;31m'
GRN='\033[1;32m'
YEL='\033[1;33m'
BLU='\033[1;34m'
NC='\033[0m'

info() { printf '%b\n' "${BLU}ℹ $*${NC}"; }
ok() { printf '%b\n' "${GRN}✓ $*${NC}"; }
warn() { printf '%b\n' "${YEL}⚠ $*${NC}"; }
err() { printf '%b\n' "${RED}✗ $*${NC}" >&2; }

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

# Preferir volume de dados gravável (evita etc/hosts no sistema selado).
find_hosts_file() {
  local vol h
  for vol in /Volumes/*; do
    [[ -d "$vol" ]] || continue
    [[ "$vol" == *Recovery* ]] && continue
    [[ "$vol" == *" - Data"* ]] || [[ "$(basename "$vol")" == "Data" ]] || continue
    for h in "$vol/private/etc/hosts" "$vol/etc/hosts"; do
      if [[ -f "$h" ]] && [[ -w "$h" ]]; then
        echo "$h"
        return 0
      fi
    done
  done
  for vol in /Volumes/*; do
    for h in "$vol/private/etc/hosts" "$vol/etc/hosts"; do
      [[ -f "$h" ]] && [[ -w "$h" ]] && echo "$h" && return 0
    done
  done
  return 1
}

if [[ "$(id -u)" -ne 0 ]]; then
  err "Execute como root (Terminal do Recovery). Não use sudo — no Recovery ele costuma não existir."
  exit 1
fi

mdm_bypass_load_block_domains "$(cd "${SCRIPT_DIR}/.." && pwd)"

SETTINGS_DIRS=()
while IFS= read -r _line; do
  [[ -n "$_line" ]] && SETTINGS_DIRS+=("$_line")
done < <(find_settings_dirs | sort -u)

if [[ "${#SETTINGS_DIRS[@]}" -eq 0 ]]; then
  err "Nenhum .../ConfigurationProfiles/Settings em /Volumes/*"
  err "Monte o disco (Utilitário de Disco) e rode: ls /Volumes"
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
  info "Atualizando hosts (gravável): ${HOSTS_FILE}"
  for domain in "${BLOCK_DOMAINS[@]}"; do
    grep -qE "[[:space:]]${domain}([[:space:]]|$)" "$HOSTS_FILE" 2>/dev/null || \
      echo "0.0.0.0 ${domain}" >>"$HOSTS_FILE" || warn "Não foi possível bloquear ${domain}"
  done
  ok "Hosts atualizados (quando o volume permitiu escrita)."
else
  warn "Nenhum etc/hosts gravável encontrado — a remoção dos arquivos DEP é o passo principal."
fi

failed=0
for SETTINGS_DIR in "${SETTINGS_DIRS[@]}"; do
  if [[ -f "$SETTINGS_DIR/.cloudConfigRecordFound" ]]; then
    err "Cloud config ainda presente em: ${SETTINGS_DIR}"
    failed=1
  fi
done

echo ""
if [[ "$failed" -ne 0 ]]; then
  err "Limpeza incompleta. Verifique volumes com: ls /Volumes"
  exit 1
fi
ok "Limpeza no Recovery concluída. Reinicie o Mac."
